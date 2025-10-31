# How to Implement Tool Calling

Step-by-step guide to implementing tool calling where the LLM selects which tool to use.

## Quick Start

Tool calling has two phases:
1. **Selection**: LLM chooses tool and extracts parameters
2. **Execution**: Your code executes the selected tool

## Step 1: Define Tools in BAML

Create `baml_src/tools.baml`:

```baml
class WeatherTool {
  city string @description("City name")
  units string @description("celsius or fahrenheit")
}

class CalculatorTool {
  operation string @description("add, subtract, multiply, divide")
  numbers float[] @description("Numbers to operate on")
}

class SearchTool {
  query string @description("Search query")
  max_results int @description("Maximum results to return")
}

client GPT4 {
  provider openai
  options {
    model gpt-4
    api_key env.OPENAI_API_KEY
  }
}

function SelectTool(message: string) -> WeatherTool | CalculatorTool | SearchTool {
  client GPT4
  prompt #"
    Based on the user's message, select the appropriate tool and extract parameters.

    Available tools:
    - WeatherTool: Get weather for a city
    - CalculatorTool: Perform math operations
    - SearchTool: Search for information

    User message: {{ message }}

    {{ ctx.output_format }}
  "#
}
```

## Step 2: Generate Types

```bash
baml build
mix ash_baml.gen.types MyApp.BamlClient
```

This creates:
- `MyApp.BamlClient.Types.WeatherTool`
- `MyApp.BamlClient.Types.CalculatorTool`
- `MyApp.BamlClient.Types.SearchTool`

## Step 3: Create Resource with Union Action

```elixir
defmodule MyApp.Assistant do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshBaml.Resource]

  alias MyApp.BamlClient.Types

  baml do
    client_module MyApp.BamlClient
  end

  actions do
    # Tool selection action
    action :select_tool, :union do
      argument :message, :string, allow_nil?: false

      constraints [
        types: [
          weather_tool: [
            type: :struct,
            constraints: [instance_of: Types.WeatherTool]
          ],
          calculator_tool: [
            type: :struct,
            constraints: [instance_of: Types.CalculatorTool]
          ],
          search_tool: [
            type: :struct,
            constraints: [instance_of: Types.SearchTool]
          ]
        ]
      ]

      run call_baml(:SelectTool)
    end

    # Tool execution actions
    action :execute_weather, :map do
      argument :city, :string, allow_nil?: false
      argument :units, :string, allow_nil?: false

      run fn input, _ctx ->
        # Call weather API
        weather = get_weather(input.arguments.city, input.arguments.units)
        {:ok, weather}
      end
    end

    action :execute_calculator, :float do
      argument :operation, :string, allow_nil?: false
      argument :numbers, {:array, :float}, allow_nil?: false

      run fn input, _ctx ->
        result = case input.arguments.operation do
          "add" -> Enum.sum(input.arguments.numbers)
          "subtract" -> Enum.reduce(input.arguments.numbers, &(&2 - &1))
          "multiply" -> Enum.reduce(input.arguments.numbers, 1, &(&1 * &2))
          "divide" -> Enum.reduce(input.arguments.numbers, &(&2 / &1))
        end

        {:ok, result}
      end
    end

    action :execute_search, :map do
      argument :query, :string, allow_nil?: false
      argument :max_results, :integer, allow_nil?: false

      run fn input, _ctx ->
        results = perform_search(input.arguments.query, input.arguments.max_results)
        {:ok, %{results: results, count: length(results)}}
      end
    end
  end

  # Placeholder implementations
  defp get_weather(city, units) do
    %{city: city, temp: 72, condition: "sunny", units: units}
  end

  defp perform_search(query, max_results) do
    ["Result 1", "Result 2", "Result 3"] |> Enum.take(max_results)
  end
end
```

## Step 4: Implement Dispatch Logic

Create a helper module:

```elixir
defmodule MyApp.ToolDispatcher do
  alias MyApp.Assistant

  def process_message(message) do
    # Step 1: Tool selection
    {:ok, tool_call} = Assistant
      |> Ash.ActionInput.for_action(:select_tool, %{message: message})
      |> Ash.run_action()

    # Step 2: Tool execution
    execute_tool(tool_call)
  end

  defp execute_tool(%Ash.Union{type: :weather_tool, value: params}) do
    Assistant
    |> Ash.ActionInput.for_action(:execute_weather, %{
      city: params.city,
      units: params.units
    })
    |> Ash.run_action()
  end

  defp execute_tool(%Ash.Union{type: :calculator_tool, value: params}) do
    Assistant
    |> Ash.ActionInput.for_action(:execute_calculator, %{
      operation: params.operation,
      numbers: params.numbers
    })
    |> Ash.run_action()
  end

  defp execute_tool(%Ash.Union{type: :search_tool, value: params}) do
    Assistant
    |> Ash.ActionInput.for_action(:execute_search, %{
      query: params.query,
      max_results: params.max_results
    })
    |> Ash.run_action()
  end
end
```

## Step 5: Use It

```elixir
# Example: Weather query
iex> MyApp.ToolDispatcher.process_message("What's the weather in Tokyo?")
{:ok, %{city: "Tokyo", temp: 72, condition: "sunny", units: "celsius"}}

# Example: Calculator
iex> MyApp.ToolDispatcher.process_message("Calculate 15 + 23 + 7")
{:ok, 45.0}

# Example: Search
iex> MyApp.ToolDispatcher.process_message("Search for Elixir tutorials")
{:ok, %{results: ["Result 1", "Result 2", "Result 3"], count: 3}}
```

## Advanced: Adding New Tools

### 1. Define Tool in BAML

```baml
class EmailTool {
  recipient string
  subject string
  body string
}

// Update function signature
function SelectTool(message: string) -> WeatherTool | CalculatorTool | SearchTool | EmailTool {
  // ... prompt updated to include EmailTool
}
```

### 2. Regenerate Types

```bash
baml build
mix ash_baml.gen.types MyApp.BamlClient
```

### 3. Update Union Constraints

```elixir
action :select_tool, :union do
  argument :message, :string

  constraints [
    types: [
      weather_tool: [...],
      calculator_tool: [...],
      search_tool: [...],
      email_tool: [
        type: :struct,
        constraints: [instance_of: MyApp.BamlClient.Types.EmailTool]
      ]
    ]
  ]

  run call_baml(:SelectTool)
end
```

### 4. Add Execution Action

```elixir
action :execute_email, :map do
  argument :recipient, :string, allow_nil?: false
  argument :subject, :string, allow_nil?: false
  argument :body, :string, allow_nil?: false

  run fn input, _ctx ->
    send_email(
      input.arguments.recipient,
      input.arguments.subject,
      input.arguments.body
    )
  end
end
```

### 5. Update Dispatcher

```elixir
defp execute_tool(%Ash.Union{type: :email_tool, value: params}) do
  Assistant
  |> Ash.ActionInput.for_action(:execute_email, %{
    recipient: params.recipient,
    subject: params.subject,
    body: params.body
  })
  |> Ash.run_action()
end
```

## Testing Tool Calling

```elixir
defmodule MyApp.ToolDispatcherTest do
  use ExUnit.Case

  import Mox
  setup :verify_on_exit!

  test "dispatches to weather tool" do
    # Mock tool selection
    expect(MyApp.BamlClientMock, :select_tool, fn %{message: _} ->
      {:ok, %Ash.Union{
        type: :weather_tool,
        value: %MyApp.BamlClient.Types.WeatherTool{
          city: "Tokyo",
          units: "celsius"
        }
      }}
    end)

    {:ok, result} = MyApp.ToolDispatcher.process_message("Weather in Tokyo?")

    assert result.city == "Tokyo"
  end

  test "dispatches to calculator tool" do
    expect(MyApp.BamlClientMock, :select_tool, fn %{message: _} ->
      {:ok, %Ash.Union{
        type: :calculator_tool,
        value: %MyApp.BamlClient.Types.CalculatorTool{
          operation: "add",
          numbers: [15.0, 23.0, 7.0]
        }
      }}
    end)

    {:ok, result} = MyApp.ToolDispatcher.process_message("Add 15, 23, and 7")

    assert result == 45.0
  end
end
```

## Error Handling

```elixir
defmodule MyApp.ToolDispatcher do
  def process_message(message) do
    with {:ok, tool_call} <- select_tool(message),
         {:ok, result} <- execute_tool(tool_call) do
      {:ok, result}
    else
      {:error, reason} ->
        {:error, "Tool execution failed: #{inspect(reason)}"}
    end
  end

  defp select_tool(message) do
    MyApp.Assistant
    |> Ash.ActionInput.for_action(:select_tool, %{message: message})
    |> Ash.run_action()
  end

  defp execute_tool(tool_call) do
    case tool_call do
      %Ash.Union{type: type, value: params} ->
        action = tool_to_action(type)

        MyApp.Assistant
        |> Ash.ActionInput.for_action(action, Map.from_struct(params))
        |> Ash.run_action()

      _ ->
        {:error, "Unknown tool type"}
    end
  end

  defp tool_to_action(:weather_tool), do: :execute_weather
  defp tool_to_action(:calculator_tool), do: :execute_calculator
  defp tool_to_action(:search_tool), do: :execute_search
end
```

## Phoenix Controller Integration

```elixir
defmodule MyAppWeb.AssistantController do
  use MyAppWeb, :controller

  def process(conn, %{"message" => message}) do
    case MyApp.ToolDispatcher.process_message(message) do
      {:ok, result} ->
        json(conn, %{success: true, result: result})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: reason})
    end
  end
end
```

## Next Steps

- [Tutorial: Tool Calling](../tutorials/03-tool-calling.md) - Complete tutorial
- [Add Streaming](add-streaming.md) - Stream tool selection results
- [Topic: Patterns](../topics/patterns.md) - Tool calling patterns

## Related

- [Tutorial: Tool Calling](../tutorials/03-tool-calling.md) - Complete walkthrough
- [Topic: Actions](../topics/actions.md) - Understanding union actions
