defmodule AshBaml.TypeSystemIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  alias AshBaml.Test.BamlClient.Types, as: BamlClient
  alias AshBaml.Test.TestResource

  describe "type system validation with real API calls" do
    test "string fields receive string values (not nil, not other types)" do
      {:ok, response} =
        TestResource
        |> Ash.ActionInput.for_action(:test_action, %{
          message: "Hello, world!"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.Reply{} = result
      assert is_binary(result.content)
      assert String.length(result.content) > 0
      refute result.content == ""
    end

    test "integer fields receive integers (not string numbers)" do
      {:ok, response} =
        TestResource
        |> Ash.ActionInput.for_action(:multi_arg_action, %{
          name: "Alice",
          age: 25,
          topic: "technology"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.MultiArgResponse{} = result
      assert is_binary(result.greeting)
      assert is_binary(result.description)
      assert is_binary(result.age_category)
      assert String.contains?(String.downcase(result.age_category), "adult")
    end

    test "float fields receive float values" do
      {:ok, response} =
        TestResource
        |> Ash.ActionInput.for_action(:test_action, %{
          message: "Give me a confidence score"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.Reply{} = result
      assert is_float(result.confidence)
      assert result.confidence >= 0.0
      assert result.confidence <= 1.0
    end

    test "boolean fields receive boolean values" do
      {:ok, response} =
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

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.NestedObjectResponse{} = result
      assert is_boolean(result.is_international)
      assert result.is_international == true
    end

    test "array fields receive arrays (not nil, not single values)" do
      {:ok, response} =
        TestResource
        |> Ash.ActionInput.for_action(:array_args_action, %{
          tags: ["elixir", "programming", "functional"]
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.TagAnalysisResponse{} = result
      assert is_binary(result.summary)
      assert is_integer(result.tag_count)
      assert result.tag_count == 3

      {:ok, profile_response} =
        TestResource
        |> Ash.ActionInput.for_action(:optional_args_action, %{
          name: "Charlie",
          age: 28,
          location: "Berlin"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = profile_response
      profile_result = profile_response.data
      assert %BamlClient.ProfileResponse{} = profile_result
      assert is_list(profile_result.interests)
      assert length(profile_result.interests) > 0

      Enum.each(profile_result.interests, fn interest ->
        assert is_binary(interest)
      end)
    end

    test "optional fields can be nil" do
      {:ok, response} =
        TestResource
        |> Ash.ActionInput.for_action(:optional_args_action, %{
          name: "David",
          age: 35,
          location: nil
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.ProfileResponse{} = result

      assert result.location in [nil, ""],
             "Expected location to be nil or empty, got: #{inspect(result.location)}"
    end

    test "optional fields can have values" do
      {:ok, response} =
        TestResource
        |> Ash.ActionInput.for_action(:optional_args_action, %{
          name: "Eve",
          age: 42,
          location: "Paris"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.ProfileResponse{} = result
      assert result.location != nil
      assert is_binary(result.location)
      assert String.contains?(String.downcase(result.location), "paris")
    end

    test "nested object fields work correctly" do
      {:ok, response} =
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

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.NestedObjectResponse{} = result
      assert is_binary(result.formatted_address)
      assert is_binary(result.distance_category)
      assert is_boolean(result.is_international)

      assert String.contains?(result.formatted_address, "Frank") or
               String.contains?(result.formatted_address, "London")

      assert String.contains?(result.formatted_address, "UK")
    end
  end

  describe "type coercion behavior" do
    test "integer argument accepts integer values" do
      {:ok, response} =
        TestResource
        |> Ash.ActionInput.for_action(:multi_arg_action, %{
          name: "Test",
          age: 30,
          topic: "test"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.MultiArgResponse{} = result
    end
  end

  describe "complex type combinations" do
    test "struct with multiple field types works correctly" do
      {:ok, response} =
        TestResource
        |> Ash.ActionInput.for_action(:test_action, %{
          message: "Complex type test"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.Reply{} = result
      assert is_binary(result.content)
      assert is_float(result.confidence)
    end

    test "array of strings works correctly" do
      {:ok, response} =
        TestResource
        |> Ash.ActionInput.for_action(:long_input_action, %{
          long_text: String.duplicate("word ", 100)
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %BamlClient.LongInputResponse{} = result
      assert is_binary(result.summary)
      assert is_integer(result.word_count)
      assert is_list(result.key_topics)

      Enum.each(result.key_topics, fn topic ->
        assert is_binary(topic)
      end)
    end
  end
end
