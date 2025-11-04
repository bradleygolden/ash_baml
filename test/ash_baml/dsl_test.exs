defmodule AshBaml.DslTest do
  use ExUnit.Case, async: true

  describe "baml/0" do
    test "returns the BAML DSL section definition" do
      section = AshBaml.Dsl.baml()
      assert %Spark.Dsl.Section{} = section
      assert section.name == :baml
      assert section.schema[:client][:type] == :atom
      assert section.schema[:client_module][:type] == :atom
      assert section.schema[:import_functions][:type] == {:list, :atom}
      assert section.schema[:import_functions][:default] == []
    end
  end

  describe "baml DSL block" do
    test "requires either client or client_module option" do
      assert_raise Spark.Error.DslError, ~r/Must specify either :client or :client_module/, fn ->
        defmodule MissingClient do
          use Ash.Resource,
            domain: nil,
            extensions: [AshBaml.Resource]

          baml do
            # Missing both client and client_module
          end
        end
      end
    end

    test "prevents both client and client_module from being specified" do
      assert_raise Spark.Error.DslError, ~r/Cannot specify both :client and :client_module/, fn ->
        defmodule BothOptionsResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshBaml.Resource]

          baml do
            client(:support)
            client_module(AshBaml.Test.BamlClient)
          end
        end
      end
    end

    test "validates client_module is an atom" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule InvalidClientModule do
          use Ash.Resource,
            domain: nil,
            extensions: [AshBaml.Resource]

          baml do
            client_module("not an atom")
          end
        end
      end
    end

    test "accepts valid client_module configuration" do
      defmodule ValidConfig do
        use Ash.Resource,
          domain: nil,
          extensions: [AshBaml.Resource]

        baml do
          client_module(AshBaml.Test.BamlClient)
        end
      end

      assert AshBaml.Info.baml_client_module(ValidConfig) == AshBaml.Test.BamlClient
    end

    test "accepts valid client identifier configuration" do
      # Test that client identifier is properly stored, without triggering full module generation
      # The actual module generation is tested in config_driven_clients_test.exs
      original_clients = Application.get_env(:ash_baml, :clients)

      try do
        # Set up minimal test client config (using existing test client to avoid BAML parsing)
        Application.put_env(:ash_baml, :clients,
          test_client: {AshBaml.Test.BamlClient, baml_src: "test/support/fixtures/baml_src"}
        )

        defmodule ValidClientIdentifier do
          use Ash.Resource,
            domain: nil,
            extensions: [AshBaml.Resource]

          baml do
            client(:test_client)
          end
        end

        assert AshBaml.Info.baml_client_identifier(ValidClientIdentifier) == :test_client
        assert AshBaml.Info.baml_client_module(ValidClientIdentifier) == AshBaml.Test.BamlClient
      after
        if original_clients do
          Application.put_env(:ash_baml, :clients, original_clients)
        else
          Application.delete_env(:ash_baml, :clients)
        end
      end
    end
  end
end
