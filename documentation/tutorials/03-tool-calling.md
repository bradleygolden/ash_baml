# Tool Calling with Union Types

Learn how to implement tool calling where the LLM selects which tool to use and extracts the parameters, then you execute the selected tool.

## Prerequisites

- Completed [Get Started](01-get-started.md) and [Structured Output](02-structured-output.md) tutorials
- Understanding of Ash union types
- Familiarity with pattern matching in Elixir

## Goals

1. Define multiple tools as BAML classes
2. Create a BAML function that returns a union type
3. Use Ash's `:union` return type for tool selection
4. Implement tool execution actions
5. Dispatch to the correct tool based on LLM selection

## The Tool Calling Pattern

Tool calling is a two-phase pattern:

1. **Selection Phase**: LLM examines user input, selects appropriate tool, extracts parameters
2. **Execution Phase**: Your code executes the selected tool with extracted parameters

This gives you full control over tool execution while letting the LLM handle selection and parameter extraction.

## Define Your Tools

Create `baml_src/tools.baml`:

```baml
class WeatherTool {
  city string @description("City name for weather lookup")
  units string @description("Temperature units: celsius or fahrenheit")
}

class CalculatorTool {
  operation string @description("Operation: add, subtract, multiply, divide")
  numbers float[] @description("Numbers to perform operation on")
}

class SearchTool {
  query string @description("Search query")
  max_results int @description("Maximum number of results")
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
    Based on the user's message, determine which tool to call and extract the parameters.

    Available tools:
    - WeatherTool: Get weather information for a city
    - CalculatorTool: Perform mathematical operations
    - SearchTool: Search for information

    User message: {{ message }}

    {{ ctx.output_format }}
  "#
}
```

The key is the union return type: `WeatherTool | CalculatorTool | SearchTool`

## Generate Ash Types

Run the type generator:

```bash
mix ash_baml.gen.types MyApp.BamlClient
```

This creates a type module for each tool:

```elixir
defmodule MyApp.BamlClient.Types.WeatherTool do
  use Ash.TypedStruct

  typed_struct do
    field :city, :string
    field :units, :string
  end
end

defmodule MyApp.BamlClient.Types.CalculatorTool do
  use Ash.TypedStruct

  typed_struct do
    field :operation, :string
    field :numbers, {:array, :float}
  end
end

defmodule MyApp.BamlClient.Types.SearchTool do
  use Ash.TypedStruct

  typed_struct do
    field :query, :string
    field :max_results, :integer
  end
end
```

## Create the Assistant Resource

Create `lib/my_app/assistant.ex`:

```elixir
defmodule MyApp.Assistant do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshBaml.Resource]

  baml do
    client :default
  end

  actions do
    # Tool selection action - returns union type
    action :select_tool, :union do
      argument :message, :string, allow_nil?: false

      constraints [
        types: [
          weather_tool: [
            type: :struct,
            constraints: [instance_of: MyApp.BamlClient.Types.WeatherTool]
          ],
          calculator_tool: [
            type: :struct,
            constraints: [instance_of: MyApp.BamlClient.Types.CalculatorTool]
          ],
          search_tool: [
            type: :struct,
            constraints: [instance_of: MyApp.BamlClient.Types.SearchTool]
          ]
        ]
      ]

      run call_baml(:SelectTool)
    end

    # Tool execution actions
    action :execute_weather, :map do
      argument :city, :string, allow_nil?: false
      argument :units, :string, allow_nil?: false

      run fn input, _context ->
        # Call weather API
        weather_data = get_weather(input.arguments.city, input.arguments.units)

        {:ok, %{
          city: input.arguments.city,
          temperature: weather_data.temp,
          condition: weather_data.condition,
          units: input.arguments.units
        }}
      end
    end

    action :execute_calculator, :float do
      argument :operation, :string, allow_nil?: false
      argument :numbers, {:array, :float}, allow_nil?: false

      run fn input, _context ->
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

      run fn input, _context ->
        # Call search API
        results = perform_search(input.arguments.query, input.arguments.max_results)

        {:ok, %{
          query: input.arguments.query,
          results: results,
          count: length(results)
        }}
      end
    end
  end

  # Placeholder functions - replace with real implementations
  defp get_weather(city, units) do
    %{temp: 72.0, condition: "sunny"}
  end

  defp perform_search(query, max_results) do
    ["Result 1", "Result 2", "Result 3"] |> Enum.take(max_results)
  end
end
```

## Use Tool Calling

Here's the complete workflow:

```elixir
# Step 1: User provides natural language input
iex> user_message = "What's the weather like in Tokyo?"

# Step 2: LLM selects tool and extracts parameters
iex> {:ok, tool_call} = MyApp.Assistant
...>   |> Ash.ActionInput.for_action(:select_tool, %{message: user_message})
...>   |> Ash.run_action()

iex> tool_call
%Ash.Union{
  type: :weather_tool,
  value: %MyApp.BamlClient.Types.WeatherTool{
    city: "Tokyo",
    units: "celsius"
  }
}

# Step 3: Dispatch to appropriate execution action
iex> case tool_call do
...>   %Ash.Union{type: :weather_tool, value: params} ->
...>     MyApp.Assistant
...>     |> Ash.ActionInput.for_action(:execute_weather, %{
...>       city: params.city,
...>       units: params.units
...>     })
...>     |> Ash.run_action()
...>
...>   %Ash.Union{type: :calculator_tool, value: params} ->
...>     MyApp.Assistant
...>     |> Ash.ActionInput.for_action(:execute_calculator, %{
...>       operation: params.operation,
...>       numbers: params.numbers
...>     })
...>     |> Ash.run_action()
...>
...>   %Ash.Union{type: :search_tool, value: params} ->
...>     MyApp.Assistant
...>     |> Ash.ActionInput.for_action(:execute_search, %{
...>       query: params.query,
...>       max_results: params.max_results
...>     })
...>     |> Ash.run_action()
...> end
{:ok, %{city: "Tokyo", temperature: 72.0, condition: "sunny", units: "celsius"}}
```

## Create a Helper Function

Wrap the dispatch logic in a helper:

```elixir
defmodule MyApp.AssistantHelper do
  def process_message(message) do
    # Step 1: Tool selection
    {:ok, tool_call} = MyApp.Assistant
      |> Ash.ActionInput.for_action(:select_tool, %{message: message})
      |> Ash.run_action()

    # Step 2: Tool execution
    case tool_call do
      %Ash.Union{type: :weather_tool, value: params} ->
        execute_tool(:execute_weather, %{
          city: params.city,
          units: params.units
        })

      %Ash.Union{type: :calculator_tool, value: params} ->
        execute_tool(:execute_calculator, %{
          operation: params.operation,
          numbers: params.numbers
        })

      %Ash.Union{type: :search_tool, value: params} ->
        execute_tool(:execute_search, %{
          query: params.query,
          max_results: params.max_results
        })
    end
  end

  defp execute_tool(action, params) do
    MyApp.Assistant
    |> Ash.ActionInput.for_action(action, params)
    |> Ash.run_action()
  end
end
```

Usage:

```elixir
iex> MyApp.AssistantHelper.process_message("Calculate 15.5 + 23 + 7.5")
{:ok, 46.0}

iex> MyApp.AssistantHelper.process_message("Search for Elixir tutorials")
{:ok, %{query: "Elixir tutorials", results: [...], count: 3}}
```

## Understanding Ash.Union

The `:union` return type creates a tagged struct:

```elixir
%Ash.Union{
  type: :weather_tool,    # Which variant was selected
  value: %WeatherTool{    # The actual struct
    city: "Tokyo",
    units: "celsius"
  }
}
```

Pattern match on `type` to determine which tool was selected:

```elixir
case tool_call do
  %Ash.Union{type: :weather_tool, value: tool} -> # Handle weather
  %Ash.Union{type: :calculator_tool, value: tool} -> # Handle calculator
  %Ash.Union{type: :search_tool, value: tool} -> # Handle search
end
```

## Adding More Tools

To add a new tool:

1. **Define the tool class** in your BAML file:
   ```baml
   class EmailTool {
     recipient string
     subject string
     body string
   }
   ```

2. **Add to union return type**:
   ```baml
   function SelectTool(message: string) -> WeatherTool | CalculatorTool | SearchTool | EmailTool {
     ...
   }
   ```

3. **Regenerate types**:
   ```bash
   mix ash_baml.gen.types MyApp.BamlClient
   ```

4. **Add to union constraints**:
   ```elixir
   email_tool: [
     type: :struct,
     constraints: [instance_of: MyApp.BamlClient.Types.EmailTool]
   ]
   ```

5. **Add execution action**:
   ```elixir
   action :execute_email, :map do
     argument :recipient, :string, allow_nil?: false
     argument :subject, :string, allow_nil?: false
     argument :body, :string, allow_nil?: false
     run fn input, _ctx -> send_email(input.arguments) end
   end
   ```

6. **Update dispatch logic** in your helper.

## Error Handling

Handle cases where tool selection or execution fails:

```elixir
def process_message(message) do
  case select_tool(message) do
    {:ok, tool_call} ->
      execute_selected_tool(tool_call)

    {:error, reason} ->
      {:error, "Tool selection failed: #{inspect(reason)}"}
  end
end

defp execute_selected_tool(%Ash.Union{type: type, value: params}) do
  case execute_tool_for_type(type, params) do
    {:ok, result} ->
      {:ok, result}

    {:error, reason} ->
      {:error, "Tool execution failed: #{inspect(reason)}"}
  end
end
```

## What You Learned

- Defining multiple tools as BAML classes
- Creating union return types in BAML
- Configuring Ash `:union` actions with type constraints
- Using `Ash.Union` struct for tool dispatch
- Implementing tool execution actions
- Pattern matching on union types
- Building helper functions for tool workflows
- Adding new tools to the system

## Next Steps

- **Tutorial 4**: [Building an Agent](04-building-an-agent.md) - Combine tool calling with agentic loops
- **How to**: [Implement Tool Calling](../how-to/implement-tool-calling.md) - Advanced patterns and best practices

See also:
- [Patterns](../topics/patterns.md) - Tool calling architecture patterns
- [Actions](../topics/actions.md) - Understanding union actions
