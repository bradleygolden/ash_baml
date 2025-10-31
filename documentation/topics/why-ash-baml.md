# Why ash_baml?

Understanding the philosophy, use cases, and design decisions behind ash_baml.

## The Problem

Building LLM-powered applications involves several challenges:

1. **Type Safety**: LLM responses are unstructured text that needs parsing and validation
2. **Prompt Management**: Prompts are scattered across code as strings, hard to version and test
3. **Integration**: Connecting LLM calls to application logic requires boilerplate
4. **Observability**: Monitoring LLM calls, costs, and performance is manual work
5. **Escape Hatches**: Need flexibility to customize when requirements get complex

## The Solution: Ash + BAML

**ash_baml** combines two powerful tools:

### BAML (Boundary ML)

[BAML](https://docs.boundaryml.com) treats prompts as typed functions:

```baml
function ExtractUser(text: string) -> User {
  client GPT4
  prompt #"Extract user info from: {{ text }}"#
}
```

**Benefits:**
- Type-safe LLM interactions
- Prompts as code (version control, testing, refactoring)
- Language-agnostic (define once, use in any language)
- Automatic output parsing and validation

### Ash Framework

[Ash](https://ash-hq.org) provides resource-based application architecture:

```elixir
defmodule MyApp.Assistant do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
  end
end
```

**Benefits:**
- Declarative resource definitions
- Powerful action system for business logic
- Built-in authorization, validation, lifecycle hooks
- Composable extensions (GraphQL, JSON:API, etc.)

### Together: ash_baml

**ash_baml** bridges these tools, giving you:

1. **Declarative LLM Resources**: Define AI capabilities as Ash resources
2. **Auto-Generated Actions**: BAML functions become Ash actions automatically
3. **Type Safety**: BAML types map to Ash types seamlessly
4. **Observability**: Built-in telemetry for all LLM calls
5. **Extensibility**: Full access to Ash's action system for custom logic

## Use Cases

### Simple: Structured Output

Extract structured data from unstructured text:

```elixir
{:ok, user} = MyApp.Extractor
  |> Ash.ActionInput.for_action(:extract_user, %{text: "..."})
  |> Ash.run_action()
```

**Good for:**
- Form filling from user input
- Data extraction from documents
- Sentiment analysis with structured results

### Intermediate: Tool Calling

Let LLM select and invoke tools:

```elixir
{:ok, %Ash.Union{type: :weather_tool, value: params}} = MyApp.Assistant
  |> Ash.ActionInput.for_action(:select_tool, %{message: "..."})
  |> Ash.run_action()
```

**Good for:**
- Conversational interfaces
- Task automation
- Multi-capability assistants

### Advanced: Agentic Loops

Build autonomous agents with feedback loops:

```elixir
{:ok, result} = MyApp.Agent
  |> Ash.ActionInput.for_action(:run_agent, %{goal: "...", max_iterations: 5})
  |> Ash.run_action()
```

**Good for:**
- Research assistants
- Complex problem-solving
- Multi-step workflows with decision-making

### Enterprise: Custom Orchestration

Combine multiple agents with custom control flow:

```elixir
defmodule MyApp.Orchestrator do
  def run_workflow(input) do
    # Custom logic using multiple Ash resources
    with {:ok, analysis} <- MyApp.Analyzer |> run_action(:analyze, input),
         {:ok, plan} <- MyApp.Planner |> run_action(:plan, analysis),
         {:ok, result} <- MyApp.Executor |> run_action(:execute, plan) do
      {:ok, result}
    end
  end
end
```

**Good for:**
- Production applications at scale
- Complex business requirements
- Integration with existing Ash applications

## Design Philosophy

### 1. Progressive Disclosure

Start simple, add complexity only when needed:

- Begin with auto-generated actions (`import_functions`)
- Add custom actions when requirements change
- Full escape hatch: implement `Ash.Resource.Actions.Implementation`

### 2. Ash-Native

Leverage Ash's ecosystem instead of reinventing:

- Actions, not custom abstractions
- Resources, not special LLM classes
- Extensions, not middleware

This means ash_baml applications work with:
- `AshGraphql` - Expose LLM actions via GraphQL
- `AshJsonApi` - REST API for LLM calls
- `AshAdmin` - Admin UI for LLM resources
- `AshAuthorization` - Authorize LLM access

### 3. BAML-First

Prompts belong in BAML files, not Elixir code:

**Anti-pattern:**
```elixir
# Don't do this
def get_completion(prompt) do
  HTTPoison.post("https://api.openai.com/...", %{
    prompt: "Extract user from #{prompt}"
  })
end
```

**Better:**
```baml
// Define in BAML
function ExtractUser(text: string) -> User {
  client GPT4
  prompt #"Extract user from: {{ text }}"#
}
```

```elixir
# Use in Elixir
MyApp.Extractor
|> Ash.ActionInput.for_action(:extract_user, %{text: prompt})
|> Ash.run_action()
```

### 4. Observability by Default

Every BAML call emits telemetry:

```elixir
:telemetry.attach(
  "baml-handler",
  [:ash_baml, :function_call, :stop],
  fn _event, measurements, metadata, _config ->
    Logger.info("LLM call completed", [
      function: metadata.function_name,
      duration_ms: measurements.duration,
      model: metadata.model
    ])
  end,
  nil
)
```

Track costs, latency, and errors without custom instrumentation.

## When to Use ash_baml

### ✅ Use ash_baml when:

- Building applications with Ash Framework
- Need type-safe LLM interactions
- Want observability and monitoring
- Require custom action logic around LLM calls
- Building complex multi-step agents
- Need to expose LLM capabilities via API (GraphQL, JSON:API)

### ❌ Consider alternatives when:

- **Not using Ash**: If you're not building with Ash, BAML alone may be simpler
- **Script/prototype**: For quick experiments, direct API calls may be faster
- **Streaming-first**: While ash_baml supports streaming, pure streaming UIs may need custom solutions
- **Non-Elixir**: BAML supports many languages; ash_baml is Elixir-specific

## Comparison: ash_baml vs Alternatives

### vs Direct API Calls (OpenAI SDK, etc.)

| Aspect | Direct API | ash_baml |
|--------|-----------|----------|
| Type safety | Manual parsing | Automatic |
| Prompt management | Strings in code | BAML files |
| Observability | Manual | Built-in |
| Testing | Mock HTTP | Mock BAML client |
| Versioning | Git code changes | BAML schema + Git |

### vs BAML Alone

| Aspect | BAML Only | ash_baml |
|--------|-----------|----------|
| LLM interaction | ✅ Excellent | ✅ Excellent |
| Authorization | Manual | Ash built-in |
| API generation | Manual | AshGraphql, etc. |
| Action system | Manual | Ash actions |
| Complex orchestration | Custom code | Ash resources + custom |

### vs LangChain (Python)

| Aspect | LangChain | ash_baml |
|--------|-----------|----------|
| Language | Python | Elixir |
| Type safety | Limited | Strong (BAML + Ash) |
| Prompt management | Python code | BAML files |
| Framework integration | Standalone | Deep Ash integration |
| Ecosystem | Vast (Python) | Ash ecosystem |

### vs Instructor (Python)

| Aspect | Instructor | ash_baml |
|--------|------------|----------|
| Core concept | Pydantic models | BAML classes |
| Validation | Pydantic | BAML + Ash types |
| Framework | Standalone | Ash integration |
| Streaming | ✅ | ✅ |
| Multi-step agents | Manual | Ash actions |

## Real-World Example: Content Moderation

Let's see ash_baml in action for content moderation:

**BAML Definition** (`baml_src/moderation.baml`):
```baml
enum Severity { Safe, Warning, Unsafe }

class ModerationResult {
  severity Severity
  categories string[]
  explanation string
  flagged_content string[]?
}

function ModerateContent(content: string) -> ModerationResult {
  client GPT4
  prompt #"
    Analyze this content for harmful material:
    {{ content }}

    Categorize and explain any issues.
  "#
}
```

**Ash Resource** (`lib/my_app/moderator.ex`):
```elixir
defmodule MyApp.Moderator do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
    import_functions [:ModerateContent]
  end

  actions do
    # Custom action combining moderation with database update
    action :moderate_and_update, :map do
      argument :post_id, :uuid, allow_nil?: false
      argument :content, :string, allow_nil?: false

      run fn input, _ctx ->
        # Step 1: Moderate with BAML
        {:ok, result} = __MODULE__
          |> Ash.ActionInput.for_action(:moderate_content, %{
            content: input.arguments.content
          })
          |> Ash.run_action()

        # Step 2: Update post in database
        case result.severity do
          :unsafe ->
            MyApp.Post
            |> Ash.Changeset.for_update(:flag, %{
              status: :flagged,
              flag_reason: result.explanation
            })
            |> Ash.update()

          _ ->
            {:ok, result}
        end
      end
    end
  end
end
```

**Usage:**
```elixir
# Moderate and automatically update database
{:ok, result} = MyApp.Moderator
  |> Ash.ActionInput.for_action(:moderate_and_update, %{
    post_id: post.id,
    content: post.content
  })
  |> Ash.run_action()
```

**What this gives you:**
1. Type-safe moderation results
2. Versioned prompt in BAML file
3. Custom action combining LLM + database
4. Automatic telemetry for LLM calls
5. Easy to test (mock BAML client)
6. Can expose via GraphQL/JSON:API

## Next Steps

- **Tutorial**: [Get Started](../tutorials/01-get-started.md) - Build your first ash_baml resource
- **Topic**: [Patterns](patterns.md) - Architectural patterns for different use cases
- **Topic**: [Actions](actions.md) - Deep dive into the action system
- **How-to**: [Call BAML Function](../how-to/call-baml-function.md) - Learn all the ways to call BAML functions

## Further Reading

- [BAML Documentation](https://docs.boundaryml.com) - Learn BAML in depth
- [Ash Framework Guide](https://ash-hq.org) - Master Ash resources and actions
- [Why BAML?](https://docs.boundaryml.com/docs/why-baml) - BAML's philosophy
