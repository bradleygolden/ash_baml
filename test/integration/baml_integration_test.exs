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

    test "can call BAML function with array arguments" do
      # This test verifies that functions with array arguments work correctly
      # - Array of strings is passed to BAML function
      # - Array is properly serialized and sent to LLM
      # - Response includes information based on array content

      tags = ["elixir", "programming", "functional", "erlang", "beam"]

      {:ok, result} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:array_args_action, %{tags: tags})
        |> Ash.run_action()

      # Verify correct response structure
      assert %AshBaml.Test.BamlClient.TagAnalysisResponse{} = result

      # Verify all fields are present and correct types
      assert is_binary(result.summary)
      assert is_integer(result.tag_count)
      assert result.tag_count == length(tags)

      # Verify content makes sense
      assert String.length(result.summary) > 0

      # most_common_tag is optional
      assert is_binary(result.most_common_tag) or is_nil(result.most_common_tag)
    end

    test "can call BAML function with nested object arguments" do
      # This test verifies that functions with nested object arguments work correctly
      # - Nested map structure is passed to BAML function
      # - Nested fields are properly accessed in BAML template
      # - Response includes information based on nested data

      user = %{
        name: "Alice Johnson",
        age: 32,
        address: %{
          street: "123 Main St",
          city: "Toronto",
          country: "Canada",
          postal_code: "M5V 3A8"
        }
      }

      {:ok, result} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:nested_object_action, %{user: user})
        |> Ash.run_action()

      # Verify correct response structure
      assert %AshBaml.Test.BamlClient.NestedObjectResponse{} = result

      # Verify all fields are present and correct types
      assert is_binary(result.formatted_address)
      assert is_binary(result.distance_category)
      assert is_boolean(result.is_international)

      # Verify content makes sense
      assert String.length(result.formatted_address) > 0
      assert result.distance_category in ["local", "regional", "international"]
      # Canada is international from US perspective
      assert result.is_international == true
    end

    test "can call BAML function with very long input (>2000 chars)" do
      # This test verifies that functions handle very long inputs correctly
      # - Long text (>2000 chars) is passed to BAML function
      # - LLM can process and analyze long context
      # - Response structure is maintained with large inputs
      # - No truncation or data loss occurs

      # Create a text that is >2000 characters
      # Using Lorem Ipsum paragraphs repeated to ensure length
      long_text =
        """
        The history of artificial intelligence (AI) is a fascinating journey that spans several decades
        and encompasses numerous breakthroughs, setbacks, and paradigm shifts. From its inception in the
        mid-20th century to the present day, AI has evolved from a theoretical concept to a practical
        technology that impacts virtually every aspect of modern life.

        The foundations of AI were laid in the 1950s when pioneers like Alan Turing began exploring the
        possibility of machines that could think. Turing's famous question, "Can machines think?" sparked
        a revolution in computer science and philosophy. The Dartmouth Conference of 1956, organized by
        John McCarthy, Marvin Minsky, Nathaniel Rochester, and Claude Shannon, is often considered the
        birth of AI as a formal field of study. During this conference, the term "artificial intelligence"
        was coined, and researchers began to explore how machines could be programmed to simulate aspects
        of human intelligence.

        The early years of AI research were characterized by optimism and ambitious goals. Researchers
        developed early AI programs that could solve algebra problems, prove logical theorems, and play
        games like chess and checkers. The Logic Theorist, created by Allen Newell and Herbert A. Simon
        in 1956, was one of the first AI programs and could prove mathematical theorems. This period saw
        the development of important concepts such as search algorithms, knowledge representation, and
        symbolic reasoning.

        However, the field soon encountered significant challenges. The limitations of early computers,
        the complexity of human intelligence, and the difficulty of scaling simple programs to handle
        real-world problems led to what became known as the "AI winters" - periods of reduced funding
        and interest in AI research. The first AI winter occurred in the 1970s when it became clear that
        many of the early promises of AI had been overly optimistic. Expert systems, which attempted to
        capture human expertise in specific domains, showed some promise but were limited in their scope
        and flexibility.

        The 1980s brought renewed interest in AI with the rise of expert systems and the development of
        new approaches to machine learning. Neural networks, inspired by the structure of the human brain,
        began to gain attention. Researchers like Geoffrey Hinton, Yann LeCun, and Yoshua Bengio made
        important contributions to the development of backpropagation and deep learning algorithms.
        However, another AI winter in the late 1980s and early 1990s dampened enthusiasm once again.

        The turn of the millennium marked a significant turning point for AI. Advances in computing power,
        the availability of large datasets, and improvements in algorithms led to breakthroughs in machine
        learning and deep learning. The victory of IBM's Deep Blue over world chess champion Garry Kasparov
        in 1997 demonstrated the potential of AI in complex problem-solving. More recently, Google's AlphaGo
        defeated world champion Go player Lee Sedol in 2016, showcasing the power of reinforcement learning
        and neural networks.
        """ <> String.duplicate(" Additional context padding.", 50)

      # Verify the text is indeed >2000 chars
      assert String.length(long_text) > 2000

      {:ok, result} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:long_input_action, %{long_text: long_text})
        |> Ash.run_action()

      # Verify correct response structure
      assert %AshBaml.Test.BamlClient.LongInputResponse{} = result

      # Verify all fields are present and correct types
      assert is_binary(result.summary)
      assert is_integer(result.word_count)
      assert is_list(result.key_topics)

      # Verify content makes sense
      assert String.length(result.summary) > 0
      assert result.word_count > 0
      assert length(result.key_topics) >= 3 and length(result.key_topics) <= 5

      # Verify the summary reflects content from the long text
      # Should mention AI or artificial intelligence since that's the main topic
      summary_lower = String.downcase(result.summary)

      assert String.contains?(summary_lower, "ai") or
               String.contains?(summary_lower, "artificial")
    end

    test "can call BAML function with special characters" do
      # This test verifies that functions handle special characters correctly
      # - Text with quotes, apostrophes, newlines, tabs, and special symbols
      # - Characters are properly escaped and transmitted to LLM
      # - Response correctly identifies the presence of special characters
      # - No data corruption or encoding issues occur

      special_text = """
      Hello "world"! This is a test with 'special' characters.
      It includes:
      - Double quotes: "test"
      - Single quotes: 'test'
      - Apostrophes: don't, won't, it's
      - Newlines and tabs:\tlike this
      - Special symbols: @#$%&*()[]{}!?
      - Unicode: émojis 🎉 and ñoño
      - Backslashes: \\ and forward slashes: /
      - Less than < and greater than >
      """

      {:ok, result} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:special_chars_action, %{
          text_with_special_chars: special_text
        })
        |> Ash.run_action()

      # Verify correct response structure
      assert %AshBaml.Test.BamlClient.SpecialCharsResponse{} = result

      # Verify all fields are present and correct types
      assert is_binary(result.received_text)
      assert is_integer(result.char_count)
      assert is_boolean(result.has_quotes)
      assert is_boolean(result.has_newlines)
      assert is_boolean(result.has_special_symbols)

      # Verify content makes sense
      assert String.length(result.received_text) > 0
      assert result.char_count > 0
      # Text definitely has quotes
      assert result.has_quotes == true
      # Text definitely has newlines
      assert result.has_newlines == true
      # Text definitely has special symbols
      assert result.has_special_symbols == true

      # Verify key content is preserved (not checking exact match due to LLM interpretation)
      received_lower = String.downcase(result.received_text)

      assert String.contains?(received_lower, "special") or
               String.contains?(received_lower, "test")
    end

    test "can handle concurrent function calls (5+ parallel)" do
      # This test verifies that ash_baml handles concurrent operations correctly
      # - Multiple BAML function calls in parallel (5 concurrent tasks)
      # - Each call completes successfully without interference
      # - Results are independent and correct for each call
      # - No race conditions or shared state issues
      # - Performance: all calls complete within reasonable time
      #
      # CLUSTERING NOTE: This test assumes single-node operation.
      # In a distributed Erlang cluster, these concurrent calls could
      # potentially run on different nodes. The design should ensure:
      # - No shared mutable state between calls
      # - Each call is completely isolated
      # - Results are properly routed back to calling process
      # - No assumptions about process locality

      # Create 5 different tasks that will run concurrently
      tasks =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            message = "Concurrent test message #{i}"

            {:ok, result} =
              AshBaml.Test.TestResource
              |> Ash.ActionInput.for_action(:test_action, %{message: message})
              |> Ash.run_action()

            {i, result, message}
          end)
        end)

      # Wait for all tasks to complete (timeout: 30 seconds total)
      results = Task.await_many(tasks, 30_000)

      # Verify we got exactly 5 results
      assert length(results) == 5

      # Verify each result is correct
      Enum.each(results, fn {i, result, _original_message} ->
        # Verify correct response structure
        assert %AshBaml.Test.BamlClient.Reply{} = result

        # Verify all fields are present and correct types
        assert is_binary(result.content)
        assert is_float(result.confidence)

        # Verify content is non-empty
        assert String.length(result.content) > 0

        # Verify confidence is in valid range
        assert result.confidence >= 0.0 and result.confidence <= 1.0

        # Log for debugging
        IO.puts("Task #{i} completed: #{String.slice(result.content, 0..50)}...")
      end)

      # Verify that all tasks completed (none timed out or failed)
      assert length(results) == 5
    end
  end
end
