defmodule AshBaml.ToolCallingTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias AshBaml.Test.BamlClient
  alias AshBaml.Test.BamlClient.Types
  alias AshBaml.Test.ToolTestResource

  describe "union return type actions" do
    test "action can declare union return type with tool constraints" do
      action = Info.action(ToolTestResource, :select_tool)

      assert action.returns == Ash.Type.Union
      assert action.constraints[:types][:weather_tool]
      assert action.constraints[:types][:calculator_tool]
    end

    test "union type uses struct with instance_of constraint" do
      action = Info.action(ToolTestResource, :select_tool)

      weather_config = action.constraints[:types][:weather_tool]
      assert weather_config[:type] == Ash.Type.Struct
      assert weather_config[:constraints][:instance_of] == Types.WeatherTool

      calculator_config = action.constraints[:types][:calculator_tool]
      assert calculator_config[:type] == Ash.Type.Struct
      assert calculator_config[:constraints][:instance_of] == Types.CalculatorTool
    end
  end

  describe "tool execution pattern" do
    test "can dispatch weather tool to execution action" do
      tool_result = %Types.WeatherTool{
        city: "San Francisco",
        units: "celsius"
      }

      {:ok, weather_data} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:execute_weather, %{
          city: tool_result.city,
          units: tool_result.units
        })
        |> Ash.run_action()

      assert weather_data.city == "San Francisco"
      assert weather_data.units == "celsius"
      assert is_float(weather_data.temperature)
      assert weather_data.condition == "sunny"
    end

    test "can dispatch calculator tool to execution action" do
      tool_result = %Types.CalculatorTool{
        operation: "add",
        numbers: [1.0, 2.0, 3.0]
      }

      {:ok, result} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:execute_calculator, %{
          operation: tool_result.operation,
          numbers: tool_result.numbers
        })
        |> Ash.run_action()

      assert result == 6.0
    end

    test "calculator handles different operations" do
      test_cases = [
        {"add", [10.0, 20.0, 30.0], 60.0},
        {"subtract", [100.0, 25.0, 10.0], 65.0},
        {"multiply", [2.0, 3.0, 4.0], 24.0},
        {"divide", [100.0, 2.0, 5.0], 10.0}
      ]

      for {operation, numbers, expected} <- test_cases do
        {:ok, result} =
          ToolTestResource
          |> Ash.ActionInput.for_action(:execute_calculator, %{
            operation: operation,
            numbers: numbers
          })
          |> Ash.run_action()

        assert result == expected, "#{operation} failed: expected #{expected}, got #{result}"
      end
    end
  end

  describe "tool dispatching helper pattern" do
    # Helper function that demonstrates the recommended dispatch pattern
    # This avoids compiler warnings about unreachable clauses in individual tests
    defp dispatch_tool(tool_result) do
      case tool_result do
        %Types.WeatherTool{city: city, units: units} ->
          {:ok, data} =
            ToolTestResource
            |> Ash.ActionInput.for_action(:execute_weather, %{city: city, units: units})
            |> Ash.run_action()

          {:weather, data}

        %Types.CalculatorTool{operation: op, numbers: nums} ->
          {:ok, result} =
            ToolTestResource
            |> Ash.ActionInput.for_action(:execute_calculator, %{
              operation: op,
              numbers: nums
            })
            |> Ash.run_action()

          {:calculator, result}
      end
    end

    test "manual case-based dispatch works correctly for weather tool" do
      tool_result = %Types.WeatherTool{
        city: "London",
        units: "fahrenheit"
      }

      result = dispatch_tool(tool_result)

      assert {:weather, %{city: "London", units: "fahrenheit"}} = result
    end

    test "manual case-based dispatch works correctly for calculator tool" do
      tool_result = %Types.CalculatorTool{
        operation: "multiply",
        numbers: [5.0, 7.0]
      }

      result = dispatch_tool(tool_result)

      assert {:calculator, 35.0} = result
    end
  end

  describe "BAML-generated tool structs" do
    test "WeatherTool struct has correct fields" do
      weather = %Types.WeatherTool{
        city: "Tokyo",
        units: "celsius"
      }

      assert weather.city == "Tokyo"
      assert weather.units == "celsius"
    end

    test "CalculatorTool struct has correct fields" do
      calculator = %Types.CalculatorTool{
        operation: "add",
        numbers: [1.0, 2.0, 3.0]
      }

      assert calculator.operation == "add"
      assert calculator.numbers == [1.0, 2.0, 3.0]
    end

    @tag :integration
    test "SelectTool function module exists" do
      assert Code.ensure_loaded?(BamlClient.SelectTool)
      assert function_exported?(BamlClient.SelectTool, :call, 2)
    end
  end
end
