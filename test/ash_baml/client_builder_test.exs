defmodule AshBaml.ClientBuilderTest do
  use ExUnit.Case, async: false

  alias AshBaml.ClientBuilder

  describe "ensure_configured_client_module/2" do
    test "returns error when client identifier not found in empty config" do
      assert {:error, message} = ClientBuilder.ensure_configured_client_module(:unknown, [])
      assert message =~ "BAML client :unknown not found"
      assert message =~ "No clients configured"
    end

    test "returns error when client identifier not found with available clients" do
      clients = [existing: {SomeModule, baml_src: "path"}]

      assert {:error, message} = ClientBuilder.ensure_configured_client_module(:unknown, clients)
      assert message =~ "BAML client :unknown not found"
      assert message =~ "Available: [:existing]"
    end

    test "returns {:ok, module} when module is already loaded without baml_src" do
      # Kernel is always loaded
      clients = [test_client: {Kernel, []}]

      assert {:ok, Kernel} = ClientBuilder.ensure_configured_client_module(:test_client, clients)
    end

    test "returns error when module not loaded and no baml_src provided" do
      # Define a config with module that doesn't exist
      clients = [test_client: {NonExistentTestModule, []}]

      assert {:error, message} =
               ClientBuilder.ensure_configured_client_module(:test_client, clients)

      assert message =~ "no :baml_src was provided"
    end
  end

  describe "ensure_client_module/2" do
    test "returns :ok when module is already loaded with matching baml_src" do
      # Create a test module that has __baml_src_path__/0
      unique_name =
        String.to_atom("TestBamlClient#{System.unique_integer([:positive])}")

      baml_path = Path.expand("test/support/fixtures/baml_src", File.cwd!())

      Module.create(
        unique_name,
        quote do
          def __baml_src_path__, do: unquote(baml_path)
        end,
        Macro.Env.location(__ENV__)
      )

      # Should return :ok since module is already loaded with matching path
      assert :ok =
               ClientBuilder.ensure_client_module(unique_name, "test/support/fixtures/baml_src")
    end

    test "returns :ok when module is already loaded" do
      # Kernel is always loaded and doesn't have __baml_src_path__
      result = ClientBuilder.ensure_client_module(Kernel, "some/path")
      assert result == :ok
    end

    test "handles concurrent module creation safely" do
      unique_module =
        Module.concat([AshBaml.Test, "Concurrent#{System.unique_integer([:positive])}"])

      baml_src = "test/support/fixtures/baml_src"

      tasks =
        for _ <- 1..10 do
          Task.async(fn -> ClientBuilder.ensure_client_module(unique_module, baml_src) end)
        end

      results = Task.await_many(tasks, 10_000)
      assert Enum.all?(results, &(&1 == :ok))
      assert Code.ensure_loaded?(unique_module)
    end
  end
end
