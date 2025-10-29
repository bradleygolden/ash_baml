defmodule AshBaml do
  @moduledoc """
  AshBaml provides Ash integration for BAML (Boundary ML) functions.

  ## Usage

  Add `AshBaml.Resource` as an extension to your Ash resources:

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

  ## Prerequisites

  You must:
  1. Write BAML files manually (e.g., in `priv/baml_src/`)
  2. Create a module using `BamlElixir.Client` to generate Elixir code
  3. Reference the generated client in your resource's `baml` block
  """

  @version "0.1.0"

  @doc """
  Returns the current version of the AshBaml library.
  """
  def version, do: @version
end
