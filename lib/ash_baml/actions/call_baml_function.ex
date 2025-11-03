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

  Telemetry is automatically integrated based on resource configuration and
  can be overridden per-action via the `telemetry` option.

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.
  """
  @impl true
  def run(input, opts, _context) do
    function_name = Keyword.fetch!(opts, :function)
    client_module = AshBaml.Info.baml_client_module(input.resource)

    if is_nil(client_module) do
      {:error, "BAML client not configured for #{inspect(input.resource)}"}
    else
      function_module = Module.concat(client_module, function_name)

      if Code.ensure_loaded?(function_module) do
        execute_baml_function(input, function_name, function_module, opts)
      else
        build_module_not_found_error(
          input.resource,
          function_name,
          client_module,
          function_module
        )
      end
    end
  end

  defp execute_baml_function(input, function_name, function_module, opts) do
    telemetry_config = build_telemetry_config(input.resource, opts)

    result =
      AshBaml.Telemetry.with_telemetry(
        input,
        function_name,
        telemetry_config,
        fn collector_opts ->
          # BAML client expects arguments as a map
          function_module.call(input.arguments, collector_opts)
        end
      )

    case result do
      {:ok, data} ->
        {:ok, wrap_union_result(input, data)}

      error ->
        error
    end
  end

  defp build_telemetry_config(resource, opts) do
    base_config = AshBaml.Info.baml_telemetry_config(resource)

    case Keyword.get(opts, :telemetry) do
      false ->
        Keyword.put(base_config, :enabled, false)

      overrides when is_list(overrides) ->
        Keyword.merge(base_config, overrides)

      _ ->
        base_config
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
