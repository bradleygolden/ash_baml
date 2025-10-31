defmodule AshBaml.AgenticLoopTest do
  @moduledoc """
  Tests for the agentic loop implementation using Ash Reactor.

  These tests verify:
  - Tool selection via BAML
  - Tool execution
  - Reactor orchestration
  - GenServer state management
  """
  use ExUnit.Case, async: true

  alias AshBaml.AgenticLoopReactor
  alias AshBaml.AgenticToolHandler
  alias AshBaml.Examples.AgenticLoopServer

  describe "AgenticToolHandler" do
    test "select_tool action returns weather tool for weather query" do
      {:ok, result} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :select_tool,
          %{message: "What's the weather in Paris?"}
        )
        |> Ash.run_action()

      assert result.type == :weather_tool
      assert is_struct(result.value, AshBaml.Test.BamlClient.WeatherTool)
      assert result.value.city == "Paris"
    end

    test "select_tool action returns calculator tool for math query" do
      {:ok, result} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :select_tool,
          %{message: "Calculate 5 + 3"}
        )
        |> Ash.run_action()

      assert result.type == :calculator_tool
      assert is_struct(result.value, AshBaml.Test.BamlClient.CalculatorTool)
      assert result.value.operation == "add"
      assert result.value.numbers == [5.0, 3.0]
    end

    test "execute_weather action returns weather data" do
      {:ok, result} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :execute_weather,
          %{city: "Tokyo", units: "celsius"}
        )
        |> Ash.run_action()

      assert result.result.city == "Tokyo"
      assert result.result.units == "celsius"
      assert is_number(result.result.temperature)
      assert is_binary(result.result.condition)
      assert result.response =~ "Tokyo"
    end

    test "execute_calculator action performs addition" do
      {:ok, result} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :execute_calculator,
          %{operation: "add", numbers: [5.0, 3.0, 2.0]}
        )
        |> Ash.run_action()

      assert result.result == 10.0
      assert result.operation == "add"
      assert result.response =~ "10.0"
    end

    test "execute_calculator action performs subtraction" do
      {:ok, result} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :execute_calculator,
          %{operation: "subtract", numbers: [20.0, 5.0, 3.0]}
        )
        |> Ash.run_action()

      assert result.result == 12.0
      assert result.operation == "subtract"
    end

    test "execute_calculator action performs multiplication" do
      {:ok, result} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :execute_calculator,
          %{operation: "multiply", numbers: [3.0, 4.0, 2.0]}
        )
        |> Ash.run_action()

      assert result.result == 24.0
      assert result.operation == "multiply"
    end

    test "execute_calculator action performs division" do
      {:ok, result} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :execute_calculator,
          %{operation: "divide", numbers: [20.0, 2.0, 2.0]}
        )
        |> Ash.run_action()

      assert result.result == 5.0
      assert result.operation == "divide"
    end

    test "execute_tool action dispatches to weather tool" do
      # First select the tool
      {:ok, tool_selection} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :select_tool,
          %{message: "What's the weather in London?"}
        )
        |> Ash.run_action()

      # Then execute it
      {:ok, result} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :execute_tool,
          %{tool_selection: tool_selection}
        )
        |> Ash.run_action()

      assert result.result.city == "London"
      assert result.response =~ "London"
    end

    test "execute_tool action dispatches to calculator tool" do
      # First select the tool
      {:ok, tool_selection} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :select_tool,
          %{message: "Multiply 7 by 8"}
        )
        |> Ash.run_action()

      # Then execute it
      {:ok, result} =
        Ash.ActionInput.for_action(
          AgenticToolHandler,
          :execute_tool,
          %{tool_selection: tool_selection}
        )
        |> Ash.run_action()

      assert result.result == 56.0
      assert result.response =~ "56.0"
    end
  end

  describe "AgenticLoopReactor" do
    test "processes weather query end-to-end" do
      {:ok, result} = AgenticLoopReactor.run(%{message: "What's the weather in Paris?"})

      assert result.tool_used == :weather_tool
      assert is_struct(result.tool_data, AshBaml.Test.BamlClient.WeatherTool)
      assert result.tool_data.city == "Paris"
      assert result.response =~ "Paris"
      assert is_map(result.execution_result)
    end

    test "processes calculator query end-to-end" do
      {:ok, result} = AgenticLoopReactor.run(%{message: "Calculate 15 * 3"})

      assert result.tool_used == :calculator_tool
      assert is_struct(result.tool_data, AshBaml.Test.BamlClient.CalculatorTool)
      assert result.tool_data.operation == "multiply"
      assert result.tool_data.numbers == [15.0, 3.0]
      assert result.execution_result.result == 45.0
      assert result.response =~ "45.0"
    end

    test "handles addition correctly" do
      {:ok, result} = AgenticLoopReactor.run(%{message: "Add 5 and 10"})

      assert result.tool_used == :calculator_tool
      assert result.execution_result.result == 15.0
    end

    test "handles different weather locations" do
      locations = ["Tokyo", "New York", "London", "Berlin"]

      for location <- locations do
        {:ok, result} = AgenticLoopReactor.run(%{message: "Weather in #{location}?"})

        assert result.tool_used == :weather_tool
        assert result.tool_data.city == location
        assert result.response =~ location
      end
    end

    test "handles different math operations" do
      test_cases = [
        {"Add 10 and 5", "add", 15.0},
        {"Subtract 10 from 20", "subtract", 10.0},
        {"Multiply 6 by 7", "multiply", 42.0},
        {"Divide 100 by 5", "divide", 20.0}
      ]

      for {query, expected_op, expected_result} <- test_cases do
        {:ok, result} = AgenticLoopReactor.run(%{message: query})

        assert result.tool_used == :calculator_tool
        assert result.tool_data.operation == expected_op
        assert result.execution_result.result == expected_result
      end
    end
  end

  describe "AgenticLoopServer" do
    setup do
      {:ok, pid} = AgenticLoopServer.start_link()
      %{pid: pid}
    end

    test "sends a single message successfully", %{pid: pid} do
      {:ok, result} = AgenticLoopServer.send_message(pid, "What's the weather in Paris?")

      assert result.turn == 1
      assert result.tool_used == :weather_tool
      assert result.response =~ "Paris"
    end

    test "maintains conversation history", %{pid: pid} do
      {:ok, result1} = AgenticLoopServer.send_message(pid, "What's the weather in Tokyo?")
      {:ok, result2} = AgenticLoopServer.send_message(pid, "Calculate 5 + 3")
      {:ok, result3} = AgenticLoopServer.send_message(pid, "What's the weather in London?")

      assert result1.turn == 1
      assert result2.turn == 2
      assert result3.turn == 3

      history = AgenticLoopServer.get_history(pid)

      assert length(history) == 3
      assert Enum.at(history, 0).turn == 1
      assert Enum.at(history, 0).message == "What's the weather in Tokyo?"
      assert Enum.at(history, 0).tool_used == :weather_tool

      assert Enum.at(history, 1).turn == 2
      assert Enum.at(history, 1).message == "Calculate 5 + 3"
      assert Enum.at(history, 1).tool_used == :calculator_tool

      assert Enum.at(history, 2).turn == 3
      assert Enum.at(history, 2).message == "What's the weather in London?"
      assert Enum.at(history, 2).tool_used == :weather_tool
    end

    test "tracks turn count correctly", %{pid: pid} do
      assert AgenticLoopServer.get_turn_count(pid) == 0

      AgenticLoopServer.send_message(pid, "Test 1")
      assert AgenticLoopServer.get_turn_count(pid) == 1

      AgenticLoopServer.send_message(pid, "Test 2")
      assert AgenticLoopServer.get_turn_count(pid) == 2

      AgenticLoopServer.send_message(pid, "Test 3")
      assert AgenticLoopServer.get_turn_count(pid) == 3
    end

    test "resets conversation history", %{pid: pid} do
      AgenticLoopServer.send_message(pid, "Test message 1")
      AgenticLoopServer.send_message(pid, "Test message 2")

      assert AgenticLoopServer.get_turn_count(pid) == 2
      assert length(AgenticLoopServer.get_history(pid)) == 2

      :ok = AgenticLoopServer.reset(pid)

      assert AgenticLoopServer.get_turn_count(pid) == 0
      assert AgenticLoopServer.get_history(pid) == []
    end

    test "includes timestamps in history entries", %{pid: pid} do
      before_time = DateTime.utc_now()
      {:ok, _result} = AgenticLoopServer.send_message(pid, "Test message")
      after_time = DateTime.utc_now()

      [entry] = AgenticLoopServer.get_history(pid)

      assert %DateTime{} = entry.timestamp
      assert DateTime.compare(entry.timestamp, before_time) in [:gt, :eq]
      assert DateTime.compare(entry.timestamp, after_time) in [:lt, :eq]
    end

    test "stores full result in history", %{pid: pid} do
      {:ok, _result} = AgenticLoopServer.send_message(pid, "Calculate 10 + 5")

      [entry] = AgenticLoopServer.get_history(pid)

      assert entry.full_result.tool_used == :calculator_tool
      assert entry.full_result.execution_result.result == 15.0
      assert is_struct(entry.full_result.tool_data, AshBaml.Test.BamlClient.CalculatorTool)
    end

    test "handles multiple concurrent servers independently" do
      {:ok, pid1} = AgenticLoopServer.start_link()
      {:ok, pid2} = AgenticLoopServer.start_link()

      AgenticLoopServer.send_message(pid1, "Weather in Paris?")
      AgenticLoopServer.send_message(pid2, "Calculate 5 + 5")

      history1 = AgenticLoopServer.get_history(pid1)
      history2 = AgenticLoopServer.get_history(pid2)

      assert length(history1) == 1
      assert length(history2) == 1
      assert Enum.at(history1, 0).tool_used == :weather_tool
      assert Enum.at(history2, 0).tool_used == :calculator_tool
    end
  end

  describe "integration scenarios" do
    test "multi-turn conversation with mixed tools" do
      {:ok, pid} = AgenticLoopServer.start_link()

      # Turn 1: Weather query
      {:ok, result1} = AgenticLoopServer.send_message(pid, "What's the weather in Paris?")
      assert result1.turn == 1
      assert result1.tool_used == :weather_tool

      # Turn 2: Calculator query
      {:ok, result2} = AgenticLoopServer.send_message(pid, "Add 10 and 20")
      assert result2.turn == 2
      assert result2.tool_used == :calculator_tool
      assert result2.execution_result.result == 30.0

      # Turn 3: Another weather query
      {:ok, result3} = AgenticLoopServer.send_message(pid, "Weather in Tokyo?")
      assert result3.turn == 3
      assert result3.tool_used == :weather_tool

      # Turn 4: Another calculator query
      {:ok, result4} = AgenticLoopServer.send_message(pid, "Multiply 5 by 6")
      assert result4.turn == 4
      assert result4.tool_used == :calculator_tool
      assert result4.execution_result.result == 30.0

      # Verify complete history
      history = AgenticLoopServer.get_history(pid)
      assert length(history) == 4

      tools_used = Enum.map(history, & &1.tool_used)
      assert tools_used == [:weather_tool, :calculator_tool, :weather_tool, :calculator_tool]
    end

    test "CLI example pattern (simulated)" do
      # Simulate what happens in the CLI loop
      messages = [
        "What's the weather in London?",
        "Calculate 100 divided by 5",
        "Weather in Berlin?"
      ]

      results =
        Enum.map(messages, fn message ->
          {:ok, result} = AgenticLoopReactor.run(%{message: message})
          result
        end)

      assert length(results) == 3
      assert Enum.at(results, 0).tool_used == :weather_tool
      assert Enum.at(results, 1).tool_used == :calculator_tool
      assert Enum.at(results, 2).tool_used == :weather_tool
    end
  end
end
