defmodule AshBaml.Info do
  @moduledoc """
  Introspection functions for AshBaml configuration.

  ## Example

      iex> AshBaml.Info.baml_client_module(MyApp.ChatResource)
      MyApp.BamlClient
  """

  alias Spark.Dsl.Extension

  @doc """
  Returns the configured BAML client module for a resource.
  """
  def baml_client_module(resource) do
    Extension.get_opt(resource, [:baml], :client_module, nil)
  end

  @doc """
  Gets the list of BAML functions to import as actions.

  Returns a list of function name atoms that should be auto-generated
  as Ash actions.
  """
  @spec baml_import_functions(Spark.Dsl.t() | map()) :: [atom()]
  def baml_import_functions(resource) do
    Extension.get_opt(resource, [:baml], :import_functions, [])
  end
end
