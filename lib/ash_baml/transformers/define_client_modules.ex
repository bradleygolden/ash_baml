defmodule AshBaml.Transformers.DefineClientModules do
  @moduledoc """
  Transformer that auto-generates BAML client modules from application config.

  For resources using `client :identifier` instead of `client_module`, this
  transformer reads the application config and dynamically creates the client
  module using `Module.create/3`.

  Follows the AshOban pattern for generating worker modules.

  ## Example

  Config:

      config :ash_baml,
        clients: [
          support: {MyApp.BamlClients.Support, baml_src: "baml_src/support"}
        ]

  Resource:

      baml do
        client :support
      end

  Generated module:

      defmodule MyApp.BamlClients.Support do
        use BamlElixir.Client, path: "baml_src/support"
      end

  The module is created during compilation and available to subsequent
  transformers like ImportBamlFunctions.
  """

  use Spark.Dsl.Transformer
  alias AshBaml.ClientBuilder
  alias AshBaml.Info
  alias Spark.Dsl.Extension
  alias Spark.Dsl.Transformer
  alias Spark.Error.DslError

  @doc """
  Must run BEFORE ImportBamlFunctions so generated modules are available.
  """
  @impl true
  def before?(AshBaml.Transformers.ImportBamlFunctions), do: true
  def before?(_), do: false

  @impl true
  def after?(_), do: false

  @doc """
  Transforms the DSL state by generating client modules for config-driven clients.

  If resource uses `client :identifier`, reads config and creates the module.
  If resource uses `client_module`, does nothing (legacy pattern).
  """
  @impl true
  def transform(dsl_state) do
    case Info.baml_client_identifier(dsl_state) do
      nil ->
        validate_explicit_client(dsl_state)

      identifier ->
        generate_client_module(dsl_state, identifier)
    end
  end

  defp validate_explicit_client(dsl_state) do
    explicit_module = Extension.get_opt(dsl_state, [:baml], :client_module, nil)

    if explicit_module do
      {:ok, dsl_state}
    else
      {:error,
       """
       BAML client not configured.

       Either specify:
         1. client :identifier (recommended)
         2. client_module MyApp.BamlClient (legacy)

       For config-driven clients, add to config/config.exs:

           config :ash_baml,
             clients: [
               my_client: {MyApp.BamlClient, baml_src: "baml_src"}
             ]
       """}
    end
  end

  defp generate_client_module(dsl_state, identifier) do
    clients = Application.get_env(:ash_baml, :clients, [])

    case ClientBuilder.ensure_configured_client_module(identifier, clients) do
      {:ok, module_name} ->
        dsl_state
        |> Transformer.persist(:baml_generated_client, module_name)
        |> Transformer.set_option([:baml], :client_module, module_name)
        |> then(&{:ok, &1})

      {:error, reason} ->
        {:error,
         DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:baml],
           message: reason
         )}
    end
  end
end
