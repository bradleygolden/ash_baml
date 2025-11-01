defmodule AshBaml.TypeSystemIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  alias AshBaml.Test.{BamlClient, TestResource}

  describe "type system validation with real API calls" do
    test "string fields receive string values (not nil, not other types)" do
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:test_action, %{
          message: "Hello, world!"
        })
        |> Ash.run_action()

      # Verify result is a Reply struct with proper string field
      assert %BamlClient.Reply{} = result
      assert is_binary(result.content)
      assert String.length(result.content) > 0
      refute result.content == ""
    end

    test "integer fields receive integers (not string numbers)" do
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:multi_arg_action, %{
          name: "Alice",
          age: 25,
          topic: "technology"
        })
        |> Ash.run_action()

      # The age argument is an integer - verify the action accepts it
      # The response doesn't have an int field, but we verify the age was processed correctly
      assert %BamlClient.MultiArgResponse{} = result
      assert is_binary(result.greeting)
      assert is_binary(result.description)
      assert is_binary(result.age_category)

      # Age 25 should be categorized as "adult" (20-64)
      assert String.contains?(String.downcase(result.age_category), "adult")
    end

    test "float fields receive float values" do
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:test_action, %{
          message: "Give me a confidence score"
        })
        |> Ash.run_action()

      # Reply has a confidence float field
      assert %BamlClient.Reply{} = result
      assert is_float(result.confidence)
      assert result.confidence >= 0.0
      assert result.confidence <= 1.0
    end

    test "boolean fields receive boolean values" do
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:nested_object_action, %{
          user: %{
            name: "Bob",
            age: 30,
            address: %{
              street: "123 Main St",
              city: "Tokyo",
              country: "Japan",
              postal_code: "100-0001"
            }
          }
        })
        |> Ash.run_action()

      # NestedObjectResponse has is_international bool field
      assert %BamlClient.NestedObjectResponse{} = result
      assert is_boolean(result.is_international)

      # Japan is international (assuming US as home country per prompt)
      assert result.is_international == true
    end

    test "array fields receive arrays (not nil, not single values)" do
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:array_args_action, %{
          tags: ["elixir", "programming", "functional"]
        })
        |> Ash.run_action()

      assert %BamlClient.TagAnalysisResponse{} = result
      assert is_binary(result.category)

      {:ok, profile_result} =
        TestResource
        |> Ash.ActionInput.for_action(:optional_args_action, %{
          name: "Charlie",
          age: 28,
          location: "Berlin"
        })
        |> Ash.run_action()

      # ProfileResponse has interests string[] field
      assert %BamlClient.ProfileResponse{} = profile_result
      assert is_list(profile_result.interests)
      assert length(profile_result.interests) > 0

      # Each element should be a string
      Enum.each(profile_result.interests, fn interest ->
        assert is_binary(interest)
      end)
    end

    test "optional fields can be nil" do
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:optional_args_action, %{
          name: "David",
          age: 35,
          # location is optional, not providing it
          location: nil
        })
        |> Ash.run_action()

      assert %BamlClient.ProfileResponse{} = result

      assert result.location in [nil, ""],
             "Expected location to be nil or empty, got: #{inspect(result.location)}"
    end

    test "optional fields can have values" do
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:optional_args_action, %{
          name: "Eve",
          age: 42,
          location: "Paris"
        })
        |> Ash.run_action()

      # ProfileResponse has location string? (optional) field
      assert %BamlClient.ProfileResponse{} = result

      # Location should be populated when provided
      assert result.location != nil
      assert is_binary(result.location)
      assert String.contains?(String.downcase(result.location), "paris")
    end

    test "nested object fields work correctly" do
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:nested_object_action, %{
          user: %{
            name: "Frank",
            age: 45,
            address: %{
              street: "456 Oak Ave",
              city: "London",
              country: "UK",
              postal_code: "SW1A 1AA"
            }
          }
        })
        |> Ash.run_action()

      # NestedObjectResponse processes nested Address object
      assert %BamlClient.NestedObjectResponse{} = result
      assert is_binary(result.formatted_address)
      assert is_binary(result.distance_category)
      assert is_boolean(result.is_international)

      # Verify the nested data was processed correctly
      assert String.contains?(result.formatted_address, "Frank") or
               String.contains?(result.formatted_address, "London")

      assert String.contains?(result.formatted_address, "UK")
    end
  end

  describe "type coercion behavior" do
    test "integer argument accepts integer values" do
      # This tests that Ash's type system correctly accepts integers
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:multi_arg_action, %{
          name: "Test",
          age: 30,
          # Using actual integer
          topic: "test"
        })
        |> Ash.run_action()

      assert %BamlClient.MultiArgResponse{} = result
    end

    # Test removed: "string argument requires string (not atom)"
    # Reason: Ash's :string type automatically coerces atoms to strings
    # This is correct framework behavior, not a validation failure
    # See: Ash.Type.String - supports atom-to-string coercion
  end

  describe "complex type combinations" do
    test "struct with multiple field types works correctly" do
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:test_action, %{
          message: "Complex type test"
        })
        |> Ash.run_action()

      # Reply struct has both string (content) and float (confidence)
      assert %BamlClient.Reply{} = result
      assert is_binary(result.content)
      assert is_float(result.confidence)
    end

    test "array of strings works correctly" do
      {:ok, result} =
        TestResource
        |> Ash.ActionInput.for_action(:long_input_action, %{
          long_text: String.duplicate("word ", 100)
        })
        |> Ash.run_action()

      # LongInputResponse has key_topics string[]
      assert %BamlClient.LongInputResponse{} = result
      assert is_binary(result.summary)
      assert is_integer(result.word_count)
      assert is_list(result.key_topics)

      # Verify each topic is a string
      Enum.each(result.key_topics, fn topic ->
        assert is_binary(topic)
      end)
    end
  end
end
