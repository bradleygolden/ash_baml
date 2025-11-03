# Actions

Understanding how ash_baml integrates with Ash's action system for BAML function calls.

## Overview

ash_baml leverages Ash's powerful action system to provide a consistent interface for LLM interactions. Every BAML function call happens through an Ash action, giving you:

- **Consistent Interface**: Use `Ash.ActionInput` and `Ash.run_action/1` for all LLM calls
- **Authorization**: Ash policies work on BAML actions
- **Validation**: Argument validation using Ash types
- **Telemetry**: Automatic instrumentation of all actions
- **Composability**: Mix BAML actions with regular Ash actions

## Action Types

### Auto-Generated Actions

When you use `import_functions`, ash_baml automatically generates two actions per BAML function:

```elixir
defmodule MyApp.Assistant do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:SayHello]
  end

  # Auto-generates:
  # - :say_hello (returns Reply)
  # - :say_hello_stream (returns Stream)
end
```

#### Regular Action

Returns the complete result:

```elixir
{:ok, result} = MyApp.Assistant
  |> Ash.ActionInput.for_action(:say_hello, %{name: "Alice"})
  |> Ash.run_action()

result
# => %MyApp.BamlClient.Types.Reply{content: "Hello Alice!", confidence: 0.95}
```

**Implementation**: Uses `AshBaml.Actions.CallBamlFunction`

#### Streaming Action

Returns a stream for incremental results:

```elixir
{:ok, stream} = MyApp.Assistant
  |> Ash.ActionInput.for_action(:say_hello_stream, %{name: "Bob"})
  |> Ash.run_action()

stream |> Stream.each(&IO.inspect/1) |> Stream.run()
# Outputs partial results as they arrive
```

**Implementation**: Uses `AshBaml.Actions.CallBamlStream`

### Return Types

Auto-generated actions infer return types from BAML:

| BAML Return Type | Ash Action Type | Returns |
|------------------|-----------------|---------|
| `class User` | Matches generated type | `MyApp.BamlClient.Types.User.t()` |
| `string` | `:string` | `String.t()` |
| `int` | `:integer` | `integer()` |
| `float` | `:float` | `float()` |
| `bool` | `:boolean` | `boolean()` |
| `Tool1 \| Tool2` | `:union` | `Ash.Union.t()` |

For complex return types, manually specify the action type:

```elixir
# BAML: function GetData() -> DataClass { ... }
actions do
  action :get_data, MyApp.BamlClient.Types.DataClass do
    run call_baml(:GetData)
  end

  action :get_data_stream, AshBaml.Type.Stream do
    run call_baml_stream(:GetData)
  end
end
```

## Manual Action Definition

For more control, define actions manually:

### Basic Manual Action

```elixir
actions do
  action :custom_hello, :string do
    argument :name, :string, allow_nil?: false
    argument :language, :string, default: "en"

    run call_baml(:SayHello)
  end
end
```

**When to use:**
- Add custom arguments
- Set argument defaults
- Change action name
- Add argument constraints

### With Validation

Add validation before calling BAML:

```elixir
actions do
  action :extract_email, MyApp.BamlClient.Types.Email do
    argument :text, :string, allow_nil?: false

    validate fn input, _ctx ->
      if String.length(input.arguments.text) < 10 do
        {:error, "Text too short for extraction"}
      else
        :ok
      end
    end

    run call_baml(:ExtractEmail)
  end
end
```

### With Authorization

Apply Ash policies to BAML actions:

```elixir
defmodule MyApp.Assistant do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  policies do
    policy action(:extract_sensitive_data) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action_type(:action) do
      authorize_if always()
    end
  end

  actions do
    action :extract_sensitive_data, :map do
      argument :text, :string

      run call_baml(:ExtractSensitiveData)
    end
  end
end
```

Usage:

```elixir
# Only admins can call this
{:ok, result} = MyApp.Assistant
  |> Ash.ActionInput.for_action(:extract_sensitive_data, %{text: "..."})
  |> Ash.run_action(actor: current_user)
```

## Custom Action Implementation

For complex logic, implement `Ash.Resource.Actions.Implementation`:

### Pattern: Pre-processing + BAML

```elixir
defmodule MyApp.PreprocessAndExtract do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    # Pre-process
    cleaned_text = input.arguments.text
      |> String.trim()
      |> String.downcase()

    # Call BAML
    MyApp.Extractor
    |> Ash.ActionInput.for_action(:extract_data, %{text: cleaned_text})
    |> Ash.run_action()
  end
end

# In resource
actions do
  action :preprocess_and_extract, MyApp.BamlClient.Types.Data do
    argument :text, :string

    run MyApp.PreprocessAndExtract
  end
end
```

### Pattern: BAML + Post-processing

```elixir
defmodule MyApp.ExtractAndSave do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    # Call BAML
    with {:ok, extracted} <- extract_baml(input),
         {:ok, saved} <- save_to_db(extracted) do
      {:ok, saved}
    end
  end

  defp extract_baml(input) do
    MyApp.Extractor
    |> Ash.ActionInput.for_action(:extract_user, %{text: input.arguments.text})
    |> Ash.run_action()
  end

  defp save_to_db(user_data) do
    MyApp.User
    |> Ash.Changeset.for_create(:create, user_data)
    |> Ash.create()
  end
end
```

### Pattern: Multi-Step BAML Calls

```elixir
defmodule MyApp.AnalyzeAndSummarize do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    text = input.arguments.text

    # Step 1: Analyze sentiment
    {:ok, sentiment} = MyApp.Analyzer
      |> Ash.ActionInput.for_action(:analyze_sentiment, %{text: text})
      |> Ash.run_action()

    # Step 2: Extract entities
    {:ok, entities} = MyApp.Extractor
      |> Ash.ActionInput.for_action(:extract_entities, %{text: text})
      |> Ash.run_action()

    # Step 3: Generate summary with context
    {:ok, summary} = MyApp.Summarizer
      |> Ash.ActionInput.for_action(:summarize, %{
        text: text,
        sentiment: sentiment,
        entities: entities
      })
      |> Ash.run_action()

    {:ok, %{
      sentiment: sentiment,
      entities: entities,
      summary: summary
    }}
  end
end
```

### Pattern: Conditional BAML

Choose which BAML function to call based on input:

```elixir
defmodule MyApp.SmartExtractor do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    text = input.arguments.text

    # Detect language first
    {:ok, language} = MyApp.Detector
      |> Ash.ActionInput.for_action(:detect_language, %{text: text})
      |> Ash.run_action()

    # Choose appropriate extraction function
    action = case language do
      "en" -> :extract_english
      "es" -> :extract_spanish
      "fr" -> :extract_french
      _ -> :extract_generic
    end

    MyApp.Extractor
    |> Ash.ActionInput.for_action(action, %{text: text})
    |> Ash.run_action()
  end
end
```

## Action Arguments

### Mapping BAML Parameters

BAML function parameters become action arguments:

**BAML:**
```baml
function Translate(text: string, target_language: string) -> string {
  // ...
}
```

**Auto-generated action:**
```elixir
action :translate, :string do
  argument :text, :string, allow_nil?: false
  argument :target_language, :string, allow_nil?: false

  run call_baml(:Translate)
end
```

### Adding Extra Arguments

Include arguments not in BAML function:

```elixir
actions do
  action :translate_with_options, :string do
    # BAML arguments
    argument :text, :string, allow_nil?: false
    argument :target_language, :string, allow_nil?: false

    # Extra arguments for your logic
    argument :save_to_history, :boolean, default: false
    argument :user_id, :uuid

    run fn input, _ctx ->
      # Call BAML
      {:ok, translation} = call_baml_function(
        :Translate,
        %{
          text: input.arguments.text,
          target_language: input.arguments.target_language
        }
      )

      # Use extra arguments
      if input.arguments.save_to_history do
        save_translation_history(
          input.arguments.user_id,
          translation
        )
      end

      {:ok, translation}
    end
  end
end
```

### Argument Constraints

Use Ash's constraint system:

```elixir
actions do
  action :generate_text, :string do
    argument :prompt, :string do
      allow_nil? false
      constraints min_length: 10, max_length: 5000
    end

    argument :max_tokens, :integer do
      default 100
      constraints min: 1, max: 4096
    end

    argument :temperature, :float do
      default 0.7
      constraints min: 0.0, max: 2.0
    end

    run call_baml(:GenerateText)
  end
end
```

## Composing Actions

### Chaining BAML Actions

Call multiple actions in sequence:

```elixir
def process_document(doc_text) do
  with {:ok, extracted} <- extract_data(doc_text),
       {:ok, validated} <- validate_data(extracted),
       {:ok, enriched} <- enrich_data(validated),
       {:ok, summarized} <- summarize_data(enriched) do
    {:ok, summarized}
  end
end

defp extract_data(text) do
  MyApp.Extractor
  |> Ash.ActionInput.for_action(:extract_from_document, %{text: text})
  |> Ash.run_action()
end

defp validate_data(data) do
  MyApp.Validator
  |> Ash.ActionInput.for_action(:validate_extraction, %{data: data})
  |> Ash.run_action()
end
```

### Parallel BAML Actions

Run multiple BAML calls concurrently:

```elixir
def analyze_all(text) do
  tasks = [
    Task.async(fn -> analyze_sentiment(text) end),
    Task.async(fn -> extract_entities(text) end),
    Task.async(fn -> detect_language(text) end)
  ]

  results = Task.await_many(tasks)

  {:ok, %{
    sentiment: Enum.at(results, 0),
    entities: Enum.at(results, 1),
    language: Enum.at(results, 2)
  }}
end
```

### Mixing BAML with Database Actions

Combine LLM calls with Ash CRUD:

```elixir
defmodule MyApp.ContentPipeline do
  def process_and_save(content) do
    Ash.DataLayer.transaction(fn ->
      # 1. Create draft
      {:ok, draft} = MyApp.Post
        |> Ash.Changeset.for_create(:create, %{content: content, status: :draft})
        |> Ash.create()

      # 2. Generate tags with BAML
      {:ok, tags} = MyApp.Tagger
        |> Ash.ActionInput.for_action(:generate_tags, %{text: content})
        |> Ash.run_action()

      # 3. Update with tags
      {:ok, updated} = draft
        |> Ash.Changeset.for_update(:update, %{tags: tags})
        |> Ash.update()

      # 4. Moderate content with BAML
      {:ok, moderation} = MyApp.Moderator
        |> Ash.ActionInput.for_action(:moderate, %{content: content})
        |> Ash.run_action()

      # 5. Update status based on moderation
      final_status = if moderation.safe?, do: :published, else: :flagged

      updated
      |> Ash.Changeset.for_update(:update, %{status: final_status})
      |> Ash.update()
    end)
  end
end
```

## Testing Actions

### Mocking BAML Calls

Mock BAML functions for testing:

```elixir
# test/support/mocks.ex
Mox.defmock(MyApp.BamlClientMock, for: MyApp.BamlClientBehaviour)

# test/my_app/assistant_test.exs
defmodule MyApp.AssistantTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  test "extract_user returns structured data" do
    expect(MyApp.BamlClientMock, :extract_user, fn %{text: text} ->
      {:ok, %MyApp.BamlClient.Types.User{
        name: "Test User",
        email: "test@example.com"
      }}
    end)

    {:ok, user} = MyApp.Assistant
      |> Ash.ActionInput.for_action(:extract_user, %{text: "..."})
      |> Ash.run_action()

    assert user.name == "Test User"
  end
end
```

### Testing Custom Actions

Test custom action implementations:

```elixir
defmodule MyApp.CustomActionTest do
  use ExUnit.Case

  test "preprocess_and_extract cleans text" do
    # Mock BAML client to verify it receives cleaned text
    expect(MyApp.BamlClientMock, :extract_data, fn %{text: text} ->
      assert text == "cleaned text"  # Verify pre-processing
      {:ok, %{data: "result"}}
    end)

    MyApp.Processor
    |> Ash.ActionInput.for_action(:preprocess_and_extract, %{
      text: "  CLEANED TEXT  "  # Uppercase with whitespace
    })
    |> Ash.run_action()
  end
end
```

## Performance Considerations

### Caching Results

Cache expensive BAML calls:

```elixir
defmodule MyApp.CachedExtractor do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    text = input.arguments.text
    cache_key = :crypto.hash(:sha256, text) |> Base.encode16()

    case Cachex.get(:baml_cache, cache_key) do
      {:ok, nil} ->
        # Cache miss, call BAML
        {:ok, result} = MyApp.Extractor
          |> Ash.ActionInput.for_action(:extract, %{text: text})
          |> Ash.run_action()

        # Store in cache
        Cachex.put(:baml_cache, cache_key, result, ttl: :timer.hours(1))

        {:ok, result}

      {:ok, cached_result} ->
        # Cache hit
        {:ok, cached_result}
    end
  end
end
```

### Batching Requests

Batch multiple requests together:

```elixir
defmodule MyApp.BatchProcessor do
  def process_batch(texts) do
    # Call BAML once with concatenated text
    combined_text = Enum.join(texts, "\n---\n")

    {:ok, results} = MyApp.Extractor
      |> Ash.ActionInput.for_action(:extract_batch, %{text: combined_text})
      |> Ash.run_action()

    # Split results back
    split_results(results, length(texts))
  end
end
```

## Next Steps

- **Tutorial**: [Building an Agent](../tutorials/04-building-an-agent.md) - Advanced custom actions
- **Topic**: [Patterns](patterns.md) - Action patterns for common use cases
- **How-to**: [Call BAML Function](../how-to/call-baml-function.md) - All the ways to call BAML
- **How-to**: [Customize Actions](../how-to/customize-actions.md) - Deep customization

## Reference

- Module: `AshBaml.Actions.CallBamlFunction` - Regular action implementation
- Module: `AshBaml.Actions.CallBamlStream` - Streaming action implementation
- Module: `Ash.Resource.Actions.Implementation` - Custom action behavior
- Guide: [Ash Actions](https://ash-hq.org/docs/guides/ash/latest/topics/actions) - Complete Ash action reference
