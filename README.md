# AshBaml

[![Hex.pm](https://img.shields.io/hexpm/v/ash_baml.svg)](https://hex.pm/packages/ash_baml)
[![Hexdocs.pm](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/ash_baml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ash integration for [BAML](https://docs.boundaryml.com) (Boundary ML) functions, enabling type-safe LLM interactions with support for structured outputs, tool calling, and streaming.

## What is AshBaml?

**Production-ready AI agents with full control.**

After shipping AI agents to production, a pattern became clear: pre-built agent frameworks sacrifice control for convenience. When agents fail, you need complete visibility into state, errors, and decisions. You need to apply standard software engineering practices to AI development—version control, testing, debugging, code review.

AshBaml provides the most flexible foundation for production AI agents by combining:
- **[Ash Framework](https://hexdocs.pm/ash)**: Composable actions and resources for custom orchestration
- **[BAML](https://docs.boundaryml.com)**: Schema-first prompts with 91-94% accuracy (vs 57-87% for provider-native)

**Why BAML?**
- **45+ providers** and hundreds of models with native integration
- **91-94% accuracy** via Schema-Aligned Parsing (proven on Berkeley benchmarks)
- **2-4x faster** with 50-80% token reduction vs alternatives

You implement the agentic loop. You control state, termination, and error handling. No magic—just typed primitives and explicit orchestration.

## Quick Start

```elixir
# 1. Add to mix.exs
def deps do
  [
    {:ash_baml, github: "bradleygolden/ash_baml"}
  ]
end

# 2. Configure your BAML client in config/config.exs
config :ash_baml,
  clients: [
    default: {MyApp.BamlClient, baml_src: "baml_src"}
  ]

# 3. Define a BAML function in baml_src/functions.baml
function ExtractUser(text: string) -> User {
  client GPT5
  prompt #"Extract user information from: {{ text }}"#
}

class User {
  name string
  email string
}

# 4. Generate types
$ mix ash_baml.gen.types MyApp.BamlClient

# 5. Create an Ash resource
defmodule MyApp.Extractor do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:ExtractUser]
  end
end

# 6. Use it!
{:ok, user} = MyApp.Extractor
  |> Ash.ActionInput.for_action(:extract_user, %{text: "Alice alice@example.com"})
  |> Ash.run_action()
```

📚 **[Read the full Getting Started tutorial →](documentation/tutorials/01-get-started.md)**

## Installation

> **Note**: AshBaml is not yet published to Hex. Use the GitHub repository as a dependency.

Add `ash_baml` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_baml, github: "bradleygolden/ash_baml"}
  ]
end
```

Then configure your BAML client in `config/config.exs`:

```elixir
config :ash_baml,
  clients: [
    default: {MyApp.BamlClient, baml_src: "baml_src"}
  ]
```

This config-driven approach:
- Auto-generates the client module at compile time
- Keeps all client configuration in one place
- Allows multiple resources to share clients
- Supports environment-specific overrides

You can also use the installer for quick setup:

```bash
# Recommended: config-driven client
mix ash_baml.install --client default

# Alternative: manual client module
mix ash_baml.install --module MyApp.BamlClient
```

## Features

- **Auto-Generated Actions**: Automatically generate Ash actions from BAML functions via `import_functions`
- **Streaming Support**: Both regular and streaming action variants generated automatically
- **Automatic Stream Cancellation**: Streams automatically cancel LLM generation when consumers exit or when the stream is explicitly closed
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
    client :default
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
    client :default
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
    client :default
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
    client :default
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

## Why ash_baml?

### Schema-Aligned Parsing: 91-94% Accuracy

ash_baml leverages **BAML's Schema-Aligned Parsing (SAP)** - a Rust-based algorithm achieving consistently high accuracy across all LLM providers.

**Berkeley Function Calling Leaderboard Results (n=1,000):**

| Model | Provider-Native | BAML SAP | Improvement |
|-------|----------------|----------|-------------|
| GPT-4o-mini | 19.8% | **92.4%** | +72.6% |
| Claude-3-Haiku | 57.3% | **91.7%** | +34.4% |
| GPT-4o | 87.4% | **93.0%** | +5.6% |
| Claude-3.5-Sonnet | 78.1% | **94.4%** | +16.3% |
| Llama-3.1-7b | N/A | **76.8%** | Works! |

**SAP beats provider-native function calling even when native APIs are available.**

### Custom Agentic Loop Control

Unlike libraries with pre-built agent loops, ash_baml provides **typed BAML actions as composable primitives**. You implement orchestration using `Ash.Resource.Actions.Implementation`, giving full control over:

- State management
- Termination conditions
- Error handling and recovery
- Multi-agent coordination

See [Building an Agent](documentation/tutorials/04-building-an-agent.md) for details.

### True Provider Independence

BAML doesn't abstract over provider-native APIs - it **bypasses them entirely** with SAP. Switch providers by changing configuration only:

```baml
// Works with OpenAI, Anthropic, Gemini, Ollama, 45+ providers
function ExtractUser(text: string) -> User {
  client MyClient  // Just change this reference
  prompt #"Extract user information from: {{ text }}"#
}
```

No code changes needed. The same SAP algorithm works everywhere.

## Comparison with Elixir Alternatives

### vs langchain

| Aspect | langchain | ash_baml |
|--------|-----------|----------|
| Agent loops | Pre-built (`:while_needs_response`) | **Custom implementation** (full control) |
| Function calling | Behavior abstraction (8+ providers) | **SAP** (91-94% accuracy, any provider) |
| Framework | Standalone | **Ash Framework** |

**Choose langchain** for quick agent setup with pre-built loops.
**Choose ash_baml** for custom orchestration with higher accuracy.

### vs req_llm

| Aspect | req_llm | ash_baml |
|--------|---------|----------|
| Provider support | 45 providers, 665+ models | Any provider (SAP-based) |
| Function calling | Provider-native (variable) | **SAP** (91-94% consistent) |
| Cost tracking | **Automatic USD** | Manual (telemetry available) |
| Framework | None (Req plugin) | **Ash Framework** |

**Choose req_llm** for automatic cost tracking and production streaming.
**Choose ash_baml** for higher accuracy and schema-first prompts.

### vs ash_ai

| Aspect | ash_ai | ash_baml |
|--------|--------|----------|
| Agent loops | Uses LangChain (pre-built) | **Custom implementation** (full control) |
| Function calling | LangChain models (variable) | **SAP** (91-94% consistent) |
| Vector search | ✅ PostgreSQL | ❌ |
| MCP server | ✅ IDE integration | ❌ |

**Choose ash_ai** for vector search, RAG, and MCP server integration.
**Choose ash_baml** for custom agentic loops and higher function calling accuracy.

See [full comparison](documentation/topics/why-ash-baml.md#comparison-ash_baml-vs-elixir-alternatives) for detailed analysis.

## Deployment

Deploying applications that use ash_baml is straightforward since `baml_elixir` comes with precompiled NIFs for common platforms (Linux, macOS, Windows). See the **[Deployment Guide](DEPLOYMENT.md)** for detailed instructions including:

- Complete Dockerfile example for containerized deployment
- Build optimization strategies
- Platform-specific considerations
- Production checklist and security considerations

**Quick summary**: Standard Elixir deployment practices apply. The precompiled NIFs are included in your release automatically.

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/ash_baml).

### Tutorials

- [Get Started](documentation/tutorials/01-get-started.md) - Your first BAML function call
- [Structured Output](documentation/tutorials/02-structured-output.md) - Working with complex types
- [Tool Calling](documentation/tutorials/03-tool-calling.md) - LLM-driven tool selection
- [Building an Agent](documentation/tutorials/04-building-an-agent.md) - Multi-step autonomous agents

### Topics

- [Why AshBaml?](documentation/topics/why-ash-baml.md) - Philosophy and benefits
- [Type Generation](documentation/topics/type-generation.md) - BAML to Ash type mapping
- [Actions](documentation/topics/actions.md) - Understanding action generation
- [Telemetry](documentation/topics/telemetry.md) - Monitoring and observability
- [Patterns](documentation/topics/patterns.md) - Common patterns and best practices

### How-to Guides

- [Call BAML Functions](documentation/how-to/call-baml-function.md)
- [Implement Tool Calling](documentation/how-to/implement-tool-calling.md)
- [Add Streaming](documentation/how-to/add-streaming.md)
- [Configure Telemetry](documentation/how-to/configure-telemetry.md)
- [Build Agentic Loop](documentation/how-to/build-agentic-loop.md)
- [Customize Actions](documentation/how-to/customize-actions.md)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
