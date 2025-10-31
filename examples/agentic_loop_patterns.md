# Agentic Loop Patterns with ash_baml

This guide demonstrates three approaches for implementing agentic loops that can be reused across different Ash resources, each with different state and context.

## Overview

An **agentic loop** follows this pattern:
1. **Decide** - LLM decides what to do next (via BAML function)
2. **Execute** - Execute the selected tool/action
3. **Continue?** - Check if we're done or should continue
4. **Loop** - Repeat with updated context

The key insight: **the loop logic can be decoupled from the resource**, allowing the same loop to work with different agents (customer support, todo assistant, research agent, etc.), each with their own state and context.

---

## Approach 1: Reactor with Map Step (Fixed Iterations)

This approach uses Reactor's **map step** to iterate a fixed number of times, allowing early termination.

### Reusable Reactor Module

```elixir
defmodule MyApp.Reactors.AgentLoop do
  @moduledoc """
  A reusable Reactor that implements an agentic loop.

  Can be attached to any resource that provides:
  - A `:decide_next_action` action returning a union with tool calls or done signal
  - Actions to execute each tool type

  Inputs:
  - message: The initial user message
  - max_iterations: Maximum number of loop iterations (default 5)
  - conversation_history: List of previous interactions (default [])
  """

  use Ash.Reactor

  input :message
  input :max_iterations, default: 5
  input :conversation_history, default: []

  # Step 1: Create iteration range
  step :create_range do
    argument :max, input(:max_iterations)

    run fn %{max: max}, _context ->
      {:ok, 1..max}
    end
  end

  # Step 2: Map over iterations (this is where the loop happens)
  map :iterate_agent do
    source result(:create_range)

    input :message, input(:message)
    input :history, input(:conversation_history)

    # For each iteration, run these steps:

    # 2a. Decide next action using the resource's action
    # NOTE: The resource is available via context
    step :decide do
      argument :message, input(:message)
      argument :history, input(:history)
      argument :iteration, element(:iterate_agent)

      run fn args, context ->
        # Get the resource from context
        resource = context.resource

        # Call the resource's decide_next_action action
        case Ash.ActionInput.for_action(resource, :decide_next_action, %{
          message: args.message,
          history: args.history
        })
        |> Ash.run_action() do
          {:ok, decision} -> {:ok, decision}
          error -> error
        end
      end
    end

    # 2b. Execute the decision
    step :execute do
      argument :decision, result(:decide)

      run fn %{decision: decision}, context ->
        resource = context.resource

        case decision do
          # If done, return the final result and signal completion
          %Ash.Union{type: :done, value: result} ->
            {:ok, {:done, result}}

          # If tool call, execute it
          %Ash.Union{type: tool_type, value: tool_params} ->
            action_name = :"execute_#{tool_type}"

            case Ash.ActionInput.for_action(resource, action_name, tool_params)
            |> Ash.run_action() do
              {:ok, result} ->
                {:ok, {:continue, result}}

              error ->
                error
            end
        end
      end
    end

    # 2c. Check if we should stop early
    step :check_done do
      argument :result, result(:execute)

      run fn %{result: result}, _context ->
        case result do
          {:done, final} ->
            # Signal to stop iterating
            {:halt, final}

          {:continue, step_result} ->
            {:ok, step_result}
        end
      end
    end

    return :check_done
  end

  # Step 3: Collect results
  step :collect_results do
    argument :iterations, result(:iterate_agent)

    run fn %{iterations: iterations}, _context ->
      # Filter out halted results and return conversation history
      results = Enum.reject(iterations, &match?({:halt, _}, &1))
      {:ok, %{history: results, completed: true}}
    end
  end

  return :collect_results
end
```

### Usage with Any Resource

```elixir
defmodule MyApp.CustomerSupportAgent do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  # Resource-specific state
  attributes do
    attribute :customer_id, :string
    attribute :support_context, :map
    attribute :agent_name, :string, default: "Support Agent"
  end

  baml do
    client_module MyApp.BamlClient
    import_functions [:DecideNextSupportAction]
  end

  actions do
    # Implement the required interface for the loop
    action :decide_next_action, :union do
      argument :message, :string
      argument :history, {:array, :map}

      constraints [
        types: [
          done: [type: :map],
          lookup_order: [type: :struct, constraints: [instance_of: MyApp.BamlClient.Types.LookupOrder]],
          create_ticket: [type: :struct, constraints: [instance_of: MyApp.BamlClient.Types.CreateTicket]],
          escalate: [type: :struct, constraints: [instance_of: MyApp.BamlClient.Types.Escalate]]
        ]
      ]

      # Enhance the message with resource-specific context
      run fn input, context ->
        # Add customer context to the message
        enhanced_message = """
        Customer: #{input.resource.customer_id}
        Agent: #{input.resource.agent_name}
        Context: #{inspect(input.resource.support_context)}

        Message: #{input.arguments.message}
        History: #{inspect(input.arguments.history)}
        """

        # Call BAML function
        case MyApp.BamlClient.DecideNextSupportAction.call(%{
          message: enhanced_message,
          history: input.arguments.history
        }) do
          {:ok, result} -> {:ok, result}
          error -> error
        end
      end
    end

    # Tool execution actions
    action :execute_lookup_order, :map do
      argument :order_id, :string

      run fn input, _context ->
        # Use resource state (customer_id) in execution
        customer_id = input.resource.customer_id
        order = lookup_order(customer_id, input.arguments.order_id)
        {:ok, order}
      end
    end

    action :execute_create_ticket, :map do
      argument :issue, :string
      argument :priority, :string

      run fn input, _context ->
        ticket = create_ticket(
          input.resource.customer_id,
          input.arguments.issue,
          input.arguments.priority
        )
        {:ok, ticket}
      end
    end

    action :execute_escalate, :map do
      argument :reason, :string

      run fn input, _context ->
        result = escalate_to_human(
          input.resource.customer_id,
          input.resource.agent_name,
          input.arguments.reason
        )
        {:ok, result}
      end
    end

    # The agentic loop action - uses the Reactor!
    action :handle_conversation, :map do
      argument :message, :string
      argument :max_turns, :integer, default: 5

      run MyApp.Reactors.AgentLoop,
        inputs: [
          message: arg(:message),
          max_iterations: arg(:max_turns),
          conversation_history: []
        ]
    end
  end
end

# Different resource, same loop!
defmodule MyApp.TodoAssistant do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  # Different state for todo agent
  attributes do
    attribute :user_id, :string
    attribute :preferences, :map
    attribute :active_projects, {:array, :string}
  end

  baml do
    client_module MyApp.BamlClient
    import_functions [:DecideNextTodoAction]
  end

  actions do
    # Same interface, different implementation
    action :decide_next_action, :union do
      argument :message, :string
      argument :history, {:array, :map}

      constraints [
        types: [
          done: [type: :map],
          extract_tasks: [type: :struct, constraints: [instance_of: MyApp.BamlClient.Types.ExtractTasks]],
          categorize: [type: :struct, constraints: [instance_of: MyApp.BamlClient.Types.Categorize]],
          schedule: [type: :struct, constraints: [instance_of: MyApp.BamlClient.Types.Schedule]]
        ]
      ]

      run fn input, _context ->
        # Different context for todo agent
        enhanced_message = """
        User: #{input.resource.user_id}
        Active Projects: #{Enum.join(input.resource.active_projects, ", ")}
        Preferences: #{inspect(input.resource.preferences)}

        Message: #{input.arguments.message}
        """

        case MyApp.BamlClient.DecideNextTodoAction.call(%{
          message: enhanced_message,
          history: input.arguments.history
        }) do
          {:ok, result} -> {:ok, result}
          error -> error
        end
      end
    end

    action :execute_extract_tasks, :map do
      argument :text, :string
      run fn input, _context -> extract_tasks(input.arguments.text) end
    end

    action :execute_categorize, :map do
      argument :tasks, {:array, :string}
      run fn input, _context -> categorize_tasks(input.arguments.tasks) end
    end

    action :execute_schedule, :map do
      argument :tasks, {:array, :map}
      run fn input, _context -> schedule_tasks(input.arguments.tasks) end
    end

    # Same Reactor, different resource!
    action :handle_conversation, :map do
      argument :message, :string
      argument :max_turns, :integer, default: 5

      run MyApp.Reactors.AgentLoop,
        inputs: [
          message: arg(:message),
          max_iterations: arg(:max_turns),
          conversation_history: []
        ]
    end
  end
end
```

### Usage

```elixir
# Create a customer support agent instance with specific state
support_agent = %MyApp.CustomerSupportAgent{
  customer_id: "CUST123",
  agent_name: "Alice",
  support_context: %{tier: "premium", region: "US"}
}

# Run the agentic loop
{:ok, result} = support_agent
|> Ash.ActionInput.for_action(:handle_conversation, %{
  message: "I need help with my order",
  max_turns: 10
})
|> Ash.run_action()

# Create a todo assistant instance with different state
todo_agent = %MyApp.TodoAssistant{
  user_id: "USER456",
  active_projects: ["Project A", "Project B"],
  preferences: %{auto_schedule: true}
}

# Same loop, different agent!
{:ok, result} = todo_agent
|> Ash.ActionInput.for_action(:handle_conversation, %{
  message: "Help me organize my tasks for this week",
  max_turns: 5
})
|> Ash.run_action()
```

---

## Approach 2: Action with Internal Loop (Simpler, More Flexible)

This approach uses a plain Ash action with internal recursion. It's simpler and more flexible for dynamic loops.

### Reusable Action Implementation Module

```elixir
defmodule MyApp.Actions.AgentLoop do
  @moduledoc """
  A reusable action implementation for agentic loops.

  Any resource using this must implement:
  - :decide_next_action - returns union with tool calls or done
  - :execute_{tool_type} - one action for each tool type
  """

  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, opts, _context) do
    max_iterations = input.arguments[:max_turns] || 5
    initial_message = input.arguments[:message]
    history = input.arguments[:conversation_history] || []

    loop(input.resource, initial_message, history, max_iterations)
  end

  defp loop(_resource, _message, history, 0) do
    {:ok, %{history: history, stopped_reason: :max_iterations}}
  end

  defp loop(resource, message, history, iterations_remaining) do
    # Step 1: Decide next action
    case Ash.ActionInput.for_action(resource, :decide_next_action, %{
      message: message,
      history: history
    })
    |> Ash.run_action() do
      {:ok, %Ash.Union{type: :done, value: final_result}} ->
        # Agent is done
        {:ok, %{
          history: [final_result | history],
          stopped_reason: :completed
        }}

      {:ok, %Ash.Union{type: tool_type, value: tool_params}} ->
        # Step 2: Execute the tool
        action_name = :"execute_#{tool_type}"

        case Ash.ActionInput.for_action(resource, action_name, tool_params)
        |> Ash.run_action() do
          {:ok, tool_result} ->
            # Step 3: Format result for next turn
            new_message = format_tool_result(tool_type, tool_result)
            new_history = [%{tool: tool_type, result: tool_result} | history]

            # Step 4: Continue loop
            loop(resource, new_message, new_history, iterations_remaining - 1)

          {:error, error} ->
            # Handle tool execution error
            {:error, error}
        end

      {:error, error} ->
        # Handle decision error
        {:error, error}
    end
  end

  defp format_tool_result(tool_type, result) do
    """
    The #{tool_type} tool returned:
    #{inspect(result)}

    What should we do next?
    """
  end
end
```

### Usage with Any Resource

```elixir
defmodule MyApp.ResearchAgent do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  attributes do
    attribute :research_topic, :string
    attribute :depth, :string, default: "detailed"
    attribute :sources, {:array, :string}
  end

  baml do
    client_module MyApp.BamlClient
    import_functions [:DecideNextResearchAction]
  end

  actions do
    action :decide_next_action, :union do
      argument :message, :string
      argument :history, {:array, :map}

      constraints [
        types: [
          done: [type: :map],
          search_web: [type: :struct, constraints: [instance_of: MyApp.BamlClient.Types.SearchWeb]],
          read_paper: [type: :struct, constraints: [instance_of: MyApp.BamlClient.Types.ReadPaper]],
          synthesize: [type: :struct, constraints: [instance_of: MyApp.BamlClient.Types.Synthesize]]
        ]
      ]

      run call_baml(:DecideNextResearchAction)
    end

    action :execute_search_web, :map do
      argument :query, :string
      run fn input, _ctx -> search_web(input.arguments.query) end
    end

    action :execute_read_paper, :map do
      argument :url, :string
      run fn input, _ctx -> read_paper(input.arguments.url) end
    end

    action :execute_synthesize, :map do
      argument :sources, {:array, :map}
      run fn input, _ctx -> synthesize(input.arguments.sources) end
    end

    # Use the reusable loop implementation
    action :conduct_research, :map do
      argument :message, :string
      argument :max_turns, :integer, default: 10
      argument :conversation_history, {:array, :map}, default: []

      run MyApp.Actions.AgentLoop
    end
  end
end
```

---

## Approach 3: Hybrid - Single Iteration Reactor + Loop Action

This combines the best of both: use Reactor for the complex single-iteration logic, wrap it in a simple loop action.

### Single Iteration Reactor (Reusable)

```elixir
defmodule MyApp.Reactors.AgentIteration do
  @moduledoc """
  Handles a single iteration of the agent loop.
  Returns either {:done, result} or {:continue, result}.
  """

  use Ash.Reactor

  input :message
  input :history

  # Step 1: Decide (with retries and error handling)
  step :decide_next_action do
    argument :message, input(:message)
    argument :history, input(:history)

    max_retries 3

    run fn args, context ->
      resource = context.resource

      Ash.ActionInput.for_action(resource, :decide_next_action, %{
        message: args.message,
        history: args.history
      })
      |> Ash.run_action()
    end

    # Compensate if something goes wrong later
    undo fn args, context, result ->
      # Log the failed decision
      log_failed_decision(result)
      :ok
    end
  end

  # Step 2: Switch based on decision type
  switch :handle_decision do
    argument :decision, result(:decide_next_action)

    # If done, return done
    matches? fn %{decision: %Ash.Union{type: :done}} -> true; _ -> false end do
      step :return_done do
        argument :decision, result(:decide_next_action)
        run fn %{decision: decision}, _ctx -> {:ok, {:done, decision.value}} end
      end

      return :return_done
    end

    # If tool call, execute it
    default do
      step :execute_tool do
        argument :decision, result(:decide_next_action)

        run fn %{decision: decision}, context ->
          resource = context.resource
          tool_type = decision.type
          tool_params = decision.value |> Map.from_struct()
          action_name = :"execute_#{tool_type}"

          case Ash.ActionInput.for_action(resource, action_name, tool_params)
          |> Ash.run_action() do
            {:ok, result} -> {:ok, {:continue, result}}
            error -> error
          end
        end
      end

      return :execute_tool
    end
  end

  return :handle_decision
end
```

### Loop Action (Simple Wrapper)

```elixir
defmodule MyApp.Actions.ReactorLoop do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    max_iterations = input.arguments[:max_turns] || 5
    initial_message = input.arguments[:message]
    history = input.arguments[:conversation_history] || []

    loop(input.resource, initial_message, history, max_iterations)
  end

  defp loop(_resource, _message, history, 0) do
    {:ok, %{history: history, stopped_reason: :max_iterations}}
  end

  defp loop(resource, message, history, iterations_remaining) do
    # Run a single iteration using the Reactor
    case Reactor.run(MyApp.Reactors.AgentIteration, %{
      message: message,
      history: history
    }, %{resource: resource}) do
      {:ok, {:done, final_result}} ->
        {:ok, %{history: [final_result | history], stopped_reason: :completed}}

      {:ok, {:continue, result}} ->
        new_message = format_for_next_turn(result)
        new_history = [result | history]
        loop(resource, new_message, new_history, iterations_remaining - 1)

      {:error, error} ->
        {:error, error}
    end
  end

  defp format_for_next_turn(result) do
    "Previous result: #{inspect(result)}\n\nWhat should we do next?"
  end
end
```

### Usage

```elixir
defmodule MyApp.AnyAgent do
  use Ash.Resource, extensions: [AshBaml.Resource]

  # ... resource state ...

  actions do
    # Implement the required interface
    action :decide_next_action, :union do
      # ...
    end

    action :execute_tool_a, :map do
      # ...
    end

    action :execute_tool_b, :map do
      # ...
    end

    # Use the hybrid approach
    action :run_agent, :map do
      argument :message, :string
      argument :max_turns, :integer, default: 5
      argument :conversation_history, {:array, :map}, default: []

      run MyApp.Actions.ReactorLoop
    end
  end
end
```

---

## Comparison of Approaches

| Approach | Pros | Cons | Best For |
|----------|------|------|----------|
| **Reactor Map** | Declarative, transactional, automatic compensation | Complex, fixed iterations | Structured workflows with known bounds |
| **Action Loop** | Simple, flexible, easy to debug | Less declarative, manual error handling | Dynamic loops, prototyping |
| **Hybrid** | Best of both, complex iteration logic + flexible loop | More code to maintain | Production systems needing robustness |

---

## Key Patterns for Reusability

### 1. **Interface Contract**

Any resource using these loops must implement:
- `:decide_next_action` - returns union with tool types or done signal
- `:execute_{tool_type}` - one action per tool type

### 2. **Context Injection**

The resource instance provides context automatically:
```elixir
run fn input, _context ->
  # Access resource state
  customer_id = input.resource.customer_id
  # ...
end
```

### 3. **History Management**

Track conversation history across iterations:
```elixir
new_history = [%{
  iteration: iteration_num,
  tool: tool_type,
  params: tool_params,
  result: tool_result,
  timestamp: DateTime.utc_now()
} | history]
```

### 4. **Graceful Termination**

Support multiple stop conditions:
- Max iterations reached
- Agent signals done
- Error threshold exceeded
- External signal (user cancellation)

---

## Next Steps

1. Choose the approach that fits your needs
2. Define your BAML functions for tool calling
3. Generate types: `mix ash_baml.gen.types YourClient`
4. Implement the required actions on your resources
5. Add the loop action using one of these patterns

Each approach is production-ready and can be customized for your specific use case!
