# How to Call BAML Functions

Step-by-step guide to calling BAML functions from ash_baml resources.

## Auto-Generated Actions

The simplest way to call BAML functions is through auto-generated actions.

### Step 1: Define BAML Function

Create `baml_src/functions.baml`:

```baml
class Reply {
  content string
  confidence float
}

client GPT4 {
  provider openai
  options {
    model gpt-4
    api_key env.OPENAI_API_KEY
  }
}

function SayHello(name: string) -> Reply {
  client GPT4
  prompt #"Say hello to {{ name }}"#
}
```

### Step 2: Build BAML Client

```bash
baml build
```

### Step 3: Generate Ash Types

```bash
mix ash_baml.gen.types MyApp.BamlClient
```

### Step 4: Create Ash Resource

```elixir
defmodule MyApp.Assistant do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
    import_functions [:SayHello]
  end
end
```

###Step 5: Call the Function

```elixir
{:ok, reply} = MyApp.Assistant
  |> Ash.ActionInput.for_action(:say_hello, %{name: "Alice"})
  |> Ash.run_action()

reply.content
# => "Hello Alice! How are you today?"
```

## Manual Actions

For more control, define actions manually.

### Basic Manual Action

```elixir
defmodule MyApp.Assistant do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
  end

  actions do
    # Manually define action
    action :greet, MyApp.BamlClient.Types.Reply do
      argument :name, :string, allow_nil?: false
      argument :language, :string, default: "en"

      run call_baml(:SayHello)
    end
  end
end
```

Usage:

```elixir
{:ok, reply} = MyApp.Assistant
  |> Ash.ActionInput.for_action(:greet, %{name: "Bob", language: "es"})
  |> Ash.run_action()
```

### With Preprocessing

```elixir
actions do
  action :greet_formatted, MyApp.BamlClient.Types.Reply do
    argument :name, :string

    run fn input, _ctx ->
      # Preprocess: capitalize name
      formatted_name = String.capitalize(input.arguments.name)

      # Call BAML
      __MODULE__
      |> Ash.ActionInput.for_action(:say_hello, %{name: formatted_name})
      |> Ash.run_action()
    end
  end
end
```

### With Validation

```elixir
actions do
  action :greet_validated, MyApp.BamlClient.Types.Reply do
    argument :name, :string, allow_nil?: false

    validate fn input, _ctx ->
      name = input.arguments.name

      cond do
        String.length(name) < 2 ->
          {:error, "Name too short"}

        String.length(name) > 50 ->
          {:error, "Name too long"}

        true ->
          :ok
      end
    end

    run call_baml(:SayHello)
  end
end
```

## Custom Action Implementation

For complex logic, use `Ash.Resource.Actions.Implementation`.

### Step-by-Step Implementation

**Step 1**: Create implementation module:

```elixir
defmodule MyApp.CustomGreeting do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    # Your custom logic here
    name = input.arguments.name

    # Determine time of day
    time_of_day = get_time_of_day()

    # Build context
    prompt = "Say #{time_of_day} greeting to #{name}"

    # Call BAML
    MyApp.Assistant
    |> Ash.ActionInput.for_action(:say_hello, %{name: name})
    |> Ash.run_action()
  end

  defp get_time_of_day do
    hour = Time.utc_now().hour

    cond do
      hour < 12 -> "morning"
      hour < 17 -> "afternoon"
      true -> "evening"
    end
  end
end
```

**Step 2**: Use in action:

```elixir
actions do
  action :contextual_greeting, MyApp.BamlClient.Types.Reply do
    argument :name, :string

    run MyApp.CustomGreeting
  end
end
```

## Calling from Controllers (Phoenix)

### In a Phoenix Controller

```elixir
defmodule MyAppWeb.GreetingController do
  use MyAppWeb, :controller

  def create(conn, %{"name" => name}) do
    case MyApp.Assistant
         |> Ash.ActionInput.for_action(:say_hello, %{name: name})
         |> Ash.run_action() do
      {:ok, reply} ->
        json(conn, %{greeting: reply.content})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: Exception.message(error)})
    end
  end
end
```

### With Background Jobs

For long-running operations:

```elixir
defmodule MyApp.GreetingWorker do
  use Oban.Worker, queue: :llm

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"name" => name, "user_id" => user_id}}) do
    {:ok, reply} = MyApp.Assistant
      |> Ash.ActionInput.for_action(:say_hello, %{name: name})
      |> Ash.run_action()

    # Store result
    MyApp.Greeting
    |> Ash.Changeset.for_create(:create, %{
      user_id: user_id,
      content: reply.content
    })
    |> Ash.create()
  end
end

# In controller
def create(conn, %{"name" => name}) do
  %{name: name, user_id: conn.assigns.current_user.id}
  |> MyApp.GreetingWorker.new()
  |> Oban.insert()

  json(conn, %{status: "processing"})
end
```

## Error Handling

### Basic Error Handling

```elixir
case MyApp.Assistant
     |> Ash.ActionInput.for_action(:say_hello, %{name: name})
     |> Ash.run_action() do
  {:ok, reply} ->
    IO.puts("Success: #{reply.content}")

  {:error, %Ash.Error.Invalid{} = error} ->
    IO.puts("Validation error: #{Exception.message(error)}")

  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

### With Retry Logic

```elixir
defmodule MyApp.ResilientCaller do
  @max_retries 3

  def call_with_retry(resource, action, args, retries \\ @max_retries) do
    case Ash.run_action(
           Ash.ActionInput.for_action(resource, action, args)
         ) do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} when retries > 0 ->
        Process.sleep(1000)
        call_with_retry(resource, action, args, retries - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end
end

# Usage
{:ok, reply} = MyApp.ResilientCaller.call_with_retry(
  MyApp.Assistant,
  :say_hello,
  %{name: "Alice"}
)
```

## Multiple Functions

### Chaining Functions

```elixir
def process_text(text) do
  with {:ok, analyzed} <- analyze(text),
       {:ok, summarized} <- summarize(analyzed),
       {:ok, tagged} <- tag(summarized) do
    {:ok, tagged}
  end
end

defp analyze(text) do
  MyApp.Analyzer
  |> Ash.ActionInput.for_action(:analyze, %{text: text})
  |> Ash.run_action()
end

defp summarize(analysis) do
  MyApp.Summarizer
  |> Ash.ActionInput.for_action(:summarize, %{text: analysis.content})
  |> Ash.run_action()
end

defp tag(summary) do
  MyApp.Tagger
  |> Ash.ActionInput.for_action(:tag, %{text: summary.content})
  |> Ash.run_action()
end
```

### Parallel Calls

```elixir
def analyze_comprehensive(text) do
  tasks = [
    Task.async(fn -> call_sentiment(text) end),
    Task.async(fn -> call_entities(text) end),
    Task.async(fn -> call_topics(text) end)
  ]

  [sentiment, entities, topics] = Task.await_many(tasks)

  {:ok, %{
    sentiment: sentiment,
    entities: entities,
    topics: topics
  }}
end

defp call_sentiment(text) do
  {:ok, result} = MyApp.Analyzer
    |> Ash.ActionInput.for_action(:analyze_sentiment, %{text: text})
    |> Ash.run_action()

  result
end
```

## Testing

### Mocking BAML Calls

```elixir
# test/my_app/assistant_test.exs
defmodule MyApp.AssistantTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  test "say_hello returns greeting" do
    # Mock BAML client
    expect(MyApp.BamlClientMock, :say_hello, fn %{name: "Alice"} ->
      {:ok, %MyApp.BamlClient.Types.Reply{
        content: "Hello Alice!",
        confidence: 0.95
      }}
    end)

    # Call action
    {:ok, reply} = MyApp.Assistant
      |> Ash.ActionInput.for_action(:say_hello, %{name: "Alice"})
      |> Ash.run_action()

    assert reply.content == "Hello Alice!"
    assert reply.confidence == 0.95
  end
end
```

## Next Steps

- [Implement Tool Calling](implement-tool-calling.md) - Call functions with union returns
- [Add Streaming](add-streaming.md) - Stream function results
- [Topic: Actions](../topics/actions.md) - Deep dive into actions

## Related

- [Tutorial: Get Started](../tutorials/01-get-started.md) - Your first BAML function
- [Topic: Actions](../topics/actions.md) - Action system overview
