defmodule AshBaml.Transformers.ValidateClientConfig do
  @moduledoc """
  Validates that either `:client` or `:client_module` is specified, but not both.

  This transformer runs first in the chain to ensure consistent configuration
  before other transformers process the DSL state.
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer
  alias Spark.Error.DslError

  def transform(dsl_state) do
    client = Transformer.get_option(dsl_state, [:baml], :client)
    client_module = Transformer.get_option(dsl_state, [:baml], :client_module)

    cond do
      client && client_module ->
        {:error,
         DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:baml],
           message: """
           Cannot specify both :client and :client_module options.

           Choose one approach:

           Config-driven (recommended):
             baml do
               client :support
             end

           Manual client module:
             baml do
               client_module MyApp.BamlClient
             end
           """
         )}

      !client && !client_module ->
        {:error,
         DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:baml],
           message: """
           Must specify either :client or :client_module option.

           Config-driven (recommended):
             baml do
               client :support
             end

           Manual client module:
             baml do
               client_module MyApp.BamlClient
             end
           """
         )}

      true ->
        {:ok, dsl_state}
    end
  end
end
