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
      fn -> {:pending, [], arguments} end,
      fn state -> stream_next(function_module, state) end,
      fn _state -> :ok end
    )
  end

  defp stream_next(_function_module, {:done, result}) do
    {:halt, {:done, result}}
  end

  defp stream_next(_function_module, {:error, reason}) do
    {:halt, {:error, reason}}
  end

  defp stream_next(function_module, {:pending, _acc, args}) do
    case function_module.sync_stream(args, & &1) do
      {:ok, result} -> {[result], {:done, result}}
      {:error, reason} -> {[], {:error, reason}}
    end
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
