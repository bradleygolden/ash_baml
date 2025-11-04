defmodule AshBaml.HelpersTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info

  defmodule TestResource do
    use Ash.Resource,
      domain: TestDomain,
      extensions: [AshBaml.Resource]

    baml do
      client_module(AshBaml.Test.BamlClient)
    end

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:read])

      action :test_call_baml, :string do
        run(call_baml(:TestFunction))
      end

      action :test_call_baml_with_opts, :string do
        run(call_baml(:TestFunction, telemetry: false))
      end

      action :test_call_baml_stream, AshBaml.Type.Stream do
        run(call_baml_stream(:TestFunction))
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource(TestResource)
    end
  end

  describe "call_baml/1 macro" do
    test "expands to CallBamlFunction action tuple with function name" do
      action = Info.action(TestResource, :test_call_baml)

      assert action.run == {AshBaml.Actions.CallBamlFunction, [function: :TestFunction]}
    end

    test "action is properly configured on the resource" do
      action = Info.action(TestResource, :test_call_baml)

      assert action.name == :test_call_baml
      assert action.returns == Ash.Type.String
      assert action.type == :action
    end
  end

  describe "call_baml/2 macro" do
    test "expands to CallBamlFunction action tuple with function name and options" do
      action = Info.action(TestResource, :test_call_baml_with_opts)

      assert action.run ==
               {AshBaml.Actions.CallBamlFunction, [function: :TestFunction, telemetry: false]}
    end

    test "merges function name with user-provided options" do
      action = Info.action(TestResource, :test_call_baml_with_opts)

      opts = elem(action.run, 1)
      assert Keyword.get(opts, :function) == :TestFunction
      assert Keyword.get(opts, :telemetry) == false
    end
  end

  describe "call_baml_stream/1 macro" do
    test "expands to CallBamlStream action tuple with function name" do
      action = Info.action(TestResource, :test_call_baml_stream)

      assert action.run == {AshBaml.Actions.CallBamlStream, [function: :TestFunction]}
    end

    test "action returns AshBaml.Type.Stream type" do
      action = Info.action(TestResource, :test_call_baml_stream)

      assert action.returns == AshBaml.Type.Stream
    end
  end
end
