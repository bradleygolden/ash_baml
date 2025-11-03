# Helpdesk Example

This example demonstrates how to use AshBaml to build AI-powered helpdesk features with the Ash Framework.

## Features Demonstrated

This example shows how to use BAML functions for common helpdesk operations:

1. **Ticket Categorization** - Automatically categorize support tickets by type and priority
2. **Sentiment Analysis** - Analyze customer sentiment to identify frustrated or urgent cases
3. **Response Suggestions** - Generate professional response drafts for support agents

## Installation Workflow

This example demonstrates the recommended AshBaml installation workflow:

### 1. Install AshBaml and Generate Client

```bash
# Add ash_baml to mix.exs dependencies first
mix deps.get

# Run the installer to generate the BAML client module
# The module name defaults to AppName.BamlClient (e.g., Helpdesk.BamlClient)
mix ash_baml.install

# Or specify a custom module name:
# mix ash_baml.install --module Helpdesk.Custom.BamlClient
```

This creates:
- `lib/helpdesk/baml_client.ex` - Your BAML client module
- `baml_src/` directory with example BAML files
- `baml_src/clients.baml` - LLM client configurations
- `baml_src/example.baml` - Example BAML function

### 2. Define BAML Functions

See `baml_src/helpdesk.baml` for helpdesk-specific BAML functions:

```baml
function CategorizeTicket(subject: string, description: string) -> TicketCategory {
  client GPT5
  prompt #"
    Analyze the following support ticket and categorize it:

    Subject: {{ subject }}
    Description: {{ description }}

    {{ ctx.output_format }}
  "#
}

class TicketCategory {
  category TicketCategoryType
  priority PriorityLevel
  reasoning string
  suggested_assignee string | null
}

enum TicketCategoryType {
  Bug
  FeatureRequest
  Question
  Account
  Billing
}
```

### 3. Generate Types

After defining your BAML functions, generate Ash types:

```bash
mix ash_baml.gen.types Helpdesk.BamlClient
```

This creates type modules in `lib/helpdesk/baml_client/types/`:
- `ticket_category.ex` - TypedStruct for TicketCategory
- `ticket_category_type.ex` - Enum for categories
- `priority_level.ex` - Enum for priorities
- `sentiment_analysis.ex` - Sentiment analysis struct
- `response_suggestion.ex` - Response suggestion struct
- And more...

### 4. Use in Ash Resources

Create resources that use the BAML functions:

```elixir
defmodule Helpdesk.Support.TicketAnalyzer do
  use Ash.Resource,
    domain: Helpdesk.Support,
    extensions: [AshBaml.Resource]

  baml do
    client_module Helpdesk.BamlClient
    import_functions [:CategorizeTicket, :AnalyzeSentiment, :SuggestResponse]
  end
end
```

This auto-generates actions:
- `:categorize_ticket` - Categorize a support ticket
- `:categorize_ticket_stream` - Streaming version
- `:analyze_sentiment` - Analyze customer sentiment
- `:analyze_sentiment_stream` - Streaming version
- `:suggest_response` - Generate response suggestions
- `:suggest_response_stream` - Streaming version

## Usage Examples

### Categorize a Ticket

```elixir
{:ok, result} = Helpdesk.Support.TicketAnalyzer
  |> Ash.ActionInput.for_action(:categorize_ticket, %{
    subject: "App crashes when uploading files",
    description: "The application crashes every time I try to upload a file larger than 10MB"
  })
  |> Ash.run_action()

# result.category => :bug
# result.priority => :high
# result.reasoning => "Technical issue affecting core functionality"
```

### Analyze Sentiment

```elixir
{:ok, analysis} = Helpdesk.Support.TicketAnalyzer
  |> Ash.ActionInput.for_action(:analyze_sentiment, %{
    text: "I've been waiting 3 days for a response! This is unacceptable!"
  })
  |> Ash.run_action()

# analysis.sentiment => :frustrated
# analysis.confidence => 0.95
# analysis.requires_escalation => true
```

### Suggest Response

```elixir
{:ok, suggestion} = Helpdesk.Support.TicketAnalyzer
  |> Ash.ActionInput.for_action(:suggest_response, %{
    ticket_subject: "Billing question",
    ticket_description: "I was charged twice this month",
    customer_name: "Alice"
  })
  |> Ash.run_action()

# suggestion.response_draft => "Hi Alice, I apologize for the confusion..."
# suggestion.next_steps => ["Check payment history", "Issue refund if duplicate charge confirmed"]
# suggestion.resolution_time => :hours
```

## Configuration

Before running BAML functions, configure your LLM API keys in `baml_src/clients.baml`:

```baml
client<llm> GPT5 {
  provider openai
  options {
    model gpt-5
    api_key env.OPENAI_API_KEY
  }
}

client<llm> GPT5Mini {
  provider openai
  options {
    model gpt-5-mini
    api_key env.OPENAI_API_KEY
  }
}

client<llm> Claude {
  provider anthropic
  options {
    model claude-4-5-sonnet
    api_key env.ANTHROPIC_API_KEY
  }
}
```

Set environment variables:

```bash
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
```

## Key Takeaways

1. **Installer First** - Use `mix ash_baml.install` to set up the client module and directory structure
2. **Define BAML** - Create `.baml` files with your functions, classes, and enums
3. **Generate Types** - Run `mix ash_baml.gen.types` to create Ash-compatible type modules
4. **Import Functions** - Use `import_functions` to auto-generate actions from BAML functions
5. **Version Control** - Generated types are checked into git for IDE support and visibility

## Learn More

- [AshBaml Documentation](https://hexdocs.pm/ash_baml)
- [BAML Documentation](https://docs.boundaryml.com)
- [Ash Framework](https://hexdocs.pm/ash)

