defmodule AshBaml.FunctionIntrospector do
  @moduledoc """
  Introspects BAML client modules to extract function metadata.

  Used by transformers to validate and generate actions at compile-time.
  """

  alias AshBaml.BamlParser

  @doc """
  Gets all available BAML function names from a client module.

  ## Example

      iex> get_function_names(MyApp.BamlClient)
      {:ok, [:ExtractTasks, :SummarizeTasks, :ChatAgent]}
  """
  def get_function_names(client_module) do
    with {:ok, baml_path} <- BamlParser.get_baml_path(client_module),
         {:ok, %{functions: functions}} <- BamlParser.parse_schema(baml_path) do
      function_names =
        functions
        |> Map.keys()
        |> Enum.map(&String.to_atom/1)

      {:ok, function_names}
    end
  end

  @doc """
  Gets metadata for a specific BAML function.

  Returns a map with:
  - `:params` - Map of parameter names to types
  - `:return_type` - The BAML return type

  ## Example

      iex> get_function_metadata(MyApp.BamlClient, :ExtractTasks)
      {:ok, %{
        params: %{"input" => {:primitive, :string}},
        return_type: {:class, "TaskList"}
      }}
  """
  def get_function_metadata(client_module, function_name) do
    with {:ok, baml_path} <- BamlParser.get_baml_path(client_module),
         {:ok, %{functions: functions}} <- BamlParser.parse_schema(baml_path) do
      function_key = Atom.to_string(function_name)

      case Map.fetch(functions, function_key) do
        {:ok, metadata} -> {:ok, metadata}
        :error -> {:error, "Function #{function_name} not found in BAML schema"}
      end
    end
  end

  @doc """
  Validates that a function exists in the BAML client.

  Returns `:ok` if valid, `{:error, reason}` otherwise.
  """
  def validate_function_exists(client_module, function_name) do
    case get_function_names(client_module) do
      {:ok, available_functions} ->
        if function_name in available_functions do
          :ok
        else
          {:error,
           """
           BAML function :#{function_name} not found in #{inspect(client_module)}.

           Available functions: #{inspect(available_functions)}

           Make sure the function is defined in your BAML files.
           """}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates that the return type has a generated Ash type module.

  Checks that `ClientModule.Types.ReturnType` exists.
  """
  def validate_return_type_exists(client_module, return_type) do
    types_module = Module.concat(client_module, Types)

    case return_type do
      {:class, class_name} ->
        type_module = Module.concat(types_module, class_name)

        if Code.ensure_loaded?(type_module) do
          {:ok, type_module}
        else
          {:error, type_not_generated_error(client_module, class_name, type_module)}
        end

      {:list, {:class, class_name}} ->
        type_module = Module.concat(types_module, class_name)

        if Code.ensure_loaded?(type_module) do
          {:ok, {:array, type_module}}
        else
          {:error, type_not_generated_error(client_module, class_name, type_module)}
        end

      {:primitive, type} ->
        {:ok, type}

      other ->
        {:error, "Unsupported return type: #{inspect(other)}"}
    end
  end

  @doc """
  Maps BAML parameters to Ash action arguments.

  Returns a list of argument specifications suitable for
  `Ash.Resource.Builder.add_action/3`.
  """
  def map_params_to_arguments(params) do
    Enum.map(params, fn {name, baml_type} ->
      {
        String.to_atom(name),
        baml_type_to_ash_type(baml_type),
        [allow_nil?: false]
      }
    end)
  end

  # Private helpers

  defp baml_type_to_ash_type({:primitive, :string}), do: :string
  defp baml_type_to_ash_type({:primitive, :int}), do: :integer
  defp baml_type_to_ash_type({:primitive, :float}), do: :float
  defp baml_type_to_ash_type({:primitive, :bool}), do: :boolean
  defp baml_type_to_ash_type({:list, inner}), do: {:array, baml_type_to_ash_type(inner)}
  defp baml_type_to_ash_type({:class, _}), do: :map
  defp baml_type_to_ash_type(_), do: :any

  defp type_not_generated_error(client_module, class_name, type_module) do
    """
    Type module not found: #{inspect(type_module)}

    The BAML function returns type '#{class_name}', but the corresponding
    Ash type has not been generated.

    Please run:

        mix ash_baml.gen.types #{inspect(client_module)}

    This will generate the required types in #{inspect(Module.concat(client_module, Types))}.
    """
  end
end
