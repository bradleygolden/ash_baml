defmodule AshBaml.Examples.AgentLoop do
  @moduledoc """
  A reusable action implementation for agentic loops.

  This implementation can be used by ANY resource that implements the required interface:
  - `:decide_next_action` - action that returns a union with tool calls or done signal
  - `:execute_{tool_type}` - actions to execute each tool type

  ## Usage

      defmodule MyApp.MyAgent do
        use Ash.Resource, extensions: [AshBaml.Resource]

        # ... define attributes for agent state ...

        actions do
          # Implement the required interface
          action :decide_next_action, :union do
            argument :message, :string
            argument :history, {:array, :map}
            # ... tool type constraints ...
          end

          action :execute_my_tool, :map do
            # ... tool execution ...
          end

          # Use the reusable loop
          action :handle_conversation, :map do
            argument :message, :string
            argument :max_turns, :integer, default: 5
            argument :conversation_history, {:array, :map}, default: []

            run AshBaml.Examples.AgentLoop
          end
        end
      end

  ## Options

  The action expects these arguments:
  - `message` - Initial user message
  - `max_turns` - Maximum iterations (default: 5)
  - `conversation_history` - Previous conversation (default: [])

  ## Return Value

  Returns a map with:
  - `history` - List of all interactions
  - `stopped_reason` - Why the loop stopped (`:completed`, `:max_iterations`, or `:error`)
  - `final_result` - The final result if completed successfully
  """

  use Ash.Resource.Actions.Implementation

  require Logger

  @impl true
  def run(input, _opts, _context) do
    max_iterations = input.arguments[:max_turns] || 5
    initial_message = input.arguments[:message]
    history = input.arguments[:conversation_history] || []

    Logger.info("""
    Starting agent loop:
      Resource: #{inspect(input.resource)}
      Message: #{initial_message}
      Max iterations: #{max_iterations}
    """)

    loop(input.resource, initial_message, history, max_iterations, 0)
  end

  # Loop iteration
  defp loop(_resource, _message, history, 0, iteration_count) do
    Logger.warning("Agent loop stopped: max iterations reached (#{iteration_count})")

    {:ok,
     %{
       history: Enum.reverse(history),
       stopped_reason: :max_iterations,
       iteration_count: iteration_count
     }}
  end

  defp loop(resource, message, history, iterations_remaining, iteration_count) do
    current_iteration = iteration_count + 1

    Logger.info("Agent loop iteration #{current_iteration}")

    # Step 1: Decide next action
    Logger.debug("Deciding next action...")

    case decide_next_action(resource, message, history) do
      {:ok, %Ash.Union{type: :done, value: final_result}} ->
        # Agent signaled completion
        Logger.info("Agent loop completed successfully")

        {:ok,
         %{
           history: Enum.reverse([%{type: :done, result: final_result} | history]),
           stopped_reason: :completed,
           final_result: final_result,
           iteration_count: current_iteration
         }}

      {:ok, %Ash.Union{type: tool_type, value: tool_params}} ->
        # Agent wants to use a tool
        Logger.debug("Executing tool: #{tool_type}")

        case execute_tool(resource, tool_type, tool_params) do
          {:ok, tool_result} ->
            # Record this interaction
            interaction = %{
              iteration: current_iteration,
              type: :tool_execution,
              tool: tool_type,
              params: tool_params |> Map.from_struct(),
              result: tool_result,
              timestamp: DateTime.utc_now()
            }

            # Format result for next turn
            new_message = format_tool_result_for_llm(tool_type, tool_params, tool_result)
            new_history = [interaction | history]

            # Continue loop
            loop(resource, new_message, new_history, iterations_remaining - 1, current_iteration)

          {:error, error} ->
            Logger.error("Tool execution failed: #{inspect(error)}")

            # Record the error
            error_interaction = %{
              iteration: current_iteration,
              type: :error,
              tool: tool_type,
              params: tool_params |> Map.from_struct(),
              error: error,
              timestamp: DateTime.utc_now()
            }

            {:ok,
             %{
               history: Enum.reverse([error_interaction | history]),
               stopped_reason: :error,
               error: error,
               iteration_count: current_iteration
             }}
        end

      {:error, error} ->
        Logger.error("Decision failed: #{inspect(error)}")

        {:ok,
         %{
           history: Enum.reverse(history),
           stopped_reason: :error,
           error: error,
           iteration_count: current_iteration
         }}
    end
  end

  # Call the resource's decide_next_action action
  defp decide_next_action(resource, message, history) do
    resource
    |> Ash.ActionInput.for_action(:decide_next_action, %{
      message: message,
      history: history
    })
    |> Ash.run_action()
  end

  # Call the resource's execute_{tool_type} action
  defp execute_tool(resource, tool_type, tool_params) do
    action_name = :"execute_#{tool_type}"

    # Convert struct to map for action input
    params_map =
      tool_params
      |> Map.from_struct()
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    resource
    |> Ash.ActionInput.for_action(action_name, params_map)
    |> Ash.run_action()
  end

  # Format the tool result into a message for the LLM's next turn
  defp format_tool_result_for_llm(tool_type, tool_params, tool_result) do
    """
    Previous action completed:

    Tool: #{tool_type}
    Parameters: #{inspect(tool_params |> Map.from_struct())}
    Result: #{format_result(tool_result)}

    Based on this result, what should we do next?
    """
  end

  defp format_result(result) when is_map(result) do
    result
    |> Enum.map(fn {k, v} -> "  #{k}: #{inspect(v)}" end)
    |> Enum.join("\n")
  end

  defp format_result(result), do: inspect(result)
end
