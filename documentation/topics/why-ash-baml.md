# Why ash_baml?

Understanding the philosophy, use cases, and design decisions behind ash_baml.

## Origin Story: Production AI Agents

After building and shipping AI agents to production, a clear pattern emerged: **pre-built agent frameworks sacrifice control for convenience**. When agents fail in production, you need complete visibility into state transitions, error handling, and decision-making. You need to compose complex multi-step workflows with custom termination conditions. You need to treat AI agents with the same software engineering rigor as any other production system.

**ash_baml was built to solve this**: providing the most flexible foundation for production AI agents while applying standard software engineering practices to both prompts and agent logic.

### Why BAML?

After evaluating LLM libraries, BAML stood out for three critical reasons:

1. **Native provider integration** - Supports 45+ providers and hundreds of models out of the box
2. **Higher accuracy** - Schema-Aligned Parsing (SAP) achieves 91-94% accuracy vs 57-87% for provider-native function calling
3. **Faster performance** - 2-4x faster than alternatives with 50-80% token reduction

These aren't incremental improvements—they're fundamental advantages that compound in production environments where reliability, cost, and latency matter.

### The Philosophy: Standard Software Engineering for AI

AI development should follow the same proven practices as any other software:

**Prompts are code:**
- Version controlled in schema files (`.baml`)
- Tested independently of application logic
- Refactored with clear diffs
- Reviewed in pull requests

**Agents are composable actions:**
- Built from typed primitives (`BAML functions → Ash actions`)
- Orchestrated with explicit control flow
- Tested with standard unit/integration patterns
- Debugged with full state visibility

**No magic abstractions:**
- You implement the agentic loop
- You manage state transitions
- You define termination conditions
- You handle errors and retries

This isn't about making AI development harder—it's about making it **production-ready**.

## The Problem

Building LLM-powered applications involves several challenges:

1. **Type Safety**: LLM responses are unstructured text that needs parsing and validation
2. **Prompt Management**: Prompts are scattered across code as strings, hard to version and test
3. **Integration**: Connecting LLM calls to application logic requires boilerplate
4. **Observability**: Monitoring LLM calls, costs, and performance is manual work
5. **Agent Control**: Pre-built agent loops work for demos but fail in production when you need custom orchestration

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
    client :default
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

## Comparison: ash_baml vs Elixir Alternatives

For Elixir developers choosing an LLM library, here's how ash_baml compares to other options in the ecosystem.

### Core Philosophy: Agentic Loop Control

A fundamental difference between ash_baml and alternatives is **who controls the agentic loop**:

**ash_baml**: Provides typed BAML actions as composable primitives. You implement the orchestration using `Ash.Resource.Actions.Implementation`, giving you full control over state management, termination conditions, and error handling.

**LangChain/ash_ai**: Provide pre-built agentic loops (`:while_needs_response`, `:until_success`) that automatically handle tool calling iterations. Convenient for standard patterns, but opinionated about control flow.

**req_llm**: Provides only HTTP-level primitives with no loop orchestration (though third-party frameworks like `req_llm_chain` add opinionated loops).

See [Building an Agent](../tutorials/04-building-an-agent.md) for ash_baml's approach to custom agentic loops.

---

### vs langchain (Elixir)

[LangChain](https://hex.pm/packages/langchain) (364K downloads) is an Elixir implementation of LangChain-style frameworks focused on agentic workflows and chaining LLMs with data sources.

| Aspect | langchain | ash_baml |
|--------|-----------|----------|
| Agent loops | **Pre-built** (`:while_needs_response`) | **Custom implementation** (full control) |
| Type safety | **Compile-time** (Ecto + `@type` specs) | **Compile-time** (BAML → Ash.TypedStruct) |
| Function calling | Behavior abstraction (8+ providers) | **SAP** (91-94% accuracy, any provider) |
| Prompt management | EEx templates with composition | **BAML files** (language-agnostic schema) |
| Observability | Callback system | **:telemetry** (Elixir standard) |
| Framework requirement | None (standalone) | **Ash Framework** |
| Focus | Quick agent setup | **Custom orchestration + type safety** |

**Choose langchain when:**
- Need quick agent setup with pre-built loops
- Want automatic tool calling without custom logic
- Not using Ash Framework
- Prefer opinionated "it just works" patterns
- Need multi-modal ContentParts support

**Choose ash_baml when:**
- Need full control over agentic loop orchestration
- Want higher function calling accuracy (SAP: 91-94% vs provider-native: 57-87%)
- Building with Ash Framework
- Complex termination conditions or state persistence required
- Want prompts as versioned, language-agnostic schemas

---

### vs req_llm

[req_llm](https://hex.pm/packages/req_llm) (2.5K downloads, v1.0) is a composable library focused on provider abstraction, offering unified access to 45+ providers and 665+ models.

| Aspect | req_llm | ash_baml |
|--------|---------|----------|
| Provider support | **45 providers, 665+ models** | Any provider (SAP-based) |
| Function calling | Provider-native (variable quality) | **SAP** (91-94% consistent accuracy) |
| Cost tracking | **Automatic USD calculation** | Manual (telemetry data available) |
| Streaming | **Production HTTP/2 multiplexing** | BAML streaming + Ash |
| Prompt management | Context API (composable in Elixir) | **BAML files** (schema-first) |
| Agent loops | None (HTTP primitives only) | **Custom implementation** |
| Framework requirement | None (Req plugin) | **Ash Framework** |

**Choose req_llm when:**
- Need automatic cost tracking out of the box
- Real-time chat with production-grade streaming infrastructure
- Want to support 45+ providers with minimal setup
- Prefer prompts as composable Elixir code
- Not using Ash Framework
- Rapid prototyping without build steps

**Choose ash_baml when:**
- Want higher function calling accuracy (SAP: 91-94% vs provider-native variable quality)
- Need prompts as versioned schemas separate from code
- Building with Ash + need custom agentic loops
- Want provider-agnostic function calling without dependency on native APIs
- Complex prompts that benefit from schema-first design

---

### vs ash_ai

[ash_ai](https://hex.pm/packages/ash_ai) (42K downloads) is the official Ash extension for LLM features, focusing on exposing domain resources as tools and prompt-backed actions.

| Aspect | ash_ai | ash_baml |
|--------|--------|----------|
| Ash integration | ✅ Native | ✅ Native |
| Primary use case | Resource exposure + prompt-backed actions | **Typed prompt functions + composable actions** |
| Agent loops | **Uses LangChain** (pre-built) | **Custom implementation** (full control) |
| Prompt definition | In Ash action DSL (EEx templates) | **Separate BAML files** |
| Function calling | LangChain models (variable quality) | **SAP** (91-94% consistent accuracy) |
| Vector search | ✅ PostgreSQL vectors + embeddings | ❌ (use ash_ai for this) |
| MCP server | ✅ IDE/Claude Desktop integration | ❌ |
| Chat scaffolding | ✅ `mix ash_ai.gen.chat` | ❌ |
| Action generation | Manual definitions | **Auto-generated** from BAML |
| Security | ✅ Policy enforcement built-in | Ash policies (manual integration) |
| Multi-modal | ✅ Image analysis | Depends on BAML/provider support |

**Choose ash_ai when:**
- Need vector search and RAG with PostgreSQL
- Want MCP server for IDE integration (Claude Desktop, etc.)
- Need chat scaffolding with `mix ash_ai.gen.chat`
- Exposing existing Ash resources as LLM tools
- Want pre-built agent loops (LangChain integration)
- Security-critical: need automatic policy enforcement
- Multi-modal applications (images, etc.)

**Choose ash_baml when:**
- Need custom agentic loop orchestration with full control
- Want higher function calling accuracy (SAP: 91-94% vs LangChain variable)
- Prompts are complex and change frequently (benefit from schema versioning)
- Want provider-agnostic function calling that works without native APIs
- Need to compose multiple BAML actions with custom logic
- Prefer explicit type generation over prompt strings in code

**Can you use both?** Theoretically yes, but this adds architectural complexity:
- ⚠️ Two different approaches to prompts (BAML files vs in-code)
- ⚠️ Two different agentic patterns (custom loops vs LangChain)
- ⚠️ Cognitive overhead deciding which to use for new features
- ✅ Practical combination: ash_ai for vector search/MCP, ash_baml for complex prompt orchestration

Most projects should choose one primary approach for consistency.

---

### vs Direct API Calls (OpenAI SDK, etc.)

| Aspect | Direct API | ash_baml |
|--------|-----------|----------|
| Type safety | Manual parsing | **Automatic** (BAML + Ash types) |
| Prompt management | Strings in code | **BAML files** (versioned schema) |
| Function calling | Provider-specific (variable quality) | **SAP** (91-94% consistent) |
| Observability | Manual | **Built-in telemetry** |
| Testing | Mock HTTP | **Mock BAML client** |
| Schema evolution | Manual updates | **Type regeneration** (`mix ash_baml.gen.types`) |

---

### vs BAML Alone

| Aspect | BAML Only | ash_baml |
|--------|-----------|----------|
| LLM interaction | ✅ Excellent | ✅ Excellent |
| Function calling | ✅ SAP (91-94% accuracy) | ✅ SAP (91-94% accuracy) |
| Authorization | Manual | **Ash policies** |
| API generation | Manual | **AshGraphql, AshJsonApi** |
| Action system | Manual orchestration | **Ash actions** |
| Agentic loops | Custom code | **Ash.Resource.Actions.Implementation** |
| Observability | BAML telemetry | **Ash + BAML telemetry** |

---

## Why BAML's Schema-Aligned Parsing Matters

ash_baml's most significant technical advantage is **BAML's Schema-Aligned Parsing (SAP)** - a Rust-based algorithm that achieves consistently high accuracy across all LLM providers.

### Proven Accuracy: Berkeley Function Calling Leaderboard

Independent benchmarks (n=1,000 per model) comparing SAP vs provider-native function calling:

| Model | Provider-Native | BAML SAP | Improvement |
|-------|----------------|----------|-------------|
| **GPT-4o-mini** | 19.8% | **92.4%** | +72.6% |
| **Claude-3-Haiku** | 57.3% | **91.7%** | +34.4% |
| **GPT-3.5-turbo** | 87.5% | **92.0%** | +4.5% |
| **Claude-3.5-Sonnet** | 78.1% | **94.4%** | +16.3% |
| **GPT-4o** | 87.4% | **93.0%** | +5.6% |
| **Llama-3.1-7b** | N/A (no native) | **76.8%** | Works! |

**Key Findings:**
- **Consistent 91-94% accuracy** across all frontier models
- **Dramatic improvement for weaker models** (GPT-4o-mini: 72.6% boost)
- **Works with models lacking native function calling** (Llama, Mistral, smaller models)
- **Beats native function calling even when available** (see GPT-4o, Claude)

### How SAP Works

Unlike provider-native function calling that constrains generation, SAP:

1. **Allows free generation** - Model can "think out loud" with chain-of-thought
2. **Rust-based parser** with <10ms overhead using edit-distance algorithm
3. **Schema-aware error correction** - Fixes invalid JSON, type mismatches, formatting errors
4. **Semantic validation** - Catches schema violations that valid JSON can still have
5. **Provider-agnostic** - Same algorithm works across all providers

### Performance Benefits

- **2-4x faster** than OpenAI FC-strict (~380ms median latency)
- **50-80% token reduction** - Compressed BAML schema vs verbose JSON Schema
- **Sub-10ms parsing overhead** - Negligible compared to API latency
- **Independent validation**: Instill AI found "only BAML produced valid JSON on every call"

### True Provider Independence

BAML doesn't abstract over provider-native APIs - it **bypasses them entirely**:

```baml
// Define function once
function ExtractUser(text: string) -> User {
  client MyClient  // Switch providers by changing this
  prompt #"Extract user information from: {{ text }}"#
}

// Switch from Ollama to OpenAI to Claude - just change client config
client MyClient {
  provider "openai"        // Change to "anthropic", "vertex-ai", "ollama", etc.
  options { model "gpt-4" }
}
```

**No code changes needed.** The same BAML function works across 45+ providers because SAP uses the same parsing algorithm everywhere.

### When SAP Provides Maximum Value

- **Models without native function calling** (open-source, smaller models)
- **Weaker models** where accuracy boost is dramatic (GPT-4o-mini: 72.6% improvement)
- **Multi-provider strategies** - no lock-in to provider-specific APIs
- **Cost optimization** - fewer tokens + fewer failed calls = lower bills
- **Provider flexibility** - switch providers without rewriting code

---

## ash_baml's Unique Positioning

Combining BAML's SAP with Ash's action system creates a unique approach:

**Type-Safe Primitives:**
```baml
function PlanNextStep(state: AgentState) -> AgentStep {
  client GPT4
  prompt #"Decide next action: Search, Analyze, or Complete"#
}
```

**Custom Orchestration:**
```elixir
defmodule MyApp.Agent.Loop do
  use Ash.Resource.Actions.Implementation

  def run(input, _opts, _context) do
    initial_state = %AgentState{goal: input.arguments.goal, ...}
    run_loop(initial_state, max_iterations: 5)
  end

  defp run_loop(state, opts) do
    case plan_next_step(state) do
      {:ok, step} -> execute_step(step, state)
      {:error, reason} -> handle_error(reason, state)
    end
  end
end
```

**Result**: 91-94% accurate function calling + full control over agentic loops + Ash ecosystem integration.

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
    client :default
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
