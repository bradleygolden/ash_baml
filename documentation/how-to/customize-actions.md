# How to Customize Actions

Step-by-step guide to customizing BAML actions beyond auto-generation.

## When to Customize

Customize actions when you need:
- Preprocessing before BAML call
- Post-processing after BAML call
- Multiple BAML calls in sequence
- Conditional logic
- State management
- Database integration

## Method 1: Inline Anonymous Function

Simplest customization for lightweight logic.

```elixir
actions do
  action :extract_formatted, MyApp.BamlClient.Types.User do
    argument :text, :string

    run fn input, _ctx ->
      # Preprocessing
      cleaned_text = input.arguments.text
        |> String.trim()
        |> String.downcase()

      # Call BAML
      {:ok, user} = __MODULE__
        |> Ash.ActionInput.for_action(:extract_user, %{text: cleaned_text})
        |> Ash.run_action()

      # Post-processing
      {:ok, normalize_user(user)}
    end
  end

  defp normalize_user(user) do
    %{user | email: String.downcase(user.email || "")}
  end
end
```

## Method 2: Custom Action Module

For complex logic, create dedicated module.

### Step 1: Create Module

```elixir
defmodule MyApp.Actions.ExtractAndValidate do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    with {:ok, extracted} <- extract(input),
         :ok <- validate(extracted),
         {:ok, enriched} <- enrich(extracted) do
      {:ok, enriched}
    end
  end

  defp extract(input) do
    MyApp.Extractor
    |> Ash.ActionInput.for_action(:extract_user, %{text: input.arguments.text})
    |> Ash.run_action()
  end

  defp validate(user) do
    cond do
      is_nil(user.email) -> {:error, "Email required"}
      String.length(user.name) < 2 -> {:error, "Name too short"}
      true -> :ok
    end
  end

  defp enrich(user) do
    # Add additional data
    {:ok, Map.put(user, :created_at, DateTime.utc_now())}
  end
end
```

### Step 2: Use Module in Action

```elixir
actions do
  action :extract_and_validate, MyApp.BamlClient.Types.User do
    argument :text, :string

    run MyApp.Actions.ExtractAndValidate
  end
end
```

## Method 3: Chaining Multiple BAML Calls

### Sequential Calls

```elixir
defmodule MyApp.Actions.ProcessDocument do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    text = input.arguments.text

    # Step 1: Extract entities
    {:ok, entities} = MyApp.Extractor
      |> Ash.ActionInput.for_action(:extract_entities, %{text: text})
      |> Ash.run_action()

    # Step 2: Classify sentiment
    {:ok, sentiment} = MyApp.Classifier
      |> Ash.ActionInput.for_action(:classify_sentiment, %{text: text})
      |> Ash.run_action()

    # Step 3: Generate summary
    {:ok, summary} = MyApp.Summarizer
      |> Ash.ActionInput.for_action(:summarize, %{
        text: text,
        entities: entities,
        sentiment: sentiment
      })
      |> Ash.run_action()

    {:ok, %{
      entities: entities,
      sentiment: sentiment,
      summary: summary
    }}
  end
end
```

### Parallel Calls

```elixir
defmodule MyApp.Actions.ParallelAnalysis do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    text = input.arguments.text

    # Run all analyses in parallel
    tasks = [
      Task.async(fn -> extract_entities(text) end),
      Task.async(fn -> classify_sentiment(text) end),
      Task.async(fn -> detect_language(text) end)
    ]

    [entities, sentiment, language] = Task.await_many(tasks)

    {:ok, %{
      entities: entities,
      sentiment: sentiment,
      language: language
    }}
  end

  defp extract_entities(text) do
    {:ok, result} = MyApp.Extractor
      |> Ash.ActionInput.for_action(:extract_entities, %{text: text})
      |> Ash.run_action()

    result
  end

  # ... other helper functions
end
```

## Method 4: Conditional Logic

Choose BAML function based on input:

```elixir
defmodule MyApp.Actions.SmartExtractor do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    text = input.arguments.text

    # Detect content type
    type = detect_type(text)

    # Choose appropriate extraction function
    action = case type do
      :email -> :extract_email
      :address -> :extract_address
      :person -> :extract_person
      _ -> :extract_generic
    end

    MyApp.Extractor
    |> Ash.ActionInput.for_action(action, %{text: text})
    |> Ash.run_action()
  end

  defp detect_type(text) do
    cond do
      String.contains?(text, "@") -> :email
      String.contains?(text, "Street") || String.contains?(text, "Ave") -> :address
      String.match?(text, ~r/\b[A-Z][a-z]+ [A-Z][a-z]+\b/) -> :person
      true -> :generic
    end
  end
end
```

## Method 5: Database Integration

Combine BAML with Ash CRUD:

```elixir
defmodule MyApp.Actions.ExtractAndSave do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    # Extract data with BAML
    {:ok, user_data} = MyApp.Extractor
      |> Ash.ActionInput.for_action(:extract_user, %{text: input.arguments.text})
      |> Ash.run_action()

    # Save to database
    MyApp.User
    |> Ash.Changeset.for_create(:create, %{
      name: user_data.name,
      email: user_data.email,
      extracted_from: input.arguments.text
    })
    |> Ash.create()
  end
end
```

## Method 6: Caching

Add caching layer:

```elixir
defmodule MyApp.Actions.CachedExtractor do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    text = input.arguments.text
    cache_key = generate_cache_key(text)

    case Cachex.get(:baml_cache, cache_key) do
      {:ok, nil} ->
        # Cache miss - call BAML
        {:ok, result} = MyApp.Extractor
          |> Ash.ActionInput.for_action(:extract, %{text: text})
          |> Ash.run_action()

        # Cache result
        Cachex.put(:baml_cache, cache_key, result, ttl: :timer.hours(1))

        {:ok, result}

      {:ok, cached_result} ->
        # Cache hit
        {:ok, cached_result}
    end
  end

  defp generate_cache_key(text) do
    :crypto.hash(:sha256, text) |> Base.encode16()
  end
end
```

## Method 7: Retry Logic

Add resilience with retries:

```elixir
defmodule MyApp.Actions.ResilientExtractor do
  use Ash.Resource.Actions.Implementation

  @max_retries 3
  @backoff_ms 1000

  @impl true
  def run(input, _opts, _context) do
    execute_with_retry(input, @max_retries)
  end

  defp execute_with_retry(input, retries_left) do
    case call_baml(input) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} when retries_left > 0 ->
        Logger.warning("BAML call failed, retrying... #{retries_left} attempts left")
        Process.sleep(@backoff_ms)
        execute_with_retry(input, retries_left - 1)

      {:error, reason} ->
        {:error, "All retries exhausted: #{inspect(reason)}"}
    end
  end

  defp call_baml(input) do
    MyApp.Extractor
    |> Ash.ActionInput.for_action(:extract, %{text: input.arguments.text})
    |> Ash.run_action()
  end
end
```

## Method 8: Custom Return Types

Transform BAML output to custom structure:

```elixir
defmodule MyApp.Actions.CustomFormatter do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    {:ok, baml_result} = MyApp.Extractor
      |> Ash.ActionInput.for_action(:extract_user, %{text: input.arguments.text})
      |> Ash.run_action()

    # Transform to custom format
    custom_result = %{
      full_name: format_name(baml_result),
      contact: %{
        email: baml_result.email,
        phone: baml_result.phone
      },
      metadata: %{
        extracted_at: DateTime.utc_now(),
        source: input.arguments.source
      }
    }

    {:ok, custom_result}
  end

  defp format_name(user) do
    "#{user.first_name} #{user.last_name}"
  end
end
```

## Testing Custom Actions

```elixir
defmodule MyApp.Actions.ExtractAndValidateTest do
  use ExUnit.Case

  import Mox
  setup :verify_on_exit!

  test "extracts and validates successfully" do
    # Mock BAML call
    expect(MyApp.BamlClientMock, :extract_user, fn %{text: _} ->
      {:ok, %MyApp.BamlClient.Types.User{
        name: "Alice",
        email: "alice@example.com"
      }}
    end)

    {:ok, result} = MyApp.Extractor
      |> Ash.ActionInput.for_action(:extract_and_validate, %{text: "Alice alice@example.com"})
      |> Ash.run_action()

    assert result.name == "Alice"
    assert result.email == "alice@example.com"
  end

  test "returns error on validation failure" do
    expect(MyApp.BamlClientMock, :extract_user, fn _ ->
      {:ok, %MyApp.BamlClient.Types.User{name: "A", email: nil}}
    end)

    assert {:error, "Email required"} = MyApp.Extractor
      |> Ash.ActionInput.for_action(:extract_and_validate, %{text: "A"})
      |> Ash.run_action()
  end
end
```

## Best Practices

1. **Keep actions focused**: One action, one responsibility
2. **Handle errors**: Always use `with` or `case` for BAML calls
3. **Log appropriately**: Log failures, not successes (unless debugging)
4. **Test thoroughly**: Mock BAML calls in tests
5. **Document intent**: Add `@moduledoc` explaining what the action does

## Next Steps

- [Topic: Actions](../topics/actions.md) - Complete action system overview
- [Topic: Patterns](../topics/patterns.md) - Common customization patterns
- [How to: Build Agentic Loop](build-agentic-loop.md) - Complex custom actions

## Related

- [How to: Call BAML Function](call-baml-function.md) - Basic function calling
- [Topic: Actions](../topics/actions.md) - Action system deep dive
