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
- **Type Generation**: Generate explicit Ash.TypedStruct modules from BAML schemas

## Type Generation

AshBaml can generate explicit Ash type modules from your BAML schemas, providing:

- Full IDE support (autocomplete, go-to-definition, type checking)
- Visible, version-controlled type definitions
- Native Ash type integration with validation
- Clear separation between BAML schema and Elixir types

> **Note on Type Generation Approaches**: There are two ways to work with BAML types in Elixir:
>
> 1. **BAML's native generation** (via `BamlElixir.Client`): Generates structs directly under your client module (e.g., `MyApp.BamlClient.WeatherTool`). These are created automatically when you call BAML functions.
>
> 2. **AshBaml's type generation** (via `mix ash_baml.gen.types`): Generates types in a `Types` submodule (e.g., `MyApp.BamlClient.Types.WeatherTool`) with full Ash integration. This is the recommended approach for Ash resources as it provides TypedStruct definitions with validation and IDE support.
>
> This guide focuses on the second approach using the mix task.

### Generating Types

After defining your BAML schemas, generate Ash type modules:

```bash
mix ash_baml.gen.types MyApp.BamlClient
```

This creates explicit type modules in `lib/my_app/baml_client/types/`:

```elixir
# Generated from BAML
defmodule MyApp.BamlClient.Types.WeatherTool do
  use Ash.TypedStruct

  typed_struct do
    field :city, :string
    field :units, :string
  end
end
```

### Using Generated Types

Reference generated types in your Ash union actions:

```elixir
defmodule MyApp.Assistant do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
  end

  actions do
    action :select_tool, :union do
      argument :message, :string

      constraints [
        types: [
          weather_tool: [
            type: :struct,
            constraints: [instance_of: MyApp.BamlClient.Types.WeatherTool]
          ],
          calculator_tool: [
            type: :struct,
            constraints: [instance_of: MyApp.BamlClient.Types.CalculatorTool]
          ]
        ]
      ]

      run call_baml(:SelectTool)
    end
  end
end
```

> **Note**: For Ash union actions, you must use `type: :struct` with `constraints: [instance_of: YourModule]`. The direct type reference syntax is not supported for union constraints.

### Type Mapping

| BAML Type | Ash Type | Example |
|-----------|----------|---------|
| `class` | `Ash.TypedStruct` | `class Person { name string }` → `field :name, :string` |
| `enum` | `Ash.Type.Enum` | `enum Status { Active Inactive }` → `values: [:active, :inactive]` |
| `string` | `:string` | Direct mapping |
| `int` | `:integer` | Direct mapping |
| `float` | `:float` | Direct mapping |
| `bool` | `:boolean` | Direct mapping |
| `T[]` | `{:array, T}` | Arrays |
| `T?` | `allow_nil?: true` | Optional fields |

### Regenerating Types

When you modify your BAML schemas:

1. Update the `.baml` files
2. Run `mix ash_baml.gen.types YourClient`
3. Review the changes in git diff
4. Commit the updated type modules

Generated files are checked into version control to ensure visibility and IDE support.

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

