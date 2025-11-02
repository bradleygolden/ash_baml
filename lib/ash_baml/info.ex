defmodule AshBaml.Info do
  @moduledoc """
  Introspection functions for AshBaml configuration.

  ## Example

      iex> AshBaml.Info.baml_client_module(MyApp.ChatResource)
      MyApp.BamlClient
  """

  alias Spark.Dsl.Extension

  @doc """
  Returns the client identifier atom if using config-driven clients.

  Returns `nil` if using explicit `client_module`.

  ## Example

      iex> AshBaml.Info.baml_client_identifier(MyApp.ChatResource)
      :support
  """
  @spec baml_client_identifier(Spark.Dsl.t() | map()) :: atom() | nil
  def baml_client_identifier(resource) do
    Extension.get_opt(resource, [:baml], :client, nil)
  end

  @doc """
  Returns the BAML client module for a resource.

  Resolves from either:
  - Explicit `client_module` option (legacy)
  - `client` identifier via application config (recommended)

  ## Example

      iex> AshBaml.Info.baml_client_module(MyApp.ChatResource)
      MyApp.BamlClients.Support
  """
  def baml_client_module(resource) do
    case Extension.get_opt(resource, [:baml], :client_module, nil) do
      nil ->
        case baml_client_identifier(resource) do
          nil -> nil
          identifier -> resolve_client_module(identifier)
        end

      module ->
        module
    end
  end

  @doc """
  Resolves a client identifier to its configured module name.

  Reads from application config:

      config :ash_baml,
        clients: [
          support: {MyApp.BamlClients.Support, baml_src: "..."}
        ]

  ## Example

      iex> AshBaml.Info.resolve_client_module(:support)
      MyApp.BamlClients.Support
  """
  @spec resolve_client_module(atom()) :: module() | nil
  def resolve_client_module(identifier) do
    clients = Application.get_env(:ash_baml, :clients, [])

    case Keyword.get(clients, identifier) do
      {module, _opts} -> module
      _ -> nil
    end
  end

  @doc """
  Gets the baml_src path for a client identifier from config.

  ## Example

      iex> AshBaml.Info.client_baml_src(:support)
      "baml_src/support"
  """
  @spec client_baml_src(atom()) :: String.t() | nil
  def client_baml_src(identifier) do
    clients = Application.get_env(:ash_baml, :clients, [])

    case Keyword.get(clients, identifier) do
      {_module, opts} ->
        case Keyword.fetch(opts, :baml_src) do
          {:ok, path} -> path
          :error -> nil
        end

      _ ->
        nil
    end
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

  @doc """
  Returns the full telemetry configuration for a resource.

  Returns a keyword list with all telemetry options, or default config
  if telemetry section is not defined.

  ## Example

      iex> AshBaml.Info.baml_telemetry_config(MyApp.ChatResource)
      [
        enabled: true,
        prefix: [:ash_baml],
        events: [:start, :stop, :exception],
        metadata: [:function_name, :resource],
        sample_rate: 1.0,
        collector_name: nil
      ]
  """
  @spec baml_telemetry_config(Spark.Dsl.t() | map()) :: keyword()
  def baml_telemetry_config(resource) do
    [
      enabled: baml_telemetry_enabled?(resource),
      prefix: baml_telemetry_prefix(resource),
      events: baml_telemetry_events(resource),
      metadata: baml_telemetry_metadata(resource),
      sample_rate: baml_telemetry_sample_rate(resource),
      collector_name: baml_telemetry_collector_name(resource)
    ]
  end

  @doc """
  Returns whether telemetry is enabled for a resource.

  Default: `false` (opt-in)

  ## Example

      iex> AshBaml.Info.baml_telemetry_enabled?(MyApp.ChatResource)
      true
  """
  @spec baml_telemetry_enabled?(Spark.Dsl.t() | map()) :: boolean()
  def baml_telemetry_enabled?(resource) do
    Extension.get_opt(resource, [:baml, :telemetry], :enabled, false)
  end

  @doc """
  Returns the telemetry event prefix for a resource.

  Default: `[:ash_baml]`
  """
  @spec baml_telemetry_prefix(Spark.Dsl.t() | map()) :: [atom()]
  def baml_telemetry_prefix(resource) do
    Extension.get_opt(resource, [:baml, :telemetry], :prefix, [:ash_baml])
  end

  @doc """
  Returns which telemetry events to emit for a resource.

  Default: `[:start, :stop, :exception]`
  """
  @spec baml_telemetry_events(Spark.Dsl.t() | map()) :: [atom()]
  def baml_telemetry_events(resource) do
    Extension.get_opt(resource, [:baml, :telemetry], :events, [:start, :stop, :exception])
  end

  @doc """
  Returns additional metadata fields to include in telemetry events.

  Default: `[]`
  """
  @spec baml_telemetry_metadata(Spark.Dsl.t() | map()) :: [atom()]
  def baml_telemetry_metadata(resource) do
    Extension.get_opt(resource, [:baml, :telemetry], :metadata, [])
  end

  @doc """
  Returns the telemetry sampling rate for a resource.

  Default: `1.0` (100%)
  """
  @spec baml_telemetry_sample_rate(Spark.Dsl.t() | map()) :: float()
  def baml_telemetry_sample_rate(resource) do
    Extension.get_opt(resource, [:baml, :telemetry], :sample_rate, 1.0)
  end

  @doc """
  Returns the custom collector name or function for a resource.

  Default: `nil` (auto-generated)
  """
  @spec baml_telemetry_collector_name(Spark.Dsl.t() | map()) :: String.t() | function() | nil
  def baml_telemetry_collector_name(resource) do
    Extension.get_opt(resource, [:baml, :telemetry], :collector_name, nil)
  end
end
