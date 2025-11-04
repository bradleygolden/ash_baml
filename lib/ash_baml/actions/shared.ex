defmodule AshBaml.Actions.Shared do
  @moduledoc false

  def build_client_not_configured_error(resource) do
    {:error, "BAML client not configured for #{inspect(resource)}"}
  end

  def build_module_not_found_error(resource, function_name, client_module, function_module) do
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

  def get_action_name(input, default \\ :unknown) do
    case input.action do
      %{name: name} -> name
      name when is_atom(name) -> name
      _ -> default
    end
  end
end
