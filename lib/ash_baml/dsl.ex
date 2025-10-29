defmodule AshBaml.Dsl do
  @moduledoc """
  DSL for configuring BAML integration in Ash resources.
  """

  @baml %Spark.Dsl.Section{
    name: :baml,
    describe: """
    Configure BAML client integration for this resource.

    ## Example

        baml do
          client_module MyApp.BamlClient
        end
    """,
    examples: [
      """
      baml do
        client_module MyApp.BamlClient
      end
      """
    ],
    schema: [
      client_module: [
        type: :atom,
        required: true,
        doc: """
        The module that uses `BamlElixir.Client` to generate BAML function modules.

        This module should use `BamlElixir.Client` with a path to your BAML files:

            defmodule MyApp.BamlClient do
              use BamlElixir.Client, path: {:my_app, "priv/baml_src"}
            end
        """
      ]
    ]
  }

  @doc false
  def baml, do: @baml
end
