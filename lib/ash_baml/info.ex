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
end
