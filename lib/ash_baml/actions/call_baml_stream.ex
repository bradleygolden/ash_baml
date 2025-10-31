defmodule AshBaml.Actions.CallBamlStream do
  @moduledoc """
  Action implementation that calls BAML functions with streaming.

  This module wraps BAML's streaming API in an Elixir Stream, allowing
  actions to return token-by-token results from LLM calls.
  """

  use Ash.Resource.Actions.Implementation

  @doc """
  Executes the BAML function with streaming.

  Returns `{:ok, stream}` where stream is an Elixir Stream that emits
  chunks as they arrive from the LLM.
  """
  @impl true
  def run(input, opts, _context) do
    client_module = AshBaml.Info.baml_client_module(input.resource)
    function_name = Keyword.fetch!(opts, :function)
    function_module = Module.concat(client_module, function_name)

    if Code.ensure_loaded?(function_module) do
      stream = create_stream(function_module, input.arguments)
      {:ok, stream}
    else
      build_module_not_found_error(input.resource, function_name, client_module, function_module)
    end
  end

  defp create_stream(function_module, arguments) do
    Stream.resource(
      fn -> start_streaming(function_module, arguments) end,
      fn state -> stream_next(state) end,
      fn _state -> :ok end
    )
  end

  defp start_streaming(function_module, arguments) do
    # Use the async stream function which handles its own process spawning
    parent = self()
    ref = make_ref()

    # Call stream with a callback that sends messages to parent
    # BAML client expects arguments as a map
    function_module.stream(arguments, fn
      {:partial, partial_result} ->
        send(parent, {ref, :chunk, partial_result})

      {:done, final_result} ->
        send(parent, {ref, :done, {:ok, final_result}})

      {:error, error} ->
        send(parent, {ref, :done, {:error, error}})
    end)

    {ref, :streaming}
  end

  defp stream_next({ref, :streaming}) do
    receive do
      {^ref, :chunk, chunk} ->
        # Emit the chunk and continue streaming
        {[chunk], {ref, :streaming}}

      {^ref, :done, {:ok, _final_result}} ->
        # Stream complete successfully
        {:halt, {ref, :done}}

      {^ref, :done, {:error, reason}} ->
        # Stream ended with error
        {:halt, {ref, {:error, reason}}}
    end
  end

  defp stream_next({_ref, :done}) do
    {:halt, :done}
  end

  defp stream_next({_ref, {:error, _reason}}) do
    {:halt, :error}
  end

  defp build_module_not_found_error(resource, function_name, client_module, function_module) do
    {:error,
     """
     BAML function module not found: #{inspect(function_module)}

     Resource: #{inspect(resource)}
     Function: #{inspect(function_name)}
     Client Module: #{inspect(client_module)}

     Make sure:
     1. You have a BAML file with a function named #{function_name}
     2. Your client module (#{inspect(client_module)}) uses BamlElixir.Client
     3. The client has successfully parsed your BAML files
     """}
  end
end
