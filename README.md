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

### Agentic Loops

For multi-turn interactions where the agent decides and executes actions iteratively, you can create reusable agentic loop patterns that work across different agent types.

```elixir
# Reusable loop implementation
defmodule MyApp.Actions.AgentLoop do
  use Ash.Resource.Actions.Implementation

  def run(input, _opts, _context) do
    loop(input.resource, input.arguments.message, [], input.arguments.max_turns)
  end

  defp loop(resource, message, history, iterations) when iterations > 0 do
    # 1. Decide next action
    {:ok, decision} = Ash.run_action(resource, :decide_next_action, %{
      message: message,
      history: history
    })

    case decision do
      %Ash.Union{type: :done, value: result} ->
        {:ok, %{history: history, result: result}}

      %Ash.Union{type: tool_type, value: params} ->
        # 2. Execute tool
        {:ok, result} = Ash.run_action(resource, :"execute_#{tool_type}", params)

        # 3. Continue loop
        loop(resource, format_result(result), [result | history], iterations - 1)
    end
  end
end

# Use with any resource
defmodule MyApp.CustomerSupportAgent do
  use Ash.Resource, extensions: [AshBaml.Resource]

  attributes do
    attribute :customer_id, :string
    attribute :support_tier, :string
  end

  actions do
    # Implement interface
    action :decide_next_action, :union do
      # ... tool type constraints ...
    end

    action :execute_lookup_order, :map do
      # Uses resource state: input.resource.customer_id
    end

    # Use reusable loop
    action :handle_conversation, :map do
      argument :message, :string
      argument :max_turns, :integer, default: 10

      run MyApp.Actions.AgentLoop
    end
  end
end
```

**Key Benefits:**
- ✅ Write loop logic once, reuse across all agents
- ✅ Each resource provides its own state and context
- ✅ Type-safe via Ash unions and BAML types
- ✅ Easy to test and extend

See the [Agentic Loop Patterns Guide](examples/agentic_loop_patterns.md) for detailed patterns using both plain Ash actions and Ash.Reactor, along with complete working examples.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ash_baml>.

