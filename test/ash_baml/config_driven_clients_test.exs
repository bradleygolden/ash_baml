defmodule AshBaml.ConfigDrivenClientsTest do
  use ExUnit.Case, async: true

  describe "config-driven client pattern" do
    test "resolve_client_module returns nil for missing config" do
      assert AshBaml.Info.resolve_client_module(:nonexistent) == nil
    end

    test "client_baml_src returns nil for missing config" do
      assert AshBaml.Info.client_baml_src(:nonexistent) == nil
    end

    test "client identifier raises error when config is missing" do
      error =
        assert_raise RuntimeError, fn ->
          defmodule MissingConfigResource do
            use Ash.Resource,
              domain: nil,
              extensions: [AshBaml.Resource]

            baml do
              client(:nonexistent_client)
            end
          end
        end

      assert error.message =~ "BAML client :nonexistent_client not found"
    end
  end

  describe "legacy client_module pattern" do
    test "explicit client_module still works" do
      defmodule LegacyResource do
        use Ash.Resource,
          domain: nil,
          extensions: [AshBaml.Resource]

        baml do
          client_module(AshBaml.Test.BamlClient)
        end
      end

      assert AshBaml.Info.baml_client_module(LegacyResource) == AshBaml.Test.BamlClient
      assert AshBaml.Info.baml_client_identifier(LegacyResource) == nil
    end

    test "explicit client_module takes precedence over config" do
      defmodule PrecedenceResource do
        use Ash.Resource,
          domain: nil,
          extensions: [AshBaml.Resource]

        baml do
          client_module(AshBaml.Test.BamlClient)
        end
      end

      assert AshBaml.Info.baml_client_module(PrecedenceResource) == AshBaml.Test.BamlClient
    end
  end

  describe "validation" do
    test "missing both client and client_module raises error" do
      assert_raise RuntimeError, ~r/BAML client not configured/, fn ->
        defmodule MissingBothOptions do
          use Ash.Resource,
            domain: nil,
            extensions: [AshBaml.Resource]

          baml do
            # Neither client nor client_module specified
          end
        end
      end
    end

    test "transformer provides helpful error for missing config" do
      error =
        assert_raise RuntimeError, fn ->
          defmodule MissingConfigClient do
            use Ash.Resource,
              domain: nil,
              extensions: [AshBaml.Resource]

            baml do
              client(:undefined_client)
            end
          end
        end

      assert error.message =~ "BAML client :undefined_client not found"
      assert error.message =~ "config/config.exs"
    end
  end

  describe "backward compatibility" do
    test "legacy client_module pattern continues to work independently" do
      defmodule BackwardCompatResource do
        use Ash.Resource,
          domain: nil,
          extensions: [AshBaml.Resource]

        baml do
          client_module(AshBaml.Test.BamlClient)
        end
      end

      assert AshBaml.Info.baml_client_identifier(BackwardCompatResource) == nil
      assert AshBaml.Info.baml_client_module(BackwardCompatResource) == AshBaml.Test.BamlClient
    end
  end
end
