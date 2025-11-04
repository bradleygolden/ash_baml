defmodule AshBaml.Transformers.ImportBamlFunctions do
  @moduledoc """
  Transformer that auto-generates Ash actions from imported BAML functions.

  For each function in `import_functions`, this transformer:

  1. Validates the function exists in the BAML client
  2. Validates return types have been generated
  3. Generates a regular action (`:function_name`)
  4. Generates a streaming action (`:function_name_stream`)

  ## Streaming Actions with Automatic Cancellation

  Streaming actions automatically cancel the underlying LLM generation when the
  stream consumer exits or crashes. This prevents wasted API calls and token usage.

  ### Example: Process Exit Triggers Cancellation

      task = Task.async(fn ->
        {:ok, stream} =
          MyResource
          |> Ash.ActionInput.for_action(:generate_story_stream, %{prompt: "..."})
          |> Ash.run_action()

        Enum.each(stream, fn chunk ->
          # Process chunks...
        end)
      end)

      # If task is killed (e.g., user disconnects), stream automatically cancels
      Task.shutdown(task, :brutal_kill)

  Runs at compile-time and fails fast with helpful error messages.
  """

  use Spark.Dsl.Transformer

  alias AshBaml.FunctionIntrospector
  alias AshBaml.Info
  alias Spark.Dsl.Transformer

  @doc """
  Specifies transformers that must run after this one.

  Returns `false` to indicate no specific ordering requirements - this transformer
  can run before any other transformers.
  """
  @impl true
  def after?(_), do: false

  @doc """
  Specifies transformers that must run before this one.

  Returns `false` to indicate no specific ordering requirements - this transformer
  can run after any other transformers.
  """
  @impl true
  def before?(_), do: false

  @doc """
  Transforms the DSL state by auto-generating Ash actions from imported BAML functions.

  For each function in `import_functions`, validates the function exists and generates
  both regular and streaming action variants.

  Returns `{:ok, dsl_state}` with added actions or `{:error, reason}` if validation fails.
  """
  @impl true
  def transform(dsl_state) do
    client_module = Info.baml_client_module(dsl_state)
    import_functions = Info.baml_import_functions(dsl_state)

    if client_module && import_functions != [] do
      generate_actions(dsl_state, client_module, import_functions)
    else
      {:ok, dsl_state}
    end
  end

  defp generate_actions(dsl_state, client_module, import_functions) do
    Enum.reduce_while(import_functions, {:ok, dsl_state}, fn function_name, {:ok, state} ->
      case generate_actions_for_function(state, client_module, function_name) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp generate_actions_for_function(dsl_state, client_module, function_name) do
    with :ok <- FunctionIntrospector.validate_function_exists(client_module, function_name),
         {:ok, metadata} <-
           FunctionIntrospector.get_function_metadata(client_module, function_name),
         {:ok, return_type_module} <-
           FunctionIntrospector.validate_return_type_exists(
             client_module,
             metadata["return_type"]
           ),
         params = Map.get(metadata, "params", %{}),
         arguments = FunctionIntrospector.map_params_to_arguments(params),
         {:ok, state} <-
           generate_regular_action(dsl_state, function_name, return_type_module, arguments) do
      generate_streaming_action(state, function_name, return_type_module, arguments)
    end
  end

  defp generate_regular_action(dsl_state, function_name, return_type, arguments) do
    action_name = function_name_to_action_name(function_name)

    action =
      build_action_entity(
        action_name,
        return_type,
        arguments,
        function_name,
        :regular
      )

    maybe_add_action(dsl_state, action_name, action)
  end

  defp generate_streaming_action(dsl_state, function_name, return_type, arguments) do
    action_name =
      function_name
      |> function_name_to_action_name()
      |> then(&:"#{&1}_stream")

    action =
      build_action_entity(
        action_name,
        AshBaml.Type.Stream,
        arguments,
        function_name,
        :stream,
        element_type: return_type
      )

    maybe_add_action(dsl_state, action_name, action)
  end

  defp maybe_add_action(dsl_state, action_name, action) do
    existing = Transformer.get_entities(dsl_state, [:actions])

    if Enum.any?(existing, &(&1.name == action_name)) do
      {:ok, dsl_state}
    else
      {:ok, Transformer.add_entity(dsl_state, [:actions], action)}
    end
  end

  defp build_action_entity(name, return_type, arguments, baml_function, action_type, opts \\ []) do
    argument_entities =
      Enum.map(arguments, fn {arg_name, arg_type, arg_opts} ->
        Transformer.build_entity!(
          Ash.Resource.Dsl,
          [:actions, :action],
          :argument,
          Keyword.merge([name: arg_name, type: arg_type], arg_opts)
        )
      end)

    implementation =
      case action_type do
        :regular -> {AshBaml.Actions.CallBamlFunction, [function: baml_function]}
        :stream -> {AshBaml.Actions.CallBamlStream, [function: baml_function]}
      end

    constraints =
      if action_type == :stream do
        [element_type: opts[:element_type]]
      else
        []
      end

    %Ash.Resource.Actions.Action{
      name: name,
      type: :action,
      returns: return_type,
      arguments: argument_entities,
      run: implementation,
      constraints: constraints,
      description: "Auto-generated from BAML function #{baml_function}"
    }
  end

  defp function_name_to_action_name(function_name) do
    function_name
    |> Atom.to_string()
    |> Macro.underscore()
    |> String.to_atom()
  end
end
