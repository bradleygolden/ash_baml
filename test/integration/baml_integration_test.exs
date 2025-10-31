defmodule AshBaml.IntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  # This test uses the actual BAML files and real baml_elixir code generation
  # It does NOT make real LLM API calls - we'll mock the NIF for now

  describe "end-to-end BAML integration" do
    test "can call BAML function through Ash action" do
      # This test verifies:
      # 1. BAML files are parsed by baml_elixir
      # 2. Modules are generated correctly
      # 3. AshBaml can call them
      # 4. Results are returned properly

      # Note: In a real test, you'd need OPENAI_API_KEY set
      # For now, we'll skip if not available
      # unless System.get_env("OPENAI_API_KEY") do
      #   IO.puts("Skipping integration test - OPENAI_API_KEY not set")
      #   :ok
      # else
      {:ok, result} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:test_action, %{message: "Hello!"})
        |> Ash.run_action()

      assert %AshBaml.Test.BamlClient.Reply{} = result
      assert is_binary(result.content)
      assert is_float(result.confidence)
      # end
    end

    test "can call BAML function with multiple arguments" do
      # This test verifies that functions with multiple arguments work correctly
      # - Multiple argument types (string, integer, string)
      # - Arguments are passed correctly to BAML function
      # - Response structure matches expected type

      {:ok, result} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:multi_arg_action, %{
          name: "Alice",
          age: 30,
          topic: "artificial intelligence"
        })
        |> Ash.run_action()

      # Verify correct response structure
      assert %AshBaml.Test.BamlClient.MultiArgResponse{} = result

      # Verify all fields are present and correct types
      assert is_binary(result.greeting)
      assert is_binary(result.description)
      assert is_binary(result.age_category)

      # Verify content makes sense
      assert String.contains?(result.greeting, "Alice") or String.contains?(result.greeting, "30")
      assert result.age_category in ["child", "teen", "adult", "senior"]
      assert String.length(result.description) > 0
    end

    test "can call BAML function with optional arguments" do
      # Test with optional argument provided
      {:ok, result_with_location} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:optional_args_action, %{
          name: "Bob",
          age: 25,
          location: "San Francisco"
        })
        |> Ash.run_action()

      # Verify correct response structure
      assert %AshBaml.Test.BamlClient.ProfileResponse{} = result_with_location
      assert is_binary(result_with_location.bio)
      assert is_list(result_with_location.interests)
      assert is_binary(result_with_location.location)
      assert result_with_location.location == "San Francisco"

      # Test without optional argument
      {:ok, result_without_location} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:optional_args_action, %{
          name: "Charlie",
          age: 35
        })
        |> Ash.run_action()

      # Verify correct response structure
      assert %AshBaml.Test.BamlClient.ProfileResponse{} = result_without_location
      assert is_binary(result_without_location.bio)
      assert is_list(result_without_location.interests)
      # Location should be nil when not provided
      assert is_nil(result_without_location.location)
    end
  end
end
