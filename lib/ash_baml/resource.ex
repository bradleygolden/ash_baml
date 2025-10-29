defmodule AshBaml.Resource do
  @moduledoc """
  The AshBaml resource extension.

  Adds the `baml do ... end` DSL block to Ash resources.

  To use the `call_baml/1` helper macro in actions, import `AshBaml.Helpers`:

      defmodule MyApp.ChatResource do
        use Ash.Resource,
          domain: MyApp.Domain,
          extensions: [AshBaml.Resource]

        import AshBaml.Helpers

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
    transformers: []
end
