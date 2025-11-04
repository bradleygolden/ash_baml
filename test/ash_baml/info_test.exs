defmodule AshBaml.InfoTest do
  use ExUnit.Case, async: false

  describe "baml_client_identifier/1" do
    test "returns client identifier from resource" do
      assert :test == AshBaml.Info.baml_client_identifier(AshBaml.Test.TestResource)
    end
  end

  describe "baml_client_module/1" do
    test "returns configured client module" do
      assert AshBaml.Test.BamlClient ==
               AshBaml.Info.baml_client_module(AshBaml.Test.TestResource)
    end
  end

  describe "resolve_client_module/1" do
    setup do
      on_exit(fn ->
        Application.delete_env(:ash_baml, :clients)
      end)
    end

    test "returns module when identifier found in config" do
      Application.put_env(:ash_baml, :clients, my_client: {MyApp.Client, baml_src: "path"})

      assert MyApp.Client == AshBaml.Info.resolve_client_module(:my_client)
    end

    test "returns nil when identifier not found" do
      assert nil == AshBaml.Info.resolve_client_module(:nonexistent)
    end
  end

  describe "baml_import_functions/1" do
    test "returns list of functions to import" do
      result = AshBaml.Info.baml_import_functions(AshBaml.Test.TestResource)
      assert is_list(result)
    end
  end

  describe "client_baml_src/1" do
    setup do
      on_exit(fn ->
        Application.delete_env(:ash_baml, :clients)
      end)
    end

    test "returns nil when identifier not found" do
      assert AshBaml.Info.client_baml_src(:nonexistent) == nil
    end

    test "returns nil when baml_src key missing from config" do
      Application.put_env(:ash_baml, :clients, broken: {MyApp.Client, []})

      assert AshBaml.Info.client_baml_src(:broken) == nil
    end

    test "returns path when properly configured" do
      Application.put_env(:ash_baml, :clients, test: {MyApp.Client, baml_src: "baml_src"})

      assert AshBaml.Info.client_baml_src(:test) == "baml_src"
    end
  end

  describe "telemetry functions" do
    test "baml_telemetry_config/1 returns full config" do
      config = AshBaml.Info.baml_telemetry_config(AshBaml.Test.TestResource)
      assert Keyword.keyword?(config)
      assert Keyword.has_key?(config, :enabled)
      assert Keyword.has_key?(config, :prefix)
      assert Keyword.has_key?(config, :events)
      assert Keyword.has_key?(config, :metadata)
      assert Keyword.has_key?(config, :sample_rate)
      assert Keyword.has_key?(config, :collector_name)
    end

    test "baml_telemetry_enabled?/1 returns boolean" do
      result = AshBaml.Info.baml_telemetry_enabled?(AshBaml.Test.TestResource)
      assert is_boolean(result)
    end

    test "baml_telemetry_prefix/1 returns atom list" do
      result = AshBaml.Info.baml_telemetry_prefix(AshBaml.Test.TestResource)
      assert is_list(result)
    end

    test "baml_telemetry_events/1 returns atom list" do
      result = AshBaml.Info.baml_telemetry_events(AshBaml.Test.TestResource)
      assert is_list(result)
    end

    test "baml_telemetry_metadata/1 returns list" do
      result = AshBaml.Info.baml_telemetry_metadata(AshBaml.Test.TestResource)
      assert is_list(result)
    end

    test "baml_telemetry_sample_rate/1 returns float" do
      result = AshBaml.Info.baml_telemetry_sample_rate(AshBaml.Test.TestResource)
      assert is_float(result)
    end

    test "baml_telemetry_collector_name/1 returns value" do
      result = AshBaml.Info.baml_telemetry_collector_name(AshBaml.Test.TestResource)
      assert result == nil or is_binary(result) or is_function(result)
    end
  end
end
