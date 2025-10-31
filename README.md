# AshBaml

[![Hex.pm](https://img.shields.io/hexpm/v/ash_baml.svg)](https://hex.pm/packages/ash_baml)
[![Hexdocs.pm](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/ash_baml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ash integration for [BAML](https://docs.boundaryml.com) (Boundary ML) functions, enabling type-safe LLM interactions with support for structured outputs, tool calling, and streaming.

## What is AshBaml?

AshBaml bridges two powerful frameworks:
- **[Ash Framework](https://hexdocs.pm/ash)**: Resource-based Elixir application framework
- **[BAML](https://docs.boundaryml.com)**: Type-safe prompt engineering with structured outputs

Together, they provide a declarative way to integrate LLMs into your Elixir applications with compile-time safety and runtime reliability.

## Quick Start

```elixir
# 1. Add to mix.exs
def deps do
  [
    {:ash_baml, "~> 0.1.0"}
  ]
end

# 2. Define a BAML function in baml_src/functions.baml
function ExtractUser(text: string) -> User {
  client GPT4
  prompt #"Extract user information from: {{ text }}"#
}

class User {
  name string
  email string
}

# 3. Generate types
$ mix ash_baml.gen.types MyApp.BamlClient

# 4. Create an Ash resource
defmodule MyApp.Extractor do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
    import_functions [:ExtractUser]
  end
end

# 5. Use it!
{:ok, user} = MyApp.Extractor
  |> Ash.ActionInput.for_action(:extract_user, %{text: "Alice alice@example.com"})
  |> Ash.run_action()
```

📚 **[Read the full Getting Started tutorial →](https://hexdocs.pm/ash_baml/01-get-started.html)**

## Installation

Add `ash_baml` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_baml, "~> 0.1.0"}
  ]
end
```

## Features

- **Auto-Generated Actions**: Automatically generate Ash actions from BAML functions via `import_functions`
- **Streaming Support**: Both regular and streaming action variants generated automatically
- **Type Safety**: Compile-time validation of BAML function signatures and generated types
- **Tool Calling Support**: Use union types to handle LLM tool selection
- **Type Generation**: Generate explicit Ash.TypedStruct modules from BAML schemas
- **Ash Integration**: Seamless integration with Ash resources and actions

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

### Auto-Generated Actions (Recommended)

The simplest way to use ash_baml is to let it auto-generate actions from your BAML functions:

```elixir
defmodule MyApp.ChatResource do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
    import_functions [:ChatAgent, :ExtractTasks]
  end

  # Actions are auto-generated:
  # - :chat_agent (regular)
  # - :chat_agent_stream (streaming)
  # - :extract_tasks (regular)
  # - :extract_tasks_stream (streaming)
end

# Usage - Regular action
{:ok, reply} = MyApp.ChatResource
  |> Ash.ActionInput.for_action(:chat_agent, %{message: "Hello"})
  |> Ash.run_action()

# Usage - Streaming action
{:ok, stream} = MyApp.ChatResource
  |> Ash.ActionInput.for_action(:chat_agent_stream, %{message: "Hello"})
  |> Ash.run_action()

stream |> Stream.each(&IO.inspect/1) |> Stream.run()
```

#### Prerequisites for Auto-Generation

Before using `import_functions`, you must:

1. **Define BAML functions** in your `baml_src/` directory
2. **Generate types** using `mix ash_baml.gen.types YourClient`
3. **Import functions** in your resource

The transformer validates at compile-time that functions exist and types are generated, providing helpful error messages if anything is missing.

### Manual Actions (Advanced)

For more control, you can still define actions manually:

```elixir
defmodule MyApp.ChatResource do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
  end

  actions do
    action :chat, MyApp.BamlClient.Types.Reply do
      argument :message, :string
      argument :context, :string

      prepare PrepareContext

      run call_baml(:ChatAgent)
    end
  end
end
```

Manual actions are useful when you need:
- Custom preparations or changes
- Authorization logic
- Composition of multiple BAML calls
- Post-processing of results

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

    # Tool execution actions
    action :execute_weather, :map do
      argument :city, :string
      argument :units, :string
      run fn input, _ctx ->
        # Execute weather API
      end
    end

    action :execute_calculator, :map do
      argument :operation, :string
      argument :numbers, {:array, :float}
      run fn input, _ctx ->
        # Execute calculator logic
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

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/ash_baml).

### Tutorials

- [Get Started](https://hexdocs.pm/ash_baml/01-get-started.html) - Your first BAML function call
- [Structured Output](https://hexdocs.pm/ash_baml/02-structured-output.html) - Working with complex types
- [Tool Calling](https://hexdocs.pm/ash_baml/03-tool-calling.html) - LLM-driven tool selection
- [Building an Agent](https://hexdocs.pm/ash_baml/04-building-an-agent.html) - Multi-step autonomous agents

### Topics

- [Why AshBaml?](https://hexdocs.pm/ash_baml/why-ash-baml.html) - Philosophy and benefits
- [Type Generation](https://hexdocs.pm/ash_baml/type-generation.html) - BAML to Ash type mapping
- [Actions](https://hexdocs.pm/ash_baml/actions.html) - Understanding action generation
- [Telemetry](https://hexdocs.pm/ash_baml/telemetry.html) - Monitoring and observability
- [Patterns](https://hexdocs.pm/ash_baml/patterns.html) - Common patterns and best practices

### How-to Guides

- [Call BAML Functions](https://hexdocs.pm/ash_baml/call-baml-function.html)
- [Implement Tool Calling](https://hexdocs.pm/ash_baml/implement-tool-calling.html)
- [Add Streaming](https://hexdocs.pm/ash_baml/add-streaming.html)
- [Configure Telemetry](https://hexdocs.pm/ash_baml/configure-telemetry.html)
- [Build Agentic Loop](https://hexdocs.pm/ash_baml/build-agentic-loop.html)
- [Customize Actions](https://hexdocs.pm/ash_baml/customize-actions.html)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

