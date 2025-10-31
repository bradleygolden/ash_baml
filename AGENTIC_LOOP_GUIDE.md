# Agentic Loop Guide: Ash + BAML

This guide demonstrates how to build agentic loops in Elixir using Ash Framework and BAML, comparable to Python's tool-calling patterns.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Key Components](#key-components)
3. [Patterns for Agentic Loops](#patterns-for-agentic-loops)
4. [Examples](#examples)
5. [Comparison with Python](#comparison-with-python)
6. [Advanced Patterns](#advanced-patterns)

## Architecture Overview

An agentic loop in Ash consists of three main components:

1. **Tool Handler Resource** - Ash resource with actions for tool selection and execution
2. **Ash Reactor** - Orchestrates the flow from selection to execution
3. **Loop Controller** - CLI, GenServer, or recursive action that manages iterations

```
┌─────────────────────────────────────────────────────────────┐
│                      User Input                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Ash Reactor (AgenticLoopReactor)                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Step 1: Select Tool (via BAML)                      │   │
│  │  ↓                                                    │   │
│  │  Step 2: Execute Tool (Weather/Calculator/etc)       │   │
│  │  ↓                                                    │   │
│  │  Step 3: Format Result                               │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    Result/Response                           │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Tool Handler Resource

`AshBaml.AgenticToolHandler` provides:

```elixir
# Select which tool to use
action :select_tool, :union do
  argument :message, :string
  run call_baml(:SelectTool)
end

# Execute weather tool
action :execute_weather, :map do
  argument :city, :string
  argument :units, :string
  # ... implementation
end

# Execute calculator tool
action :execute_calculator, :map do
  argument :operation, :string
  argument :numbers, {:array, :float}
  # ... implementation
end

# Unified executor (dispatches based on tool type)
action :execute_tool, :map do
  argument :tool_selection, :union
  # ... routes to appropriate execution action
end
```

### 2. Ash Reactor

`AshBaml.AgenticLoopReactor` orchestrates the flow:

```elixir
use Ash.Reactor

input :message

# Step 1: Call BAML to select tool
action :select_tool, AshBaml.AgenticToolHandler, :select_tool do
  inputs(%{message: input(:message)})
end

# Step 2: Execute selected tool
action :execute_tool, AshBaml.AgenticToolHandler, :execute_tool do
  inputs(%{tool_selection: result(:select_tool)})
end

# Step 3: Format and return result
step :format_result do
  argument :tool_selection, result(:select_tool)
  argument :execution_result, result(:execute_tool)
  run fn inputs, _ctx -> {:ok, format(inputs)} end
end

return :format_result
```

### 3. Loop Controllers

#### CLI (Simple Loop)

```elixir
defmodule AshBaml.Examples.AgenticLoopCLI do
  def run do
    IO.puts("Agent started! Type 'exit' to quit.")
    loop()
  end

  defp loop do
    user_input = IO.gets("You: ") |> String.trim()

    case user_input do
      "exit" -> :ok
      message ->
        {:ok, result} = AshBaml.AgenticLoopReactor.run(%{message: message})
        IO.puts("Agent: #{result.response}")
        loop()
    end
  end
end
```

#### GenServer (Stateful Loop)

```elixir
defmodule AshBaml.Examples.AgenticLoopServer do
  use GenServer

  def send_message(pid, message) do
    GenServer.call(pid, {:send_message, message})
  end

  def handle_call({:send_message, message}, _from, state) do
    {:ok, result} = AshBaml.AgenticLoopReactor.run(%{message: message})

    new_state = update_history(state, message, result)
    {:reply, {:ok, result}, new_state}
  end
end
```

## Patterns for Agentic Loops

### Pattern 1: Simple Single-Shot (No Loop)

Use the reactor once per request:

```elixir
{:ok, result} = AshBaml.AgenticLoopReactor.run(%{message: "What's the weather?"})
```

**Use when:** One-off tool selection and execution

### Pattern 2: CLI Loop (User-Driven)

User provides input in a loop until exit:

```elixir
AshBaml.Examples.AgenticLoopCLI.run()
```

**Use when:** Interactive CLI applications, testing, demos

### Pattern 3: GenServer Loop (State-Preserving)

Maintain conversation history and context:

```elixir
{:ok, pid} = AshBaml.Examples.AgenticLoopServer.start_link()
AshBaml.Examples.AgenticLoopServer.send_message(pid, "Calculate 5 + 3")
history = AshBaml.Examples.AgenticLoopServer.get_history(pid)
```

**Use when:** Multi-turn conversations, stateful agents, production systems

### Pattern 4: Recursive Action Loop (Agent-Driven)

Agent decides when to stop based on task completion:

```elixir
defmodule MyResource do
  use Ash.Resource

  actions do
    action :agentic_task, :map do
      argument :task, :string
      argument :max_iterations, :integer, default: 10

      run fn input, ctx ->
        recursive_execute(input.arguments.task, input.arguments.max_iterations)
      end
    end
  end

  defp recursive_execute(task, remaining_iterations) when remaining_iterations > 0 do
    {:ok, result} = AshBaml.AgenticLoopReactor.run(%{message: task})

    # Agent decides if task is complete
    if task_complete?(result) do
      {:ok, result}
    else
      # Generate next action based on result
      next_task = generate_next_action(result)
      recursive_execute(next_task, remaining_iterations - 1)
    end
  end

  defp recursive_execute(_task, 0), do: {:error, "Max iterations reached"}
end
```

**Use when:** Complex multi-step tasks, autonomous agents, workflow automation

### Pattern 5: Nested Reactors (Composed Workflows)

Combine multiple reactors for complex flows:

```elixir
defmodule ComplexAgenticReactor do
  use Ash.Reactor

  input :initial_task

  # First iteration
  reactor :first_step, AshBaml.AgenticLoopReactor do
    inputs(%{message: input(:initial_task)})
  end

  # Conditional second iteration
  step :decide_next_step do
    argument :first_result, result(:first_step)

    run fn %{first_result: result}, _ctx ->
      if needs_followup?(result) do
        {:ok, generate_followup(result)}
      else
        {:ok, :done}
      end
    end
  end

  reactor :second_step, AshBaml.AgenticLoopReactor do
    inputs(%{message: result(:decide_next_step)})

    wait_for([
      result(:decide_next_step)
    ])
  end

  return :second_step
end
```

**Use when:** Multi-stage workflows, conditional branching, complex orchestration

## Examples

### Example 1: Simple Weather Query

```elixir
{:ok, result} = AshBaml.AgenticLoopReactor.run(%{
  message: "What's the weather in Tokyo?"
})

IO.inspect(result)
# %{
#   response: "The weather in Tokyo is sunny with a temperature of 22°C.",
#   tool_used: :weather_tool,
#   tool_data: %AshBaml.Test.BamlClient.WeatherTool{city: "Tokyo", units: "celsius"},
#   execution_result: %{...}
# }
```

### Example 2: Calculator Query

```elixir
{:ok, result} = AshBaml.AgenticLoopReactor.run(%{
  message: "Calculate 15 * 3"
})

IO.inspect(result)
# %{
#   response: "The result of multiply [15.0, 3.0] is 45.0",
#   tool_used: :calculator_tool,
#   tool_data: %AshBaml.Test.BamlClient.CalculatorTool{operation: "multiply", numbers: [15.0, 3.0]},
#   execution_result: %{result: 45.0, ...}
# }
```

### Example 3: CLI Loop

```elixir
AshBaml.Examples.AgenticLoopCLI.run()

# Output:
# Agent started! Type 'exit' to quit.
#
# You: What's the weather in Paris?
# Agent (Weather): The weather in Paris is cloudy with a temperature of 18°C.
#
# You: Multiply 7 by 8
# Agent (Calculator): The result of multiply [7.0, 8.0] is 56.0
#
# You: exit
# Goodbye!
```

### Example 4: GenServer with History

```elixir
{:ok, pid} = AshBaml.Examples.AgenticLoopServer.start_link()

AshBaml.Examples.AgenticLoopServer.send_message(pid, "What's the weather in London?")
# {:ok, %{response: "...", turn: 1, ...}}

AshBaml.Examples.AgenticLoopServer.send_message(pid, "Add 5 and 10")
# {:ok, %{response: "...", turn: 2, ...}}

history = AshBaml.Examples.AgenticLoopServer.get_history(pid)
# [
#   %{turn: 1, message: "What's the weather in London?", tool_used: :weather_tool, ...},
#   %{turn: 2, message: "Add 5 and 10", tool_used: :calculator_tool, ...}
# ]
```

## Comparison with Python

### Python Pattern

```python
def main():
    while True:
        user_input = input("You: ")
        if user_input.lower() == 'exit':
            break

        # Call BAML function
        tool_response = b.SelectTool(user_input)

        # Handle response
        if isinstance(tool_response, WeatherAPI):
            result = handle_weather(tool_response)
        elif isinstance(tool_response, CalculatorAPI):
            result = handle_calculator(tool_response)

        print(f"Agent: {result}")
```

### Elixir/Ash Pattern

```elixir
defmodule AgenticLoopCLI do
  def run do
    loop()
  end

  defp loop do
    user_input = IO.gets("You: ") |> String.trim()

    case user_input do
      "exit" -> :ok
      message ->
        # Call reactor (which uses BAML internally)
        {:ok, result} = AgenticLoopReactor.run(%{message: message})
        IO.puts("Agent: #{result.response}")
        loop()
    end
  end
end
```

### Key Differences

| Aspect | Python | Elixir/Ash |
|--------|--------|------------|
| **Tool Selection** | Direct BAML call | Ash action with `call_baml()` |
| **Type Handling** | `isinstance()` checks | Ash Union type with pattern matching |
| **Tool Execution** | Function calls | Ash actions |
| **Orchestration** | Manual if/elif | Ash Reactor with steps |
| **State Management** | Global variables | GenServer or process dictionary |
| **Concurrency** | Threading/async | OTP processes |

## Advanced Patterns

### Pattern: Multi-Agent Collaboration

```elixir
defmodule MultiAgentReactor do
  use Ash.Reactor

  input :task

  # Agent 1: Planner
  reactor :planner, PlannerReactor do
    inputs(%{task: input(:task)})
  end

  # Agent 2: Executor (uses agentic loop)
  reactor :executor, AgenticLoopReactor do
    inputs(%{message: result(:planner).plan})
  end

  # Agent 3: Validator
  reactor :validator, ValidatorReactor do
    inputs(%{
      plan: result(:planner),
      execution: result(:executor)
    })
  end

  return :validator
end
```

### Pattern: Tool Chaining with Context

```elixir
defmodule ContextualAgenticReactor do
  use Ash.Reactor

  input :message
  input :context, default: %{}

  step :enrich_message do
    argument :message, input(:message)
    argument :context, input(:context)

    run fn %{message: msg, context: ctx}, _ctx ->
      enriched = "#{msg} (Context: #{inspect(ctx)})"
      {:ok, enriched}
    end
  end

  reactor :execute_with_context, AgenticLoopReactor do
    inputs(%{message: result(:enrich_message)})
  end

  return :execute_with_context
end
```

### Pattern: Retry with Fallback

```elixir
defmodule ResilientAgenticReactor do
  use Ash.Reactor

  input :message

  reactor :primary_attempt, AgenticLoopReactor do
    inputs(%{message: input(:message)})
    max_retries(3)
  end

  step :check_and_fallback do
    argument :result, result(:primary_attempt)

    run fn
      %{result: {:ok, result}}, _ctx ->
        {:ok, result}

      %{result: {:error, _}}, _ctx ->
        # Fallback to simpler tool or default response
        {:ok, %{response: "I apologize, I couldn't process that request.", tool_used: :fallback}}
    end
  end

  return :check_and_fallback
end
```

## Testing Agentic Loops

### Unit Test: Reactor

```elixir
defmodule AgenticLoopReactorTest do
  use ExUnit.Case

  test "processes weather query correctly" do
    {:ok, result} = AshBaml.AgenticLoopReactor.run(%{
      message: "What's the weather in Paris?"
    })

    assert result.tool_used == :weather_tool
    assert result.tool_data.city == "Paris"
    assert result.response =~ "weather"
  end

  test "processes calculator query correctly" do
    {:ok, result} = AshBaml.AgenticLoopReactor.run(%{
      message: "Calculate 5 + 3"
    })

    assert result.tool_used == :calculator_tool
    assert result.execution_result.result == 8.0
  end
end
```

### Integration Test: GenServer

```elixir
defmodule AgenticLoopServerTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = AshBaml.Examples.AgenticLoopServer.start_link()
    %{pid: pid}
  end

  test "maintains conversation history", %{pid: pid} do
    {:ok, _result1} = AgenticLoopServer.send_message(pid, "Weather in Tokyo?")
    {:ok, _result2} = AgenticLoopServer.send_message(pid, "Add 5 and 10")

    history = AgenticLoopServer.get_history(pid)

    assert length(history) == 2
    assert Enum.at(history, 0).tool_used == :weather_tool
    assert Enum.at(history, 1).tool_used == :calculator_tool
  end

  test "resets conversation", %{pid: pid} do
    AgenticLoopServer.send_message(pid, "Test message")
    AgenticLoopServer.reset(pid)

    history = AgenticLoopServer.get_history(pid)
    assert history == []
  end
end
```

## Best Practices

1. **Use Reactors for Orchestration** - Let Ash Reactor handle the flow between tool selection and execution
2. **Separate Concerns** - Keep tool selection (BAML), execution (Ash actions), and looping (CLI/GenServer) separate
3. **Type Safety** - Use Ash Union types for tool selection to get compile-time guarantees
4. **Error Handling** - Always handle errors from BAML and tool execution gracefully
5. **State Management** - Use GenServer for stateful agents, avoid global state
6. **Testing** - Test reactor steps independently before testing the full loop
7. **Resource Limits** - Set max iterations to prevent infinite loops
8. **Logging** - Add telemetry events to track agent decisions and tool usage

## Next Steps

- Add more tools beyond weather and calculator
- Implement tool chaining (output of one tool → input to another)
- Add reflection step where agent evaluates its own work
- Build multi-agent systems with specialized roles
- Add memory/RAG for context-aware tool selection
- Implement streaming responses for long-running tools

## Resources

- [Ash Framework Documentation](https://hexdocs.pm/ash/)
- [Ash Reactor Guide](https://hexdocs.pm/ash/reactor.html)
- [BAML Documentation](https://docs.boundaryml.com/)
- [AshBaml Project](https://github.com/bradleygolden/ash_baml)
