defmodule AshBaml.Integration.Basic.OllamaTest do
  use AshBaml.IntegrationCase, provider: :ollama

  @moduletag timeout: 60_000

  describe "end-to-end BAML integration" do
    test "can call BAML function through Ash action" do
      {:ok, response} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:test_action, %{message: "Hello!"})
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %AshBaml.Test.BamlClient.Types.Reply{} = result
      assert is_binary(result.content)
      assert is_float(result.confidence)
    end

    test "can call BAML function with multiple arguments" do
      {:ok, response} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:multi_arg_action, %{
          name: "Alice",
          age: 30,
          topic: "artificial intelligence"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %AshBaml.Test.BamlClient.Types.MultiArgResponse{} = result

      assert is_binary(result.greeting)
      assert is_binary(result.description)
      assert is_binary(result.age_category)

      assert is_binary(result.greeting)
      assert String.length(result.greeting) > 0
      assert result.age_category in ["child", "teen", "adult", "senior"]
      assert String.length(result.description) > 0
    end

    test "can call BAML function with optional arguments" do
      {:ok, response_with_location} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:optional_args_action, %{
          name: "Bob",
          age: 25,
          location: "San Francisco"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response_with_location
      result_with_location = response_with_location.data
      assert %AshBaml.Test.BamlClient.Types.ProfileResponse{} = result_with_location
      assert is_binary(result_with_location.bio)
      assert is_list(result_with_location.interests)
      assert is_binary(result_with_location.location)
      assert result_with_location.location == "San Francisco"

      {:ok, response_without_location} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:optional_args_action, %{
          name: "Charlie",
          age: 35
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response_without_location
      result_without_location = response_without_location.data
      assert %AshBaml.Test.BamlClient.Types.ProfileResponse{} = result_without_location
      assert is_binary(result_without_location.bio)
      assert is_list(result_without_location.interests)
      assert is_nil(result_without_location.location)
    end

    test "can call BAML function with array arguments" do
      tags = ["elixir", "programming", "functional", "erlang", "beam"]

      {:ok, response} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:array_args_action, %{tags: tags})
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %AshBaml.Test.BamlClient.Types.TagAnalysisResponse{} = result

      assert is_binary(result.summary)
      assert is_integer(result.tag_count)
      assert result.tag_count == length(tags)

      assert String.length(result.summary) > 0

      assert is_binary(result.most_common_tag) or is_nil(result.most_common_tag)
    end

    test "can call BAML function with nested object arguments" do
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

      {:ok, response} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:nested_object_action, %{user: user})
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %AshBaml.Test.BamlClient.Types.NestedObjectResponse{} = result

      assert is_binary(result.formatted_address)
      assert is_binary(result.distance_category)
      assert is_boolean(result.is_international)

      assert String.length(result.formatted_address) > 0
      assert result.distance_category in ["local", "regional", "international"]
      assert result.is_international == true
    end

    test "can call BAML function with very long input (>2000 chars)" do
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

      assert String.length(long_text) > 2000

      {:ok, response} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:long_input_action, %{long_text: long_text})
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %AshBaml.Test.BamlClient.Types.LongInputResponse{} = result

      assert is_binary(result.summary)
      assert is_integer(result.word_count)
      assert is_list(result.key_topics)

      assert String.length(result.summary) > 0
      assert result.word_count > 0
      assert is_list(result.key_topics)
      assert length(result.key_topics) > 0, "Expected at least one topic"
    end

    test "can call BAML function with special characters" do
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

      {:ok, response} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:special_chars_action, %{
          text_with_special_chars: special_text
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      result = response.data
      assert %AshBaml.Test.BamlClient.Types.SpecialCharsResponse{} = result

      assert is_binary(result.received_text)
      assert is_integer(result.char_count)
      assert is_boolean(result.has_quotes)
      assert is_boolean(result.has_newlines)
      assert is_boolean(result.has_special_symbols)

      assert String.length(result.received_text) > 0
      assert result.char_count > 0
      assert result.has_quotes == true
      assert result.has_newlines == true
      assert result.has_special_symbols == true

      assert is_binary(result.received_text)
      assert String.length(result.received_text) > 0
    end

    test "can handle concurrent function calls (5+ parallel)" do
      tasks =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            message = "Concurrent test message #{i}"

            {:ok, response} =
              AshBaml.Test.TestResource
              |> Ash.ActionInput.for_action(:test_action, %{message: message})
              |> Ash.run_action()

            {i, response.data, message}
          end)
        end)

      results = Task.await_many(tasks, 30_000)

      assert length(results) == 5

      Enum.each(results, fn {_i, result, _original_message} ->
        assert %AshBaml.Test.BamlClient.Types.Reply{} = result

        assert is_binary(result.content)
        assert is_float(result.confidence)

        assert String.length(result.content) > 0

        assert result.confidence >= 0.0 and result.confidence <= 1.0
      end)

      assert length(results) == 5
    end

    test "same function called multiple times returns consistent structure" do
      input_message = "Tell me about consistency in testing"

      results =
        Enum.map(1..3, fn _i ->
          {:ok, response} =
            AshBaml.Test.TestResource
            |> Ash.ActionInput.for_action(:test_action, %{message: input_message})
            |> Ash.run_action()

          response.data
        end)

      assert length(results) == 3

      Enum.each(results, fn result ->
        assert %AshBaml.Test.BamlClient.Types.Reply{} = result

        assert is_binary(result.content)
        assert is_float(result.confidence)

        assert String.length(result.content) > 0
        assert result.confidence >= 0.0 and result.confidence <= 1.0
      end)

      [first | rest] = results

      Enum.each(rest, fn result ->
        assert result.__struct__ == first.__struct__

        assert is_binary(result.content) == is_binary(first.content)
        assert is_float(result.confidence) == is_float(first.confidence)

        assert String.length(result.content) > 0
        assert String.length(first.content) > 0
      end)
    end
  end
end
