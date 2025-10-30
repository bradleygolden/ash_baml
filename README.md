# AshBaml

Ash integration for BAML (Boundary ML) functions, enabling type-safe LLM interactions with support for structured outputs and tool calling.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ash_baml` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_baml, "~> 0.1.0"}
  ]
end
```

## Features

- **Regular BAML Functions**: Call LLM functions that return structured data
- **Tool Calling Support**: Use union types to handle LLM tool selection
- **Type Safety**: Compile-time validation of BAML function signatures
- **Ash Integration**: Seamless integration with Ash resources and actions

## Usage Examples

### Regular BAML Functions

```elixir
defmodule MyApp.ChatResource do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
  end

  actions do
    action :chat, MyApp.BamlClient.Reply do
      argument :message, :string
      run call_baml(:ChatAgent)
    end
  end
end
```

### Tool Calling

Tool calling lets the LLM select a tool and populate its parameters. BAML parses the response
into a struct, and you decide what to do with it.

```elixir
defmodule MyApp.AssistantResource do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
  end

  actions do
    # Tool selection with union return type
    action :select_tool, :union do
      argument :message, :string

      constraints [
        types: [
          weather_tool: [
            type: :struct,
            constraints: [instance_of: MyApp.BamlClient.WeatherTool]
          ],
          calculator_tool: [
            type: :struct,
            constraints: [instance_of: MyApp.BamlClient.CalculatorTool]
          ]
        ]
      ]

      run call_baml(:SelectTool)
    end

    # Tool execution actions
    action :execute_weather, :map do
      argument :city, :string
      argument :units, :string
      run fn input, _ctx ->
        # Execute weather API
      end
    end
  end
end

# Using tool calling - LLM selects tool and populates parameters
{:ok, tool_call} = MyApp.AssistantResource
  |> Ash.ActionInput.for_action(:select_tool, %{message: "Weather in NYC?"})
  |> Ash.run_action()

# You decide what to do with the tool selection
case tool_call do
  %Ash.Union{type: :weather_tool, value: tool} ->
    # Execute weather action with extracted parameters
    MyApp.AssistantResource
    |> Ash.ActionInput.for_action(:execute_weather, %{
      city: tool.city,
      units: tool.units
    })
    |> Ash.run_action()

  %Ash.Union{type: :calculator_tool, value: tool} ->
    # Execute calculator action
    MyApp.AssistantResource
    |> Ash.ActionInput.for_action(:execute_calculator, %{
      operation: tool.operation,
      numbers: tool.numbers
    })
    |> Ash.run_action()
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ash_baml>.

