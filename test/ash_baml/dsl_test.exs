defmodule AshBaml.DslTest do
  use ExUnit.Case, async: true

  describe "baml DSL block" do
    test "requires client_module option" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule MissingClientModule do
          use Ash.Resource,
            domain: nil,
            extensions: [AshBaml.Resource]

          baml do
            # Missing client_module
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

    test "accepts valid configuration" do
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
  end
end
