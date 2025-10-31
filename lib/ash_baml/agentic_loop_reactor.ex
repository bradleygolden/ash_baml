defmodule AshBaml.AgenticLoopReactor do
  @moduledoc """
  Ash Reactor that implements an agentic loop for tool selection and execution.

  This reactor orchestrates:
  1. Tool selection via BAML based on user input
  2. Tool execution based on the selected tool type
  3. Result aggregation and return

  ## Example

      iex> AshBaml.AgenticLoopReactor.run(%{message: "What's the weather in Paris?"})
      {:ok, %{response: "The weather in Paris is...", tool_used: :weather_tool}}

      iex> AshBaml.AgenticLoopReactor.run(%{message: "Calculate 5 + 3 + 2"})
      {:ok, %{response: "The result of add [5.0, 3.0, 2.0] is 10.0", tool_used: :calculator_tool}}

  ## Usage in an Action

  You can use this reactor within an Ash action:

      action :process_message, :map do
        argument :message, :string, allow_nil?: false

        run fn input, _ctx ->
          AshBaml.AgenticLoopReactor.run(%{message: input.arguments.message})
        end
      end

  ## Multi-turn Loop

  For a continuous agentic loop (like the Python example), you can:

  1. Call this reactor repeatedly in a recursive action
  2. Use a GenServer to maintain conversation state
  3. Build a CLI interface that calls the reactor in a loop
  """

  use Ash.Reactor

  input :message

  # Step 1: Select tool using BAML
  action :select_tool, AshBaml.AgenticToolHandler, :select_tool do
    inputs(%{
      message: input(:message)
    })
  end

  # Step 2: Execute the selected tool
  action :execute_tool, AshBaml.AgenticToolHandler, :execute_tool do
    inputs(%{
      tool_selection: result(:select_tool)
    })
  end

  # Step 3: Return formatted result with metadata
  step :format_result do
    argument :tool_selection, result(:select_tool)
    argument :execution_result, result(:execute_tool)

    run fn %{tool_selection: tool, execution_result: exec_result}, _ctx ->
      result = %{
        response: exec_result.response,
        tool_used: tool.type,
        tool_data: tool.value,
        execution_result: exec_result
      }

      {:ok, result}
    end
  end

  return :format_result
end
