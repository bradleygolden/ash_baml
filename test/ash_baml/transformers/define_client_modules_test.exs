defmodule AshBaml.Transformers.DefineClientModulesTest do
  use ExUnit.Case, async: false

  alias AshBaml.Transformers.DefineClientModules
  alias AshBaml.Transformers.ImportBamlFunctions

  setup do
    original_config = Application.get_env(:ash_baml, :clients, [])

    on_exit(fn ->
      Application.put_env(:ash_baml, :clients, original_config)
    end)

    :ok
  end

  describe "before?/1" do
    test "returns true for ImportBamlFunctions" do
      assert DefineClientModules.before?(ImportBamlFunctions)
    end

    test "returns false for other transformers" do
      refute DefineClientModules.before?(SomeOtherTransformer)
      refute DefineClientModules.before?(AnotherTransformer)
    end
  end

  describe "after?/1" do
    test "returns false for all transformers" do
      refute DefineClientModules.after?(ImportBamlFunctions)
      refute DefineClientModules.after?(SomeOtherTransformer)
    end
  end

  describe "transform/1 with client identifier" do
    test "successfully generates client module from config" do
      unique_module =
        Module.concat([AshBaml.Test, "GeneratedClient#{System.unique_integer([:positive])}"])

      Application.put_env(:ash_baml, :clients,
        generated: {unique_module, baml_src: "test/support/fixtures/baml_src"}
      )

      defmodule ConfigClientResource do
        use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

        baml do
          client(:generated)
        end
      end

      assert Code.ensure_loaded?(unique_module)
      assert function_exported?(unique_module, :__baml_src_path__, 0)
    end

    test "returns error when client identifier not found in config" do
      Application.put_env(:ash_baml, :clients,
        test: {AshBaml.Test.BamlClient, baml_src: "test/support/fixtures/baml_src"}
      )

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule UnknownClientResource do
            use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

            baml do
              client(:nonexistent)
            end
          end
        end

      assert error.message =~ "BAML client :nonexistent not found"
      assert error.message =~ "Available: [:test]"
    end

    test "handles module already loaded with same source" do
      unique_module =
        Module.concat([AshBaml.Test, "SameSourceClient#{System.unique_integer([:positive])}"])

      Application.put_env(:ash_baml, :clients,
        same_source: {unique_module, baml_src: "test/support/fixtures/baml_src"}
      )

      defmodule SameSourceResource1 do
        use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

        baml do
          client(:same_source)
        end
      end

      defmodule SameSourceResource2 do
        use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

        baml do
          client(:same_source)
        end
      end

      assert Code.ensure_loaded?(unique_module)
    end
  end

  describe "transform/1 with explicit client_module" do
    test "succeeds when client_module is provided" do
      defmodule ExplicitClientResource do
        use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

        baml do
          client_module(AshBaml.Test.BamlClient)
        end
      end

      assert Code.ensure_loaded?(AshBaml.Test.BamlClient)
    end
  end

  describe "transform/1 with no client configured" do
    test "returns error when neither client nor client_module specified" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule NoClientResource do
            use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

            baml do
            end
          end
        end

      assert error.message =~ "Must specify either :client or :client_module"
    end
  end

  describe "client module generation details" do
    test "generated module exports __baml_src_path__/0" do
      unique_module =
        Module.concat([AshBaml.Test, "PathExportClient#{System.unique_integer([:positive])}"])

      Application.put_env(:ash_baml, :clients,
        path_export: {unique_module, baml_src: "test/support/fixtures/baml_src"}
      )

      defmodule PathExportResource do
        use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

        baml do
          client(:path_export)
        end
      end

      assert function_exported?(unique_module, :__baml_src_path__, 0)
      path = unique_module.__baml_src_path__()
      assert String.ends_with?(path, "test/support/fixtures/baml_src")
    end

    test "error message includes available clients when identifier not found" do
      Application.put_env(:ash_baml, :clients,
        test: {AshBaml.Test.BamlClient, baml_src: "test/support/fixtures/baml_src"}
      )

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule AvailableClientsResource do
            use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

            baml do
              client(:missing)
            end
          end
        end

      assert error.message =~ "BAML client :missing not found"
      assert error.message =~ "Available: [:test]"
    end

    test "error message shows 'No clients configured' when config is empty" do
      Application.put_env(:ash_baml, :clients, [])

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule NoClientsConfiguredResource do
            use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

            baml do
              client(:any)
            end
          end
        end

      assert error.message =~ "BAML client :any not found"
      assert error.message =~ "No clients configured"
    end

    test "raises error when baml_src missing from config" do
      unique_module =
        Module.concat([AshBaml.Test, "MissingSrcClient#{System.unique_integer([:positive])}"])

      Application.put_env(:ash_baml, :clients, missing_src: {unique_module, []})

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MissingSrcResource do
            use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

            baml do
              client(:missing_src)
            end
          end
        end

      assert error.message =~ ":baml_src"
    end

    test "handles invalid baml_src path gracefully" do
      unique_module =
        Module.concat([AshBaml.Test, "InvalidPathClient#{System.unique_integer([:positive])}"])

      Application.put_env(:ash_baml, :clients,
        invalid_path: {unique_module, baml_src: "nonexistent/path"}
      )

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule InvalidPathResource do
            use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

            baml do
              client(:invalid_path)
            end
          end
        end

      assert error.message =~ "Failed to create BAML client module"
    end
  end
end
