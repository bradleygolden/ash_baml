# How to Build Agentic Loop

Step-by-step guide to building autonomous agents with feedback loops.

## Overview

An agentic loop allows the LLM to:
1. Plan the next action based on current state
2. Execute that action
3. Update state with results
4. Repeat until goal achieved or max iterations

## Step 1: Define State and Action Types

Create `baml_src/agent.baml`:

```baml
enum AgentAction {
  Search
  Analyze
  Complete
}

class AgentStep {
  action AgentAction
  reasoning string
  query string?
  final_answer string?
}

class AgentState {
  goal string
  steps_taken string[]
  information_gathered string[]
  iteration int
}

function PlanNextStep(state: AgentState) -> AgentStep {
  client GPT4
  prompt #"
    You are a research agent. Goal: {{ state.goal }}

    Current iteration: {{ state.iteration }}
    Steps taken: {{ state.steps_taken }}
    Information: {{ state.information_gathered }}

    Decide next action:
    - Search: Need more information
    - Analyze: Process gathered information
    - Complete: Have enough to answer

    {{ ctx.output_format }}
  "#
}
```

## Step 2: Generate Types

```bash
baml build
mix ash_baml.gen.types MyApp.BamlClient
```

## Step 3: Create Agent Resource

```elixir
defmodule MyApp.Agent do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
    import_functions [:PlanNextStep]
  end

  actions do
    action :run_agent, :map do
      argument :goal, :string, allow_nil?: false
      argument :max_iterations, :integer, default: 5

      run MyApp.Agent.AgentLoop
    end
  end
end
```

## Step 4: Implement Agent Loop

```elixir
defmodule MyApp.Agent.AgentLoop do
  use Ash.Resource.Actions.Implementation

  alias MyApp.BamlClient.Types.{AgentState, AgentStep}

  @impl true
  def run(input, _opts, _context) do
    initial_state = %AgentState{
      goal: input.arguments.goal,
      steps_taken: [],
      information_gathered: [],
      iteration: 0
    }

    run_loop(initial_state, input.arguments.max_iterations)
  end

  defp run_loop(state, max_iterations) do
    if state.iteration >= max_iterations do
      {:ok, %{
        status: :max_iterations,
        iterations: state.iteration,
        steps: state.steps_taken
      }}
    else
      # Plan next step
      case plan_step(state) do
        {:ok, step} ->
          # Execute step
          case execute_step(step, state) do
            {:ok, :complete, answer} ->
              {:ok, %{
                status: :completed,
                answer: answer,
                iterations: state.iteration + 1,
                steps: state.steps_taken ++ [step.reasoning]
              }}

            {:ok, :continue, updated_state} ->
              run_loop(updated_state, max_iterations)

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp plan_step(state) do
    MyApp.Agent
    |> Ash.ActionInput.for_action(:plan_next_step, %{state: state})
    |> Ash.run_action()
  end

  defp execute_step(%AgentStep{action: :complete, final_answer: answer}, _state) do
    {:ok, :complete, answer}
  end

  defp execute_step(%AgentStep{action: :search, query: query, reasoning: reasoning}, state) do
    # Perform search
    results = search(query)

    updated_state = %AgentState{
      state
      | iteration: state.iteration + 1,
        steps_taken: state.steps_taken ++ ["Search: #{reasoning}"],
        information_gathered: state.information_gathered ++ [results]
    }

    {:ok, :continue, updated_state}
  end

  defp execute_step(%AgentStep{action: :analyze, reasoning: reasoning}, state) do
    # Analyze gathered information
    analysis = analyze(state.information_gathered, state.goal)

    updated_state = %AgentState{
      state
      | iteration: state.iteration + 1,
        steps_taken: state.steps_taken ++ ["Analyze: #{reasoning}"],
        information_gathered: state.information_gathered ++ [analysis]
    }

    {:ok, :continue, updated_state}
  end

  # Placeholder functions - replace with real implementations
  defp search(query), do: "Results for: #{query}"
  defp analyze(info, goal), do: "Analysis of #{length(info)} items for #{goal}"
end
```

## Step 5: Use the Agent

```elixir
{:ok, result} = MyApp.Agent
  |> Ash.ActionInput.for_action(:run_agent, %{
    goal: "What are the benefits of Elixir?",
    max_iterations: 5
  })
  |> Ash.run_action()

IO.inspect(result)
# %{
#   status: :completed,
#   answer: "Elixir provides...",
#   iterations: 3,
#   steps: ["Search: ...", "Analyze: ...", "Search: ..."]
# }
```

## Adding Streaming Progress Updates

```elixir
defmodule MyApp.Agent.AgentLoopStream do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    initial_state = %AgentState{
      goal: input.arguments.goal,
      steps_taken: [],
      information_gathered: [],
      iteration: 0
    }

    stream = Stream.resource(
      fn -> initial_state end,
      fn state ->
        if state.iteration >= input.arguments.max_iterations do
          {[%{type: :max_iterations, state: state}], :halt}
        else
          case run_iteration(state) do
            {:ok, :complete, answer} ->
              {[%{type: :complete, answer: answer, state: state}], :halt}

            {:ok, :continue, step, updated_state} ->
              {[%{type: :step, step: step, state: updated_state}], updated_state}

            {:error, reason} ->
              {[%{type: :error, reason: reason}], :halt}
          end
        end
      end,
      fn _ -> :ok end
    )

    {:ok, stream}
  end

  defp run_iteration(state) do
    # Similar logic but returns per-iteration
    # ...
  end
end
```

Add streaming action:

```elixir
action :run_agent_stream, AshBaml.Type.Stream do
  argument :goal, :string
  argument :max_iterations, :integer, default: 5

  run MyApp.Agent.AgentLoopStream
end
```

## State Persistence

For long-running agents, persist state:

```elixir
defmodule MyApp.PersistentAgent do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :goal, :string
    attribute :state, :map
    attribute :status, :atom
    attribute :result, :map
  end

  actions do
    create :start do
      accept [:goal]

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :state, %{
          iteration: 0,
          steps_taken: [],
          information_gathered: []
        })
        |> Ash.Changeset.change_attribute(:status, :running)
      end
    end

    action :continue, :map do
      argument :agent_id, :uuid

      run fn input, _ctx ->
        agent = MyApp.PersistentAgent |> Ash.get!(input.arguments.agent_id)

        case run_next_iteration(agent.state, agent.goal) do
          {:ok, :complete, answer} ->
            agent
            |> Ash.Changeset.for_update(:update, %{
              status: :completed,
              result: %{answer: answer}
            })
            |> Ash.update!()

            {:ok, %{status: :completed, answer: answer}}

          {:ok, :continue, new_state} ->
            agent
            |> Ash.Changeset.for_update(:update, %{state: new_state})
            |> Ash.update!()

            {:ok, %{status: :running, state: new_state}}
        end
      end
    end
  end
end
```

## Error Recovery

Add retry and fallback logic:

```elixir
defp execute_step_with_retry(step, state, retries \\ 3) do
  case execute_step(step, state) do
    {:ok, result} ->
      {:ok, result}

    {:error, _reason} when retries > 0 ->
      Process.sleep(1000)
      execute_step_with_retry(step, state, retries - 1)

    {:error, _reason} ->
      # Fallback: try analysis instead
      fallback_step = %AgentStep{
        action: :analyze,
        reasoning: "Original action failed, analyzing available data"
      }
      execute_step(fallback_step, state)
  end
end
```

## Testing

```elixir
defmodule MyApp.AgentTest do
  use ExUnit.Case

  test "agent completes within max iterations" do
    {:ok, result} = MyApp.Agent
      |> Ash.ActionInput.for_action(:run_agent, %{
        goal: "Test goal",
        max_iterations: 5
      })
      |> Ash.run_action()

    assert result.status in [:completed, :max_iterations]
    assert result.iterations <= 5
  end

  test "agent state progresses" do
    # Mock plan_next_step to return predictable steps
    expect(MyApp.BamlClientMock, :plan_next_step, fn %{state: state} ->
      step = case state.iteration do
        0 -> %AgentStep{action: :search, query: "test", reasoning: "Need info"}
        1 -> %AgentStep{action: :analyze, reasoning: "Process results"}
        _ -> %AgentStep{action: :complete, final_answer: "Done"}
      end

      {:ok, step}
    end)

    {:ok, result} = MyApp.Agent
      |> Ash.ActionInput.for_action(:run_agent, %{goal: "Test"})
      |> Ash.run_action()

    assert result.status == :completed
    assert length(result.steps) == 3
  end
end
```

## Next Steps

- [Tutorial: Building an Agent](../tutorials/04-building-an-agent.md) - Complete tutorial
- [Topic: Patterns](../topics/patterns.md) - Agent patterns
- [How to: Customize Actions](customize-actions.md) - Advanced customization

## Related

- [Tutorial: Building an Agent](../tutorials/04-building-an-agent.md) - Full walkthrough
- [Topic: Actions](../topics/actions.md) - Custom action implementations
