# Get Started with ash_baml

In this tutorial, you'll create your first AI-powered Ash resource using BAML. By the end, you'll have a working resource that calls an LLM and returns structured output.

## Prerequisites

- Elixir and Erlang installed
- Familiarity with Ash Framework (resources, actions, domains)
- A text editor and terminal

## Goals

1. Install ash_baml and BAML
2. Define a simple BAML function
3. Create an Ash resource that calls it
4. See structured LLM output in action

## Installation

Add ash_baml to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash, "~> 3.0"},
    {:ash_baml, "~> 0.1"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Set Up BAML

Create a `baml_src/` directory in your project root for BAML files:

```bash
mkdir -p baml_src
```

This directory will contain your BAML schema definitions (classes, enums, functions, and client configurations).

## Define Your First BAML Function

Create `baml_src/functions.baml`:

```baml
class Reply {
  content string @description("The AI's response")
  confidence float @description("Confidence score 0.0-1.0")
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
  prompt #"
    Say a friendly hello to {{ name }}.
    Be enthusiastic!

    {{ ctx.output_format }}
  "#
}
```

> **Note**: See [BAML documentation](https://docs.boundaryml.com) for more on BAML syntax, clients, and prompts.

## Configure BAML Client

Add client configuration to `config/config.exs`:

```elixir
config :ash_baml,
  clients: [
    default: {MyApp.BamlClient, baml_src: "baml_src"}
  ]
```

This tells ash_baml to auto-generate a `MyApp.BamlClient` module at compile-time that reads from your `baml_src/` directory.

## Generate Ash Types

Generate Ash-compatible types from your BAML schemas:

```bash
mix ash_baml.gen.types MyApp.BamlClient
```

This creates `lib/my_app/baml_client/types/reply.ex`:

```elixir
defmodule MyApp.BamlClient.Types.Reply do
  use Ash.TypedStruct

  typed_struct do
    field :content, :string
    field :confidence, :float
  end
end
```

> **Note**: The BAML client module itself is generated automatically at compile-time based on your config. The `mix ash_baml.gen.types` task generates separate Ash type modules for use in your resources.

## Create Your First AI-Powered Resource

Create `lib/my_app/assistant.ex`:

```elixir
defmodule MyApp.Assistant do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:SayHello]
  end

  # Actions are auto-generated:
  # - :say_hello (regular)
  # - :say_hello_stream (streaming)
end
```

Add to your domain (`lib/my_app/domain.ex`):

```elixir
defmodule MyApp.Domain do
  use Ash.Domain

  resources do
    resource MyApp.Assistant
  end
end
```

## Call Your First BAML Function

Start IEx:

```bash
iex -S mix
```

Call the function:

```elixir
{:ok, reply} = MyApp.Assistant
  |> Ash.ActionInput.for_action(:say_hello, %{name: "Alice"})
  |> Ash.run_action()
```

You'll get a structured response:

```elixir
reply
# => %MyApp.BamlClient.Types.Reply{
#      content: "Hello Alice! It's wonderful to meet you! 🎉",
#      confidence: 0.95
#    }
```

## What Just Happened?

1. **AshBaml auto-generated** the `MyApp.BamlClient` module at compile-time from your `baml_src/` directory
2. **You generated** Ash types from BAML schemas using `mix ash_baml.gen.types`
3. **AshBaml.Resource extension** auto-generated two actions:
   - `:say_hello` - Regular action returning `Reply`
   - `:say_hello_stream` - Streaming action returning `Stream`
4. **Ash executed** the action, calling the BAML function
5. **Structured output** was returned as an Ash TypedStruct

## Try Streaming

For long-running LLM calls, use the streaming action:

```elixir
{:ok, stream} = MyApp.Assistant
  |> Ash.ActionInput.for_action(:say_hello_stream, %{name: "Bob"})
  |> Ash.run_action()

stream
|> Stream.each(&IO.inspect/1)
|> Stream.run()
```

## Next Steps

- **Tutorial 2**: Learn about structured output with complex types
- **Tutorial 3**: Implement tool calling with union types
- **Tutorial 4**: Build a multi-step agentic loop

See also:
- [Type Generation](../topics/type-generation.md) - Deep dive into BAML → Ash type mapping
- [Actions](../topics/actions.md) - Understanding auto-generated vs manual actions
