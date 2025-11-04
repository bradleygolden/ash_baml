defmodule AshBaml.Transformers.ImportBamlFunctionsTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info, as: ResourceInfo
  alias AshBaml.Transformers.ImportBamlFunctions
  alias Spark.Dsl.Transformer

  defmodule TestResource do
    use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

    baml do
      client_module(AshBaml.Test.BamlClient)
      import_functions([:TestFunction])
    end
  end

  defmodule TestFunctionDuplicateResource do
    use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

    baml do
      client_module(AshBaml.Test.BamlClient)
      import_functions([:TestFunction, :TestFunction])
    end
  end

  defmodule NoImportResource do
    use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

    baml do
      client_module(AshBaml.Test.BamlClient)
    end
  end

  defmodule MinimalResource do
    use Ash.Resource, domain: nil
  end

  describe "after?/1" do
    test "returns false for all transformers" do
      refute ImportBamlFunctions.after?(SomeTransformer)
      refute ImportBamlFunctions.after?(AnotherTransformer)
    end
  end

  describe "before?/1" do
    test "returns false for all transformers" do
      refute ImportBamlFunctions.before?(SomeTransformer)
      refute ImportBamlFunctions.before?(AnotherTransformer)
    end
  end

  describe "transform/1" do
    test "creates both regular and streaming actions for single imported function" do
      actions = ResourceInfo.actions(TestResource)

      assert action = Enum.find(actions, &(&1.name == :test_function))
      assert action.type == :action
      assert action.returns == AshBaml.Test.BamlClient.Types.Reply
      assert [argument] = action.arguments
      assert argument.name == :message
      assert argument.type == Ash.Type.String
      assert action.description == "Auto-generated from BAML function TestFunction"

      assert stream_action = Enum.find(actions, &(&1.name == :test_function_stream))
      assert stream_action.type == :action
      assert stream_action.returns == AshBaml.Type.Stream
      assert [stream_argument] = stream_action.arguments
      assert stream_argument.name == :message
      assert stream_argument.type == Ash.Type.String

      assert stream_action.constraints[:element_type] == AshBaml.Test.BamlClient.Types.Reply
    end

    test "handles duplicate function imports correctly" do
      actions = ResourceInfo.actions(TestFunctionDuplicateResource)

      test_function_actions =
        Enum.filter(actions, &(&1.name == :test_function))

      assert length(test_function_actions) == 1
    end

    test "does not affect resources without AshBaml extension" do
      actions = ResourceInfo.actions(MinimalResource)

      refute Enum.any?(actions, &String.contains?(Atom.to_string(&1.name), "test_function"))
    end

    test "returns dsl_state unchanged when import_functions is empty" do
      actions = ResourceInfo.actions(NoImportResource)

      refute Enum.any?(actions, &String.contains?(Atom.to_string(&1.name), "test_function"))
    end

    test "converts function names to action names using underscore convention" do
      defmodule CamelCaseResource do
        use Ash.Resource, domain: nil, extensions: [AshBaml.Resource]

        baml do
          client_module(AshBaml.Test.BamlClient)
          import_functions([:TestFunction])
        end
      end

      actions = ResourceInfo.actions(CamelCaseResource)
      assert Enum.find(actions, &(&1.name == :test_function))
      assert Enum.find(actions, &(&1.name == :test_function_stream))
    end

    test "sets proper action implementation for regular actions" do
      actions = ResourceInfo.actions(TestResource)
      action = Enum.find(actions, &(&1.name == :test_function))

      assert {AshBaml.Actions.CallBamlFunction, opts} = action.run
      assert opts[:function] == :TestFunction
    end

    test "sets proper action implementation for streaming actions" do
      actions = ResourceInfo.actions(TestResource)
      stream_action = Enum.find(actions, &(&1.name == :test_function_stream))

      assert {AshBaml.Actions.CallBamlStream, opts} = stream_action.run
      assert opts[:function] == :TestFunction
    end

    test "handles function with single argument" do
      actions = ResourceInfo.actions(TestResource)
      action = Enum.find(actions, &(&1.name == :test_function))

      assert length(action.arguments) == 1
      [arg] = action.arguments
      assert arg.name == :message
      assert arg.type == Ash.Type.String
      assert arg.allow_nil? == false
    end
  end
end
