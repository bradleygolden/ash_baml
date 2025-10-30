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
      case function_module.call(input.arguments) do
        {:ok, result} ->
          {:ok, wrap_union_result(input, result)}

        error ->
          error
      end
    else
      build_module_not_found_error(input.resource, function_name, client_module, function_module)
    end
  end

  defp wrap_union_result(input, result) do
    action_name =
      case input.action do
        %{name: name} -> name
        name when is_atom(name) -> name
        _ -> nil
      end

    case action_name do
      nil ->
        result

      name ->
        action = Ash.Resource.Info.action(input.resource, name)

        if action && action.returns == Ash.Type.Union do
          union_type = find_matching_union_type(action.constraints[:types], result)
          %Ash.Union{type: union_type, value: result}
        else
          result
        end
    end
  end

  defp find_matching_union_type(types, result) do
    Enum.find_value(types, fn {type_name, config} ->
      instance_of = get_in(config, [:constraints, :instance_of])

      if instance_of && result.__struct__ == instance_of do
        type_name
      end
    end)
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
