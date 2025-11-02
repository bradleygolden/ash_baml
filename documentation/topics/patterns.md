# Patterns

Architectural patterns and best practices for building LLM-powered applications with ash_baml.

## Overview

This guide presents battle-tested patterns for common use cases, from simple structured output to complex multi-agent systems.

## Pattern: Structured Data Extraction

**Use case**: Extract structured data from unstructured text.

**When to use**:
- Form filling from user input
- Document parsing
- Data normalization
- Information extraction

**Implementation**:

```elixir
# BAML schema
class Contact {
  name string
  email string?
  phone string?
  company string?
}

function ExtractContact(text: string) -> Contact {
  client GPT4
  prompt #"Extract contact information from: {{ text }}"#
}

# Ash resource
defmodule MyApp.ContactExtractor do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:ExtractContact]
  end
end

# Usage
{:ok, contact} = MyApp.ContactExtractor
  |> Ash.ActionInput.for_action(:extract_contact, %{text: raw_text})
  |> Ash.run_action()
```

**Escape hatch**: Add validation and post-processing:

```elixir
actions do
  action :extract_and_validate, MyApp.BamlClient.Types.Contact do
    argument :text, :string

    run fn input, _ctx ->
      # Extract
      {:ok, contact} = MyApp.ContactExtractor
        |> Ash.ActionInput.for_action(:extract_contact, %{text: input.arguments.text})
        |> Ash.run_action()

      # Validate
      case validate_contact(contact) do
        :ok -> {:ok, contact}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end

defp validate_contact(%{email: email}) when not is_nil(email) do
  if String.contains?(email, "@"), do: :ok, else: {:error, "Invalid email"}
end
defp validate_contact(_), do: :ok
```

---

## Pattern: Classification and Routing

**Use case**: Classify input and route to appropriate handler.

**When to use**:
- Intent detection in chatbots
- Content moderation
- Support ticket routing
- Document categorization

**Implementation**:

```baml
enum Category {
  Question
  Complaint
  Feedback
  Bug_Report
  Feature_Request
}

class Classification {
  category Category
  confidence float
  reasoning string
}

function ClassifyMessage(message: string) -> Classification {
  client GPT4
  prompt #"Classify this customer message: {{ message }}"#
}
```

```elixir
defmodule MyApp.MessageRouter do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:ClassifyMessage]
  end

  actions do
    action :route_message, :map do
      argument :message, :string

      run fn input, _ctx ->
        # Classify
        {:ok, classification} = __MODULE__
          |> Ash.ActionInput.for_action(:classify_message, %{message: input.arguments.message})
          |> Ash.run_action()

        # Route based on category
        case classification.category do
          :question -> handle_question(input.arguments.message)
          :complaint -> escalate_to_human(input.arguments.message)
          :feedback -> save_feedback(input.arguments.message)
          :bug_report -> create_bug_ticket(input.arguments.message)
          :feature_request -> add_to_roadmap(input.arguments.message)
        end
      end
    end
  end

  defp handle_question(message), do: {:ok, %{action: "answered_automatically"}}
  defp escalate_to_human(message), do: {:ok, %{action: "escalated"}}
  defp save_feedback(message), do: {:ok, %{action: "saved"}}
  defp create_bug_ticket(message), do: {:ok, %{action: "ticket_created"}}
  defp add_to_roadmap(message), do: {:ok, %{action: "added_to_roadmap"}}
end
```

---

## Pattern: Tool Calling (LLM-Selected)

**Use case**: Let LLM choose which tool to use based on user input.

**When to use**:
- Conversational interfaces
- Multi-capability assistants
- Task automation

**Implementation**: See [Tool Calling Tutorial](../tutorials/03-tool-calling.md) for complete example.

**Key points**:
1. Define tools as BAML classes
2. Use union return type: `ToolA | ToolB | ToolC`
3. Map to Ash `:union` action type
4. Pattern match on result to execute tool

```elixir
case tool_selection do
  %Ash.Union{type: :weather_tool, value: params} ->
    execute_weather(params)

  %Ash.Union{type: :calculator_tool, value: params} ->
    execute_calculator(params)

  %Ash.Union{type: :search_tool, value: params} ->
    execute_search(params)
end
```

---

## Pattern: Agentic Loop

**Use case**: Multi-step reasoning where agent decides next actions.

**When to use**:
- Research tasks
- Complex problem-solving
- Planning and execution
- Autonomous workflows

**Implementation**: See [Building an Agent Tutorial](../tutorials/04-building-an-agent.md) for complete example.

**Key structure**:

```elixir
defp agent_loop(state, max_iterations) do
  if should_terminate?(state, max_iterations) do
    {:ok, finalize(state)}
  else
    # 1. Plan next step
    {:ok, next_step} = plan_next_action(state)

    # 2. Execute step
    {:ok, updated_state} = execute_action(next_step, state)

    # 3. Recurse
    agent_loop(updated_state, max_iterations)
  end
end
```

**Escape hatches**:
- Custom termination conditions
- State persistence
- Manual intervention points
- Fallback strategies

---

## Pattern: Multi-Agent Collaboration

**Use case**: Multiple specialized agents working together.

**When to use**:
- Complex workflows requiring specialization
- Peer review / validation workflows
- Multi-perspective analysis

**Implementation**:

```elixir
defmodule MyApp.MultiAgentOrchestrator do
  def research_and_validate(topic) do
    # Agent 1: Research
    {:ok, research} = MyApp.ResearchAgent
      |> Ash.ActionInput.for_action(:research, %{topic: topic})
      |> Ash.run_action()

    # Agent 2: Fact-check
    {:ok, fact_check} = MyApp.FactChecker
      |> Ash.ActionInput.for_action(:verify_claims, %{
        content: research.findings
      })
      |> Ash.run_action()

    # Agent 3: Synthesize (if facts check out)
    if fact_check.all_verified? do
      MyApp.Writer
      |> Ash.ActionInput.for_action(:write_article, %{
        research: research,
        verified_facts: fact_check.facts
      })
      |> Ash.run_action()
    else
      {:error, "Fact check failed: #{fact_check.failed_claims}"}
    end
  end
end
```

**Variations**:
- **Sequential**: Each agent builds on previous (pipeline)
- **Parallel**: Agents work independently, results combined
- **Iterative**: Agents critique each other until consensus

---

## Pattern: Hierarchical Agent

**Use case**: Manager agent delegates to worker agents.

**When to use**:
- Complex tasks requiring decomposition
- Resource-intensive operations need load balancing
- Different subtasks need different expertise

**Implementation**:

```elixir
defmodule MyApp.ManagerAgent do
  def process_request(request) do
    # Manager decomposes task
    {:ok, subtasks} = MyApp.PlannerAgent
      |> Ash.ActionInput.for_action(:decompose_task, %{task: request})
      |> Ash.run_action()

    # Delegate to workers in parallel
    results = subtasks.tasks
    |> Task.async_stream(&execute_subtask/1, max_concurrency: 5)
    |> Enum.to_list()

    # Manager synthesizes results
    MyApp.SynthesizerAgent
    |> Ash.ActionInput.for_action(:combine_results, %{
      results: results,
      original_request: request
    })
    |> Ash.run_action()
  end

  defp execute_subtask(subtask) do
    case subtask.type do
      "research" -> MyApp.ResearchWorker.execute(subtask)
      "calculate" -> MyApp.CalculationWorker.execute(subtask)
      "query_db" -> MyApp.DatabaseWorker.execute(subtask)
    end
  end
end
```

---

## Pattern: Streaming with Progressive Disclosure

**Use case**: Show incremental results as they arrive.

**When to use**:
- Long-running LLM calls
- User interfaces need immediate feedback
- Partial results are useful

**Implementation**:

```elixir
# Controller (Phoenix)
def stream_response(conn, %{"prompt" => prompt}) do
  {:ok, stream} = MyApp.Generator
    |> Ash.ActionInput.for_action(:generate_stream, %{prompt: prompt})
    |> Ash.run_action()

  conn
  |> put_resp_content_type("text/event-stream")
  |> send_chunked(200)
  |> stream_chunks(stream)
end

defp stream_chunks(conn, stream) do
  Enum.reduce_while(stream, conn, fn chunk, conn ->
    case Plug.Conn.chunk(conn, "data: #{Jason.encode!(chunk)}\n\n") do
      {:ok, conn} -> {:cont, conn}
      {:error, :closed} -> {:halt, conn}
    end
  end)
end
```

---

## Pattern: Caching and Memoization

**Use case**: Avoid redundant LLM calls for identical inputs.

**When to use**:
- Expensive/slow operations
- Identical requests are common
- Results don't change frequently

**Implementation**:

```elixir
defmodule MyApp.CachedExtractor do
  use Ash.Resource.Actions.Implementation

  @cache_ttl :timer.hours(24)

  @impl true
  def run(input, _opts, _context) do
    text = input.arguments.text
    cache_key = generate_cache_key(text)

    case Cachex.get(:baml_cache, cache_key) do
      {:ok, nil} ->
        # Cache miss - call BAML
        {:ok, result} = call_baml(text)
        Cachex.put(:baml_cache, cache_key, result, ttl: @cache_ttl)
        {:ok, result}

      {:ok, cached_result} ->
        # Cache hit
        {:ok, cached_result}
    end
  end

  defp generate_cache_key(text) do
    :crypto.hash(:sha256, text) |> Base.encode16()
  end

  defp call_baml(text) do
    MyApp.Extractor
    |> Ash.ActionInput.for_action(:extract, %{text: text})
    |> Ash.run_action()
  end
end
```

**Considerations**:
- Cache invalidation strategy
- Cache key generation (hash sensitive fields)
- TTL based on data freshness requirements
- Memory/storage limits

---

## Pattern: Fallback and Retry

**Use case**: Handle LLM failures gracefully.

**When to use**:
- API rate limits
- Transient errors
- Need high availability

**Implementation**:

```elixir
defmodule MyApp.ResilientExtractor do
  use Ash.Resource.Actions.Implementation

  @max_retries 3
  @retry_delay 1_000

  @impl true
  def run(input, _opts, _context) do
    execute_with_retry(input, @max_retries)
  end

  defp execute_with_retry(input, retries_left) do
    case call_primary(input) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} when retries_left > 0 ->
        Logger.warning("BAML call failed, retrying... (#{retries_left} attempts left)")
        Process.sleep(@retry_delay)
        execute_with_retry(input, retries_left - 1)

      {:error, _reason} ->
        # All retries exhausted, try fallback
        call_fallback(input)
    end
  end

  defp call_primary(input) do
    MyApp.Extractor
    |> Ash.ActionInput.for_action(:extract_with_gpt4, %{text: input.arguments.text})
    |> Ash.run_action()
  end

  defp call_fallback(input) do
    Logger.info("Using fallback model")

    MyApp.Extractor
    |> Ash.ActionInput.for_action(:extract_with_claude, %{text: input.arguments.text})
    |> Ash.run_action()
  end
end
```

---

## Pattern: Validation and Refinement

**Use case**: Iteratively improve LLM output until it meets criteria.

**When to use**:
- Output must meet strict requirements
- First attempt often needs refinement
- Quality is more important than latency

**Implementation**:

```elixir
defmodule MyApp.RefinementLoop do
  @max_iterations 3

  def generate_and_refine(prompt) do
    refinement_loop(prompt, nil, @max_iterations)
  end

  defp refinement_loop(_prompt, result, 0), do: result

  defp refinement_loop(prompt, nil, iterations_left) do
    # Initial generation
    {:ok, draft} = MyApp.Generator
      |> Ash.ActionInput.for_action(:generate, %{prompt: prompt})
      |> Ash.run_action()

    case validate(draft) do
      :ok -> {:ok, draft}
      {:error, issues} -> refinement_loop(prompt, {draft, issues}, iterations_left - 1)
    end
  end

  defp refinement_loop(prompt, {draft, issues}, iterations_left) do
    # Refinement
    {:ok, refined} = MyApp.Refiner
      |> Ash.ActionInput.for_action(:refine, %{
        original_prompt: prompt,
        draft: draft,
        issues: issues
      })
      |> Ash.run_action()

    case validate(refined) do
      :ok -> {:ok, refined}
      {:error, new_issues} -> refinement_loop(prompt, {refined, new_issues}, iterations_left - 1)
    end
  end

  defp validate(content) do
    # Custom validation logic
    cond do
      String.length(content) < 100 -> {:error, ["Too short"]}
      !String.contains?(content, "key_phrase") -> {:error, ["Missing key phrase"]}
      true -> :ok
    end
  end
end
```

---

## Pattern: Batch Processing

**Use case**: Process multiple inputs efficiently.

**When to use**:
- Many similar items to process
- Latency per item is not critical
- Want to optimize for throughput/cost

**Implementation**:

```elixir
defmodule MyApp.BatchProcessor do
  def process_batch(items, batch_size \\ 10) do
    items
    |> Enum.chunk_every(batch_size)
    |> Task.async_stream(&process_chunk/1, max_concurrency: 3)
    |> Enum.flat_map(fn {:ok, results} -> results end)
  end

  defp process_chunk(chunk) do
    # Process chunk with single BAML call
    combined_text = Enum.map_join(chunk, "\n---\n", & &1.text)

    {:ok, results} = MyApp.BatchExtractor
      |> Ash.ActionInput.for_action(:extract_batch, %{text: combined_text})
      |> Ash.run_action()

    # Map results back to original items
    Enum.zip(chunk, results.items)
    |> Enum.map(fn {original, extracted} ->
      Map.merge(original, %{extracted_data: extracted})
    end)
  end
end
```

---

## Pattern: Hybrid LLM + Rules

**Use case**: Combine LLM flexibility with deterministic rules.

**When to use**:
- Some logic is best handled by code
- Need guaranteed behavior for specific cases
- Want to reduce LLM calls

**Implementation**:

```elixir
defmodule MyApp.HybridProcessor do
  def process(input) do
    # Try rules first (fast, deterministic)
    case apply_rules(input) do
      {:ok, result} -> {:ok, %{source: :rules, result: result}}
      :no_match -> call_llm(input)
    end
  end

  defp apply_rules(input) do
    cond do
      # Exact match rules
      input.text == "help" -> {:ok, %{intent: :help, action: :show_help}}
      input.text == "cancel" -> {:ok, %{intent: :cancel, action: :cancel_operation}}

      # Pattern match rules
      String.starts_with?(input.text, "/") -> parse_command(input.text)

      # No rules matched
      true -> :no_match
    end
  end

  defp call_llm(input) do
    {:ok, result} = MyApp.Classifier
      |> Ash.ActionInput.for_action(:classify_intent, %{text: input.text})
      |> Ash.run_action()

    {:ok, %{source: :llm, result: result}}
  end
end
```

---

## Pattern: Progressive Enhancement

**Use case**: Start simple, progressively add AI capabilities.

**When to use**:
- Existing application adding AI features
- Want to test AI capabilities incrementally
- Need escape hatches to non-AI fallbacks

**Implementation**:

```elixir
defmodule MyApp.SmartSearch do
  def search(query, opts \\ []) do
    ai_enabled? = Keyword.get(opts, :ai_enabled, true)

    results = basic_search(query)

    if ai_enabled? && should_enhance?(results) do
      enhance_with_ai(query, results)
    else
      results
    end
  end

  defp basic_search(query) do
    # Traditional search (database, Elasticsearch, etc.)
    MyApp.Posts
    |> Ash.Query.filter(contains(title, ^query))
    |> Ash.read!()
  end

  defp should_enhance?(results) do
    # Only use AI if basic search yields few results
    length(results) < 3
  end

  defp enhance_with_ai(query, basic_results) do
    # Use LLM to understand intent and expand query
    {:ok, intent} = MyApp.QueryExpander
      |> Ash.ActionInput.for_action(:expand_query, %{query: query})
      |> Ash.run_action()

    # Re-search with expanded terms
    expanded_results = search_with_expansion(intent.expanded_terms)

    # Combine and re-rank with AI
    all_results = basic_results ++ expanded_results

    {:ok, ranked} = MyApp.Ranker
      |> Ash.ActionInput.for_action(:rank_results, %{
        query: query,
        results: all_results
      })
      |> Ash.run_action()

    ranked.sorted_results
  end
end
```

---

## Anti-Patterns

### ❌ God Resource

Don't put all BAML functions in one resource:

```elixir
# Don't do this
defmodule MyApp.AIResource do
  baml do
    import_functions [
      :ExtractUser, :ClassifyMessage, :GenerateText,
      :Translate, :Summarize, :Moderate, :Tag, ...
    ]
  end
end
```

**Instead**: Organize by domain:

```elixir
defmodule MyApp.Extractor do
  baml do
    import_functions [:ExtractUser, :ExtractContact]
  end
end

defmodule MyApp.Classifier do
  baml do
    import_functions [:ClassifyMessage, :DetectIntent]
  end
end
```

### ❌ Ignoring Errors

Don't assume LLM calls always succeed:

```elixir
# Don't do this
def process(input) do
  {:ok, result} = call_llm(input)  # What if this fails?
  save_to_db(result)
end
```

**Instead**: Handle errors explicitly:

```elixir
def process(input) do
  case call_llm(input) do
    {:ok, result} -> save_to_db(result)
    {:error, reason} -> handle_error(reason)
  end
end
```

### ❌ Blocking on LLM Calls

Don't block user-facing requests on slow LLM calls:

```elixir
# Don't do this (in web controller)
def create(conn, params) do
  {:ok, extracted} = extract_data(params)  # Blocks request!
  # ... rest of handler
end
```

**Instead**: Use background jobs:

```elixir
def create(conn, params) do
  job = Oban.insert!(ExtractJob.new(%{data: params}))
  render(conn, "accepted.json", job_id: job.id)
end
```

---

## Next Steps

- **Tutorials**: See patterns in action across all tutorials
- **How-to Guides**: Implementation details for specific patterns
- **Topic**: [Actions](actions.md) - Understanding the action system
- **Topic**: [Telemetry](telemetry.md) - Monitoring pattern performance

## Further Reading

- [Ash Patterns](https://ash-hq.org/docs/guides/ash/latest/topics/about-the-ash-framework/design-patterns) - General Ash patterns
- [BAML Best Practices](https://docs.boundaryml.com/docs/calling-baml/best-practices) - BAML-specific patterns
