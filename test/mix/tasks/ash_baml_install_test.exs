defmodule Mix.Tasks.AshBaml.InstallTest do
  use ExUnit.Case, async: false

  import Igniter.Test

  alias Mix.Tasks.AshBaml.Install

  describe "info/2" do
    test "returns task schema" do
      schema = Install.info([], %{})

      assert is_map(schema)
      assert Map.has_key?(schema, :schema)
    end
  end

  describe "supports_umbrella?/0" do
    test "returns false" do
      refute Install.supports_umbrella?()
    end
  end

  describe "installer?/0" do
    test "returns true" do
      assert Install.installer?()
    end
  end

  describe "igniter/1" do
    test "warns when both --client and --module are specified" do
      igniter =
        test_project()
        |> Igniter.compose_task("ash_baml.install", [
          "--client",
          "support",
          "--module",
          "MyApp.Client"
        ])

      assert_has_warning(igniter, fn warning ->
        warning =~ "Specify either --client or --module, not both" and
          warning =~ "For config-driven clients (recommended)"
      end)
    end

    test "warns when neither --client nor --module are specified" do
      igniter =
        test_project()
        |> Igniter.compose_task("ash_baml.install", [])

      assert_has_warning(igniter, fn warning ->
        warning =~ "Must specify either --client or --module"
      end)
    end

    test "raises when client identifier is invalid" do
      assert_raise RuntimeError, ~r/Invalid client identifier/, fn ->
        test_project()
        |> Igniter.compose_task("ash_baml.install", ["--client", "InvalidClient"])
        |> apply_igniter!()
      end
    end

    test "installs config-driven client with valid identifier" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("ash_baml.install", ["--client", "support"])

      igniter
      |> assert_creates("baml_src/.gitkeep")
      |> assert_creates("baml_src/clients.baml")
      |> assert_creates("baml_src/example.baml")
      |> assert_has_notice(fn notice ->
        notice =~ "Config-driven BAML client installed successfully" and
          notice =~ "Client ID: :support" and
          notice =~ "Module: MyApp.BamlClients.Support"
      end)
    end

    test "installs config-driven client with custom path" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("ash_baml.install", [
          "--client",
          "content",
          "--path",
          "baml_src/content"
        ])

      igniter
      |> assert_creates("baml_src/content/.gitkeep")
      |> assert_creates("baml_src/content/clients.baml")
      |> assert_creates("baml_src/content/example.baml")
      |> assert_has_notice(fn notice ->
        notice =~ "BAML source: baml_src/content/"
      end)
    end

    test "installs legacy client module" do
      igniter =
        test_project()
        |> Igniter.compose_task("ash_baml.install", ["--module", "MyApp.BamlClient"])

      igniter
      |> assert_creates("lib/my_app/baml_client.ex")
      |> assert_creates("baml_src/.gitkeep")
      |> assert_creates("baml_src/clients.baml")
      |> assert_creates("baml_src/example.baml")
      |> assert_has_notice(fn notice ->
        notice =~ "Legacy BAML client installed successfully" and
          notice =~ "Client module: MyApp.BamlClient"
      end)
    end

    test "installs legacy client with custom path" do
      igniter =
        test_project()
        |> Igniter.compose_task("ash_baml.install", [
          "--module",
          "MyApp.CustomClient",
          "--path",
          "custom_baml"
        ])

      igniter
      |> assert_creates("lib/my_app/custom_client.ex")
      |> assert_creates("custom_baml/.gitkeep")
      |> assert_creates("custom_baml/clients.baml")
      |> assert_creates("custom_baml/example.baml")
    end

    test "valid client identifiers" do
      for client_id <- ["support", "main_client", "client123", "a"] do
        test_project(app_name: :test_app)
        |> Igniter.compose_task("ash_baml.install", ["--client", client_id])
        |> assert_creates("baml_src/.gitkeep")
      end
    end

    test "invalid client identifiers raise error" do
      for client_id <- ["Support", "Main-Client", "123client", "_private"] do
        assert_raise RuntimeError, ~r/Invalid client identifier/, fn ->
          test_project()
          |> Igniter.compose_task("ash_baml.install", ["--client", client_id])
          |> apply_igniter!()
        end
      end
    end
  end
end
