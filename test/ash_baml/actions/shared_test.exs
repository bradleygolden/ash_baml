defmodule AshBaml.Actions.SharedTest do
  use ExUnit.Case, async: true
  alias AshBaml.Actions.Shared

  describe "build_client_not_configured_error/1" do
    test "returns error tuple with resource name" do
      assert {:error, message} = Shared.build_client_not_configured_error(MyApp.Resource)
      assert message =~ "BAML client not configured"
      assert message =~ "MyApp.Resource"
    end
  end

  describe "build_module_not_found_error/4" do
    test "returns error tuple with detailed message" do
      assert {:error, message} =
               Shared.build_module_not_found_error(
                 MyApp.Resource,
                 :test_function,
                 MyApp.BamlClient,
                 MyApp.BamlClient.TestFunction
               )

      assert message =~ "BAML function module not found"
      assert message =~ "MyApp.BamlClient.TestFunction"
      assert message =~ "Resource: MyApp.Resource"
      assert message =~ "Function: :test_function"
      assert message =~ "Client Module: MyApp.BamlClient"
      assert message =~ "Make sure:"
      assert message =~ "BAML file with a function named test_function"
      assert message =~ "uses BamlElixir.Client"
      assert message =~ "parsed your BAML files"
    end
  end

  describe "get_action_name/2" do
    test "returns name from action struct" do
      input = %{action: %{name: :my_action}}
      assert :my_action = Shared.get_action_name(input)
    end

    test "returns name when action is an atom" do
      input = %{action: :my_action}
      assert :my_action = Shared.get_action_name(input)
    end

    test "returns nil when action is nil" do
      input = %{action: nil}
      assert nil == Shared.get_action_name(input)
    end

    test "returns default when action is unknown type" do
      input = %{action: "string_action"}
      assert :unknown = Shared.get_action_name(input)
    end

    test "returns custom default when provided" do
      input = %{action: "string_action"}
      assert :custom_default = Shared.get_action_name(input, :custom_default)
    end

    test "returns custom default of nil when action is unknown and default is nil" do
      input = %{action: "string_action"}
      assert nil == Shared.get_action_name(input, nil)
    end
  end
end
