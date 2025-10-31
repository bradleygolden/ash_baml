# Architecture: Module Delegate Pattern for Agentic Loops

## The Idiomatic Ash Pattern

The agentic loop implementation uses **module delegates** for generic actions, which is the idiomatic and recommended Ash pattern.

### Why Module Delegates?

Instead of inline anonymous functions:
```elixir
# ❌ Not recommended for complex logic
action :handle_conversation, :map do
  run fn input, context ->
    # Complex loop logic here...
  end
end
```

We use module delegates:
```elixir
# ✅ Idiomatic Ash pattern
action :handle_conversation, :map do
  run MyApp.Actions.AgentLoop
end
```

### The Delegate Module

```elixir
defmodule MyApp.Actions.AgentLoop do
  @moduledoc """
  Reusable agentic loop implementation.

  Ash automatically calls run/3 when the action executes.
  """

  use Ash.Resource.Actions.Implementation

  @impl true
  @spec run(Ash.ActionInput.t(), Keyword.t(), Ash.Resource.Context.t()) ::
        {:ok, any()} | {:error, any()}
  def run(input, opts, context) do
    # Full control over loop execution
    max_iterations = input.arguments[:max_turns] || 5
    initial_message = input.arguments[:message]
    history = input.arguments[:conversation_history] || []

    loop(input.resource, initial_message, history, max_iterations, opts, context)
  end

  # Private helper with fine-grained control
  defp loop(resource, message, history, iterations, opts, context)
end
```

## Benefits of This Pattern

### 1. **Fine-Grained Loop Control**

The module delegate gives complete control over the loop:

```elixir
defp loop(resource, message, history, iterations, opts, context) do
  # Check stop conditions
  if iterations == 0 do
    {:ok, %{stopped_reason: :max_iterations}}
  end

  # Custom error handling
  case decide_next_action(resource, message, history) do
    {:ok, decision} ->
      handle_decision(decision, ...)

    {:error, %RateLimitError{}} ->
      # Wait and retry
      Process.sleep(opts[:retry_delay] || 1000)
      loop(resource, message, history, iterations, opts, context)

    {:error, error} ->
      # Custom error recovery
      {:ok, %{stopped_reason: :error, error: error}}
  end
end
```

### 2. **State Management via Other Actions**

The module can call other actions for state updates:

```elixir
defp loop(resource, message, history, iterations, opts, context) do
  # 1. Decide next action
  {:ok, decision} = Ash.run_action(resource, :decide_next_action, %{
    message: message,
    history: history
  })

  # 2. Update state before executing tool (if resource is stateful)
  if resource.__struct__.spark_is() == :resource do
    {:ok, updated_resource} = resource
    |> Ash.Changeset.for_update(:increment_interaction_count, %{})
    |> Ash.update()

    # Continue with updated resource
    execute_with_resource(updated_resource, decision, ...)
  else
    # Continue with original resource (struct-based agents)
    execute_with_resource(resource, decision, ...)
  end
end
```

### 3. **Composability with Ash Features**

Module delegates work seamlessly with other Ash features:

```elixir
actions do
  action :handle_conversation, :map do
    argument :message, :string
    argument :max_turns, :integer, default: 10

    # Can add preparations
    prepare fn query, _context ->
      # Load conversation history from database
      query
    end

    # Can add validations
    validate fn input, _context ->
      if String.length(input.arguments.message) > 10000 do
        {:error, "Message too long"}
      else
        :ok
      end
    end

    # Module delegate for main logic
    run MyApp.Actions.AgentLoop

    # Can add changes (for stateful resources)
    change fn changeset, _context ->
      # Update last_conversation_at timestamp
      Ash.Changeset.change_attribute(changeset, :last_conversation_at, DateTime.utc_now())
    end
  end
end
```

### 4. **Testability**

The module can be tested independently:

```elixir
defmodule MyApp.Actions.AgentLoopTest do
  use ExUnit.Case

  describe "run/3" do
    test "completes after max iterations" do
      input = %Ash.ActionInput{
        resource: MyApp.TestAgent,
        arguments: %{message: "Hello", max_turns: 2}
      }

      assert {:ok, %{stopped_reason: :max_iterations}} =
        MyApp.Actions.AgentLoop.run(input, [], %{})
    end

    test "handles errors gracefully" do
      # Test error scenarios
    end
  end
end
```

## Advanced Patterns

### Pattern 1: Persistent State Management

For agents backed by a database:

```elixir
defmodule MyApp.PersistentAgent do
  use Ash.Resource,
    domain: MyApp.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshBaml.Resource]

  postgres do
    table "agents"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :conversation_history, {:array, :map}, default: []
    attribute :state, :map, default: %{}
    timestamps()
  end

  actions do
    create :create do
      accept [:conversation_history, :state]
    end

    update :update_state do
      accept [:conversation_history, :state]
    end

    action :handle_conversation, :map do
      argument :message, :string
      argument :max_turns, :integer, default: 10

      # Load current state
      prepare fn query, _context ->
        # Resource is already loaded if acting on an instance
        query
      end

      # Module delegate with state management
      run MyApp.Actions.PersistentAgentLoop

      # Persist state after completion
      change fn changeset, context ->
        result = context.private[:loop_result]

        changeset
        |> Ash.Changeset.change_attribute(:conversation_history, result.history)
        |> Ash.Changeset.change_attribute(:state, result.final_state)
      end
    end
  end
end

defmodule MyApp.Actions.PersistentAgentLoop do
  use Ash.Resource.Actions.Implementation

  def run(input, opts, context) do
    # Loop with state persistence at each step
    result = loop_with_persistence(input.resource, ...)

    # Store result in context for the change hook
    new_context = put_in(context.private[:loop_result], result)

    {:ok, result, new_context}
  end
end
```

### Pattern 2: Streaming with Module Delegate

```elixir
actions do
  action :handle_conversation_stream, :stream do
    argument :message, :string
    argument :max_turns, :integer, default: 10

    # Module delegate returns a Stream
    run MyApp.Actions.AgentLoopStream
  end
end

defmodule MyApp.Actions.AgentLoopStream do
  use Ash.Resource.Actions.Implementation

  def run(input, _opts, _context) do
    stream = Stream.resource(
      fn -> init_state(input) end,
      fn state -> iterate(state) end,
      fn state -> cleanup(state) end
    )

    {:ok, stream}
  end

  defp iterate(state) do
    # Yield results as they complete
    case execute_iteration(state) do
      {:done, result} -> {[result], :halt}
      {:continue, result, new_state} -> {[result], new_state}
    end
  end
end
```

### Pattern 3: Nested Loops (Multi-Level Agents)

```elixir
defmodule MyApp.Actions.SupervisorAgentLoop do
  use Ash.Resource.Actions.Implementation

  def run(input, opts, context) do
    # Outer loop - supervisor agent
    supervisor_loop(input.resource, input.arguments.message, [], opts, context)
  end

  defp supervisor_loop(resource, message, history, opts, context) do
    # Decide which sub-agent to delegate to
    {:ok, decision} = Ash.run_action(resource, :decide_delegation, %{
      message: message
    })

    case decision do
      %{delegate_to: :research_agent} ->
        # Inner loop - research agent
        {:ok, research_result} = Ash.run_action(
          MyApp.ResearchAgent,
          :handle_conversation,
          %{message: message, max_turns: 5}
        )

        # Continue supervisor loop with research results
        supervisor_loop(resource, format_research(research_result),
                       [research_result | history], opts, context)

      %{delegate_to: :done} ->
        {:ok, %{history: history}}
    end
  end
end
```

## Why This Pattern Works for Agentic Loops

| Requirement | How Module Delegates Solve It |
|-------------|------------------------------|
| **Iteration Control** | Full control in `loop/6` function |
| **State Management** | Can call `Ash.update` or use changes/preparations |
| **Error Handling** | Custom retry logic, exponential backoff, fallbacks |
| **Composability** | Works with preparations, changes, validations |
| **Reusability** | Same module works across multiple resources |
| **Testability** | Test module independently from resources |
| **Streaming** | Return Stream from `run/3` |
| **Nested Loops** | Call other actions from within the loop |
| **Persistence** | Hook into Ash changesets for state persistence |

## Comparison with Alternatives

### Inline Functions
```elixir
# ❌ Not suitable for complex loops
run fn input, context ->
  # Hard to test
  # Hard to reuse
  # Limited control
end
```

### Reactor
```elixir
# ✅ Good for declarative workflows
# ❌ More complex for imperative loops
# ❌ Less control over iteration logic
run MyApp.MyReactor,
  inputs: [message: arg(:message)]
```

### Module Delegate (Our Pattern)
```elixir
# ✅✅✅ Perfect for agentic loops
run MyApp.Actions.AgentLoop
```

## Best Practices

1. **Keep modules focused** - One module per loop pattern
2. **Use private helpers** - Extract `loop/6`, `iterate/5`, etc.
3. **Document the interface** - What actions must the resource implement?
4. **Handle errors gracefully** - Return `{:ok, result}` even on partial completion
5. **Make it configurable** - Accept options for retry delays, max iterations, etc.
6. **Test thoroughly** - Unit test the module, integration test with resources
7. **Log appropriately** - Use `Logger` for debugging iteration flow

## Summary

The **module delegate pattern** for generic actions is the idiomatic Ash approach and perfect for agentic loops because:

- ✅ Fine-grained control over loop execution
- ✅ Seamless integration with state management via other actions
- ✅ Composable with preparations, changes, validations
- ✅ Fully testable and reusable
- ✅ Supports advanced patterns (streaming, nested loops, persistence)

This is the pattern used throughout the agentic assistant examples and recommended for production use.
