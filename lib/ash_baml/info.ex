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
