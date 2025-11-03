defmodule AshBaml.InfoTest do
  use ExUnit.Case, async: false

  describe "baml_client_module/1" do
    test "returns configured client module" do
      assert AshBaml.Test.BamlClient ==
               AshBaml.Info.baml_client_module(AshBaml.Test.TestResource)
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
end
