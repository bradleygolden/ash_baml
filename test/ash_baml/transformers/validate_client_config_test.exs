defmodule AshBaml.Transformers.ValidateClientConfigTest do
  use ExUnit.Case, async: false

  alias Spark.Error.DslError

  setup do
    original_config = Application.get_env(:ash_baml, :clients, [])

    on_exit(fn ->
      Application.put_env(:ash_baml, :clients, original_config)
    end)

    :ok
  end

  describe "transform/1" do
    test "returns error when both :client and :client_module are specified" do
      Application.put_env(:ash_baml, :clients,
        test_client: {TestModule, baml_src: "test/support/fixtures/baml_src"}
      )

      assert_raise DslError, ~r/Cannot specify both :client and :client_module/, fn ->
        defmodule BothSpecifiedResource do
          use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

          baml do
            client(:test_client)
            client_module(SomeManualModule)
          end
        end
      end
    end

    test "returns error when neither :client nor :client_module is specified" do
      assert_raise DslError, ~r/Must specify either :client or :client_module/, fn ->
        defmodule NeitherSpecifiedResource do
          use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

          baml do
            # No client or client_module specified
          end
        end
      end
    end

    test "succeeds when only :client is specified" do
      unique_module =
        Module.concat([AshBaml.Test, "ValidClient#{System.unique_integer([:positive])}"])

      Application.put_env(:ash_baml, :clients,
        valid_client: {unique_module, baml_src: "test/support/fixtures/baml_src"}
      )

      # Should not raise
      defmodule OnlyClientResource do
        use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

        baml do
          client(:valid_client)
        end
      end

      assert Code.ensure_loaded?(OnlyClientResource)
    end

    test "succeeds when only :client_module is specified" do
      # Define a mock client module
      defmodule MockBamlClient do
        def functions, do: []
      end

      # Should not raise
      defmodule OnlyClientModuleResource do
        use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

        baml do
          client_module(MockBamlClient)
        end
      end

      assert Code.ensure_loaded?(OnlyClientModuleResource)
    end
  end

  describe "error messages" do
    test "error message for both specified includes helpful guidance" do
      Application.put_env(:ash_baml, :clients,
        guidance_test: {GuidanceModule, baml_src: "test/support/fixtures/baml_src"}
      )

      error =
        assert_raise DslError, fn ->
          defmodule BothSpecifiedForGuidanceResource do
            use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

            baml do
              client(:guidance_test)
              client_module(SomeModule)
            end
          end
        end

      assert error.message =~ "Config-driven (recommended)"
      assert error.message =~ "Manual client module"
    end

    test "error message for neither specified includes helpful guidance" do
      error =
        assert_raise DslError, fn ->
          defmodule NeitherSpecifiedForGuidanceResource do
            use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

            baml do
            end
          end
        end

      assert error.message =~ "Config-driven (recommended)"
      assert error.message =~ "Manual client module"
    end
  end
end
