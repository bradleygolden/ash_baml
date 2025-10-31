# Building an Agent with Agentic Loops

Learn how to build a multi-step agent that makes sequential LLM calls, maintains state, and decides when to terminate.

## Prerequisites

- Completed previous tutorials ([Get Started](01-get-started.md), [Structured Output](02-structured-output.md), [Tool Calling](03-tool-calling.md))
- Understanding of Ash actions and `Ash.Resource.Actions.Implementation`
- Familiarity with Elixir processes and state management

## Goals

1. Understand the agentic loop pattern
2. Define BAML functions for agent steps
3. Implement custom action logic with `Ash.Resource.Actions.Implementation`
4. Manage state across iterations
5. Implement termination conditions
6. Handle feedback loops (output → next input)

## The Agentic Loop Pattern

An agent is a system that:

1. **Observes**: Takes input from environment/previous step
2. **Thinks**: Calls LLM to decide next action
3. **Acts**: Executes the decided action
4. **Repeats**: Continues until goal is achieved or max iterations reached

This differs from simple tool calling because the agent can make multiple decisions in sequence, learning from each step.

## Define Agent BAML Functions

Create `baml_src/agent.baml`:

```baml
enum AgentAction {
  Search
  Analyze
  Complete
}

class AgentStep {
  action AgentAction @description("What action to take next")
  reasoning string @description("Why this action is needed")
  query string? @description("Query for search action")
  analysis string? @description("Analysis results")
  final_answer string? @description("Final answer if completing")
}

class AgentState {
  goal string @description("User's original goal")
  steps_taken string[] @description("Actions taken so far")
  information_gathered string[] @description("Information collected")
  iteration int @description("Current iteration number")
}

client GPT4 {
  provider openai
  options {
    model gpt-4
    api_key env.OPENAI_API_KEY
  }
}

function PlanNextStep(state: AgentState) -> AgentStep {
  client GPT4
  prompt #"
    You are a research agent. Your goal: {{ state.goal }}

    Current state:
    - Iteration: {{ state.iteration }}
    - Steps taken: {{ state.steps_taken }}
    - Information gathered: {{ state.information_gathered }}

    Decide the next action:
    - Search: If you need more information
    - Analyze: If you need to process gathered information
    - Complete: If you have enough to answer the goal

    {{ ctx.output_format }}
  "#
}

function AnalyzeInformation(information: string[], goal: string) -> string {
  client GPT4
  prompt #"
    Analyze the following information to answer: {{ goal }}

    Information:
    {% for item in information %}
    - {{ item }}
    {% endfor %}

    Provide your analysis:
    {{ ctx.output_format }}
  "#
}
```

## Generate Types

Generate Ash types from BAML:

```bash
mix ash_baml.gen.types MyApp.BamlClient
```

This creates:
- `MyApp.BamlClient.Types.AgentAction` (enum)
- `MyApp.BamlClient.Types.AgentStep` (struct)
- `MyApp.BamlClient.Types.AgentState` (struct)

## Create Agent Resource with Custom Logic

Create `lib/my_app/research_agent.ex`:

```elixir
defmodule MyApp.ResearchAgent do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshBaml.Resource]

  alias MyApp.BamlClient.Types.{AgentAction, AgentStep, AgentState}

  baml do
    client_module MyApp.BamlClient
    import_functions [:PlanNextStep, :AnalyzeInformation]
  end

  actions do
    # Main agent loop action
    action :run_agent, :map do
      argument :goal, :string, allow_nil?: false
      argument :max_iterations, :integer, default: 5

      run MyApp.ResearchAgent.AgentLoop
    end

    # Auto-generated BAML actions:
    # :plan_next_step, :plan_next_step_stream
    # :analyze_information, :analyze_information_stream
  end
end
```

## Implement the Agent Loop

Create `lib/my_app/research_agent/agent_loop.ex`:

```elixir
defmodule MyApp.ResearchAgent.AgentLoop do
  @moduledoc """
  Custom action implementation for the agentic loop.
  """

  use Ash.Resource.Actions.Implementation

  alias MyApp.ResearchAgent
  alias MyApp.BamlClient.Types.{AgentAction, AgentStep, AgentState}

  @impl true
  def run(input, _opts, _context) do
    goal = input.arguments.goal
    max_iterations = input.arguments.max_iterations || 5

    # Initialize state
    initial_state = %AgentState{
      goal: goal,
      steps_taken: [],
      information_gathered: [],
      iteration: 0
    }

    # Run the loop
    case run_loop(initial_state, max_iterations) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp run_loop(state, max_iterations) do
    if state.iteration >= max_iterations do
      {:ok, %{
        status: :max_iterations_reached,
        iterations: state.iteration,
        steps_taken: state.steps_taken,
        information: state.information_gathered
      }}
    else
      # Step 1: Plan next action
      case plan_next_step(state) do
        {:ok, step} ->
          # Step 2: Execute action
          case execute_step(step, state) do
            {:ok, :complete, final_answer} ->
              {:ok, %{
                status: :completed,
                answer: final_answer,
                iterations: state.iteration + 1,
                steps_taken: state.steps_taken ++ [step.reasoning]
              }}

            {:ok, :continue, updated_state} ->
              # Continue loop with updated state
              run_loop(updated_state, max_iterations)

            {:error, reason} ->
              {:error, {:execution_failed, reason, state}}
          end

        {:error, reason} ->
          {:error, {:planning_failed, reason, state}}
      end
    end
  end

  defp plan_next_step(state) do
    ResearchAgent
    |> Ash.ActionInput.for_action(:plan_next_step, %{state: state})
    |> Ash.run_action()
  end

  defp execute_step(%AgentStep{action: :complete, final_answer: answer}, _state) do
    {:ok, :complete, answer}
  end

  defp execute_step(%AgentStep{action: :search, query: query, reasoning: reasoning}, state) do
    # Simulate search (replace with real search API)
    search_results = perform_search(query)

    updated_state = %AgentState{
      state
      | iteration: state.iteration + 1,
        steps_taken: state.steps_taken ++ ["Search: #{reasoning}"],
        information_gathered: state.information_gathered ++ [search_results]
    }

    {:ok, :continue, updated_state}
  end

  defp execute_step(%AgentStep{action: :analyze, reasoning: reasoning}, state) do
    # Call BAML analyze function
    case analyze_information(state.information_gathered, state.goal) do
      {:ok, analysis} ->
        updated_state = %AgentState{
          state
          | iteration: state.iteration + 1,
            steps_taken: state.steps_taken ++ ["Analyze: #{reasoning}"],
            information_gathered: state.information_gathered ++ [analysis]
        }

        {:ok, :continue, updated_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analyze_information(information, goal) do
    ResearchAgent
    |> Ash.ActionInput.for_action(:analyze_information, %{
      information: information,
      goal: goal
    })
    |> Ash.run_action()
  end

  # Placeholder search function
  defp perform_search(query) do
    "Search results for: #{query}"
  end
end
```

## Use the Agent

```elixir
# Start the agent with a research goal
iex> {:ok, result} = MyApp.ResearchAgent
...>   |> Ash.ActionInput.for_action(:run_agent, %{
...>     goal: "What are the key benefits of using Elixir for web development?",
...>     max_iterations: 5
...>   })
...>   |> Ash.run_action()

iex> result
%{
  status: :completed,
  answer: "Elixir offers several key benefits for web development: 1) Concurrency through lightweight processes...",
  iterations: 3,
  steps_taken: [
    "Search: Need to gather information about Elixir benefits",
    "Search: Need more specific information about web development use cases",
    "Analyze: Have enough information to provide comprehensive answer"
  ]
}
```

## Understanding State Management

The agent maintains state through the `AgentState` struct:

```elixir
%AgentState{
  goal: "User's question",
  steps_taken: ["Action 1", "Action 2"],        # History
  information_gathered: ["Info 1", "Info 2"],   # Knowledge base
  iteration: 2                                   # Progress tracker
}
```

State flows through the loop:

1. **Initial State**: Created with user's goal
2. **Planning**: State sent to `PlanNextStep` BAML function
3. **Execution**: Action updates state with new information
4. **Feedback**: Updated state becomes input for next iteration

## Termination Conditions

The agent stops when:

1. **Goal Achieved**: LLM returns `Complete` action
   ```elixir
   defp execute_step(%AgentStep{action: :complete, final_answer: answer}, _state) do
     {:ok, :complete, answer}
   end
   ```

2. **Max Iterations**: Safety limit reached
   ```elixir
   if state.iteration >= max_iterations do
     {:ok, %{status: :max_iterations_reached, ...}}
   end
   ```

3. **Error**: Execution fails
   ```elixir
   {:error, reason} -> {:error, {:execution_failed, reason, state}}
   ```

## Adding Streaming Support

For long-running agents, provide progress updates:

```elixir
defmodule MyApp.ResearchAgent.AgentLoopStream do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    goal = input.arguments.goal
    max_iterations = input.arguments.max_iterations || 5

    initial_state = %AgentState{
      goal: goal,
      steps_taken: [],
      information_gathered: [],
      iteration: 0
    }

    # Return a stream that emits progress updates
    stream = Stream.resource(
      fn -> initial_state end,
      fn state ->
        case run_iteration(state, max_iterations) do
          {:ok, :complete, final_answer} ->
            {[%{type: :complete, answer: final_answer}], :halt}

          {:ok, :continue, step, updated_state} ->
            {[%{type: :step, step: step, state: updated_state}], updated_state}

          {:error, reason} ->
            {[%{type: :error, reason: reason}], :halt}
        end
      end,
      fn _ -> :ok end
    )

    {:ok, stream}
  end

  defp run_iteration(state, max_iterations) do
    # Similar logic but returns per-iteration results
    # ...
  end
end
```

Add to actions:

```elixir
action :run_agent_stream, AshBaml.Type.Stream do
  argument :goal, :string, allow_nil?: false
  argument :max_iterations, :integer, default: 5

  run MyApp.ResearchAgent.AgentLoopStream
end
```

Usage:

```elixir
{:ok, stream} = MyApp.ResearchAgent
  |> Ash.ActionInput.for_action(:run_agent_stream, %{goal: "..."})
  |> Ash.run_action()

stream
|> Stream.each(fn
  %{type: :step, step: step} ->
    IO.puts("Step: #{step.reasoning}")

  %{type: :complete, answer: answer} ->
    IO.puts("Complete: #{answer}")

  %{type: :error, reason: reason} ->
    IO.puts("Error: #{inspect(reason)}")
end)
|> Stream.run()
```

## Advanced Patterns

### 1. State Persistence

Save state between runs:

```elixir
defmodule MyApp.PersistentAgent do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :goal, :string, allow_nil?: false
    attribute :state, :map, allow_nil?: false
    attribute :status, :atom, allow_nil?: false
    attribute :result, :map
  end

  actions do
    action :continue_agent, :map do
      argument :agent_id, :uuid, allow_nil?: false

      run fn input, _ctx ->
        # Load saved state
        agent = MyApp.PersistentAgent |> Ash.get!(input.arguments.agent_id)

        # Continue from saved state
        case run_loop(agent.state, 5) do
          {:ok, result} ->
            # Update with result
            agent
            |> Ash.Changeset.for_update(:update, %{
              status: :completed,
              result: result
            })
            |> Ash.update!()

            {:ok, result}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end
end
```

### 2. Multi-Agent Collaboration

Multiple agents working together:

```elixir
defmodule MyApp.AgentOrchestrator do
  def run_multi_agent(goal) do
    # Agent 1: Research
    {:ok, research_results} = MyApp.ResearchAgent
      |> Ash.ActionInput.for_action(:run_agent, %{goal: goal})
      |> Ash.run_action()

    # Agent 2: Critic (review research)
    {:ok, critique} = MyApp.CriticAgent
      |> Ash.ActionInput.for_action(:critique, %{
        content: research_results.answer
      })
      |> Ash.run_action()

    # Agent 3: Synthesizer (combine insights)
    {:ok, final_answer} = MyApp.SynthesizerAgent
      |> Ash.ActionInput.for_action(:synthesize, %{
        research: research_results.answer,
        critique: critique.feedback
      })
      |> Ash.run_action()

    {:ok, final_answer}
  end
end
```

### 3. Error Recovery

Implement retry and fallback logic:

```elixir
defp execute_step_with_retry(step, state, retries \\ 3) do
  case execute_step(step, state) do
    {:ok, result} ->
      {:ok, result}

    {:error, reason} when retries > 0 ->
      # Log error
      Logger.warning("Step failed: #{inspect(reason)}, retrying...")

      # Wait and retry
      Process.sleep(1000)
      execute_step_with_retry(step, state, retries - 1)

    {:error, reason} ->
      # All retries exhausted, try fallback action
      fallback_step = %AgentStep{
        action: :analyze,
        reasoning: "Original action failed, analyzing available information"
      }
      execute_step(fallback_step, state)
  end
end
```

## Telemetry Integration

Add telemetry events for monitoring:

```elixir
defp run_loop(state, max_iterations) do
  :telemetry.execute(
    [:my_app, :agent, :iteration, :start],
    %{iteration: state.iteration},
    %{goal: state.goal}
  )

  result = if state.iteration >= max_iterations do
    # ... termination logic
  else
    # ... loop logic
  end

  :telemetry.execute(
    [:my_app, :agent, :iteration, :stop],
    %{iteration: state.iteration},
    %{goal: state.goal, result: result}
  )

  result
end
```

See [Telemetry](../topics/telemetry.md) for complete integration guide.

## What You Learned

- Building agentic loops with sequential BAML calls
- Implementing custom action logic with `Ash.Resource.Actions.Implementation`
- Managing state across iterations
- Implementing termination conditions
- Creating feedback loops (output → next input)
- Streaming progress updates
- Advanced patterns: persistence, multi-agent, error recovery
- Telemetry integration for monitoring

## Next Steps

- **Topics**: [Patterns](../topics/patterns.md) - Architectural patterns for agents
- **Topics**: [Actions](../topics/actions.md) - Deep dive into custom action implementations
- **How to**: [Build Agentic Loop](../how-to/build-agentic-loop.md) - Advanced agentic patterns
- **How to**: [Configure Telemetry](../how-to/configure-telemetry.md) - Monitor agent performance

See also:
- [Tool Calling](03-tool-calling.md) - Agents can use tools for actions
- [Ash Actions Documentation](https://hexdocs.pm/ash/actions.html) - Understanding Ash action system
