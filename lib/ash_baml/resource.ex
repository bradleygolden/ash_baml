defmodule AshBaml.Resource do
  @moduledoc """
  The AshBaml resource extension.

  Adds the `baml do ... end` DSL block to Ash resources.

  The `call_baml/1` helper macro is automatically available when using this extension:

      defmodule MyApp.ChatResource do
        use Ash.Resource,
          domain: MyApp.Domain,
          extensions: [AshBaml.Resource]

        baml do
          client_module MyApp.BamlClient
        end

        actions do
          action :chat, MyApp.BamlClient.Reply do
            argument :message, :string
            run call_baml(:ChatAgent)
          end
        end
      end
  """

  use Spark.Dsl.Extension,
    sections: [AshBaml.Dsl.baml()],
    imports: [AshBaml.Helpers],
    transformers: []
end
