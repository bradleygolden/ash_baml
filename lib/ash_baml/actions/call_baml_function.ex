defmodule AshBaml.Actions.CallBamlFunction do
  @moduledoc """
  Action implementation that calls BAML functions.

  This module implements `Ash.Resource.Actions.Implementation` and is used
  internally by the `call_baml/1` helper macro.
  """

  use Ash.Resource.Actions.Implementation

  @doc """
  Executes the BAML function call action.

  This callback is invoked by Ash when the action is run. It retrieves the
  configured BAML client module, constructs the function module name, validates
  it exists, and delegates the call to the generated BAML function.

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.
  """
  @impl true
  def run(input, opts, _context) do
    client_module = AshBaml.Info.baml_client_module(input.resource)
    function_name = Keyword.fetch!(opts, :function)
    function_module = Module.concat(client_module, function_name)

    if Code.ensure_loaded?(function_module) do
      function_module.call(input.arguments)
    else
      build_module_not_found_error(input.resource, function_name, client_module, function_module)
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
