defmodule AshBaml.BamlParser do
  @moduledoc """
  Parses BAML schemas and extracts type information for code generation.

  This module wraps the baml_elixir parsing functionality to provide
  a clean interface for extracting classes, enums, and functions.
  """

  @doc """
  Extracts all type definitions from BAML files in the given path.

  ## Parameters
  - `baml_src_path` - Path to directory containing .baml files

  ## Returns
  - `{:ok, %{classes: map, enums: map, functions: map}}` on success
  - `{:error, reason}` on failure
  """
  def parse_schema(baml_src_path) do
    case BamlElixir.Native.parse_baml(baml_src_path) do
      baml_types when is_map(baml_types) ->
        classes = Map.get(baml_types, :classes, %{})
        enums = Map.get(baml_types, :enums, %{})
        functions = Map.get(baml_types, :functions, %{})

        {:ok, %{classes: classes, enums: enums, functions: functions}}

      error ->
        {:error, "Failed to parse BAML files: #{inspect(error)}"}
    end
  end

  @doc """
  Extracts class definitions from parsed BAML schema.

  Returns a map where keys are class names and values contain field definitions.
  """
  def extract_classes(%{classes: classes}), do: classes

  @doc """
  Extracts enum definitions from parsed BAML schema.

  Returns a map where keys are enum names and values are lists of variants.
  """
  def extract_enums(%{enums: enums}), do: enums

  @doc """
  Gets the BAML source path from a client module's configuration.

  ## Parameters
  - `client_module` - Module that uses BamlElixir.Client

  ## Returns
  - `{:ok, path}` if configuration found
  - `{:error, reason}` if not found
  """
  def get_baml_path(client_module) do
    # Client modules store their path in module attributes or config
    # This needs to introspect the client module's configuration

    if function_exported?(client_module, :__baml_src_path__, 0) do
      {:ok, client_module.__baml_src_path__()}
    else
      {:error, "Client module #{inspect(client_module)} does not have BAML path configuration"}
    end
  end
end
