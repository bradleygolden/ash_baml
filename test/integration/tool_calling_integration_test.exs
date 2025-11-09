defmodule AshBaml.ToolCallingIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  alias AshBaml.Test.{BamlClient, ToolTestResource}

  describe "complete tool calling workflow" do
    test "full workflow: select tool -> dispatch -> execute (weather)" do
      {:ok, response} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "What's the weather like in Tokyo?"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      tool_call = response.data
      assert %Ash.Union{type: :weather_tool, value: weather_tool} = tool_call
      assert weather_tool.city == "Tokyo"

      {:ok, weather_result} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:execute_weather, %{
          city: weather_tool.city,
          units: weather_tool.units
        })
        |> Ash.run_action()

      assert weather_result.city == "Tokyo"
      assert is_float(weather_result.temperature)
    end

    test "full workflow: select tool -> dispatch -> execute (calculator)" do
      {:ok, response} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "Calculate 10 + 20 + 30"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      tool_call = response.data
      assert %Ash.Union{type: :calculator_tool, value: calc_tool} = tool_call
      assert calc_tool.operation == "add"
      assert calc_tool.numbers == [10.0, 20.0, 30.0]

      {:ok, result} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:execute_calculator, %{
          operation: calc_tool.operation,
          numbers: calc_tool.numbers
        })
        |> Ash.run_action()

      assert result == 60.0
    end

    test "ambiguous prompt selects valid tool" do
      ambiguous_message = "What about 72 degrees?"

      {:ok, response} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: ambiguous_message
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      tool_call = response.data
      assert %Ash.Union{} = tool_call

      assert tool_call.type in [:weather_tool, :calculator_tool],
             "Expected valid tool selection, got #{tool_call.type}"
    end

    test "tool with all fields populated (weather)" do
      {:ok, response} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "What's the temperature in Seattle in celsius?"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      tool_call = response.data
      assert %Ash.Union{type: :weather_tool, value: weather_tool} = tool_call

      assert weather_tool.city != nil
      assert weather_tool.city != ""
      assert String.contains?(String.downcase(weather_tool.city), "seattle")

      assert weather_tool.units != nil
      assert weather_tool.units != ""
      assert weather_tool.units in ["celsius", "fahrenheit"]
      assert weather_tool.units == "celsius"
    end

    test "tool with all fields populated (calculator)" do
      {:ok, response} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "Multiply 3.5 times 2.0 and 4.0"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      tool_call = response.data
      assert %Ash.Union{type: :calculator_tool, value: calc_tool} = tool_call

      assert calc_tool.operation != nil
      assert calc_tool.operation in ["add", "subtract", "multiply", "divide"]
      assert calc_tool.operation == "multiply"

      assert calc_tool.numbers != nil
      assert is_list(calc_tool.numbers)
      assert length(calc_tool.numbers) > 0

      Enum.each(calc_tool.numbers, fn num ->
        assert is_float(num)
      end)

      expected_numbers = MapSet.new([3.5, 2.0, 4.0])
      actual_numbers = MapSet.new(calc_tool.numbers)

      assert MapSet.subset?(expected_numbers, actual_numbers),
             "Expected numbers #{inspect(expected_numbers)}, got #{inspect(actual_numbers)}"
    end

    test "3+ tool options in union (timer tool)" do
      {:ok, response} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "Set a timer for 5 minutes called 'tea brewing'"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      tool_call = response.data
      assert %Ash.Union{type: :timer_tool, value: timer_tool} = tool_call

      assert timer_tool.duration_seconds != nil
      assert is_integer(timer_tool.duration_seconds)

      assert timer_tool.duration_seconds in 295..305,
             "Expected ~300 seconds for '5 minutes', got #{timer_tool.duration_seconds}"

      assert timer_tool.label != nil
      assert is_binary(timer_tool.label)
      assert String.contains?(String.downcase(timer_tool.label), "tea")
    end

    test "concurrent tool selection calls (cluster-safe)" do
      messages = [
        "What's the weather in Tokyo?",
        "Calculate 100 + 200",
        "Temperature in London in fahrenheit?",
        "Divide 50 by 2",
        "Weather forecast for Paris?"
      ]

      start_time = System.monotonic_time(:millisecond)

      results =
        messages
        |> Task.async_stream(
          fn message ->
            {:ok, response} =
              ToolTestResource
              |> Ash.ActionInput.for_action(:select_tool, %{message: message})
              |> Ash.run_action()

            {message, response.data}
          end,
          timeout: 30_000,
          max_concurrency: 5
        )
        |> Enum.to_list()

      _duration = System.monotonic_time(:millisecond) - start_time

      Enum.each(results, fn result ->
        assert {:ok, {_message, _tool_call}} = result
      end)

      tool_calls =
        Enum.map(results, fn {:ok, {message, tool_call}} ->
          {message, tool_call}
        end)

      Enum.each(tool_calls, fn {_message, tool_call} ->
        assert %Ash.Union{} = tool_call
        assert tool_call.type in [:weather_tool, :calculator_tool]
      end)

      weather_calls =
        Enum.filter(tool_calls, fn {msg, _} ->
          String.contains?(msg, "weather") or String.contains?(msg, "Temperature") or
            String.contains?(msg, "forecast")
        end)

      calc_calls =
        Enum.filter(tool_calls, fn {msg, _} ->
          String.contains?(msg, "Calculate") or String.contains?(msg, "Divide")
        end)

      assert length(weather_calls) == 3
      assert length(calc_calls) == 2

      Enum.each(weather_calls, fn {_msg, tool_call} ->
        assert tool_call.type == :weather_tool
      end)

      Enum.each(calc_calls, fn {_msg, tool_call} ->
        assert tool_call.type == :calculator_tool
      end)
    end

    defp dispatch_tool_union(tool_union) do
      case tool_union do
        %Ash.Union{type: :weather_tool, value: %BamlClient.WeatherTool{} = tool} ->
          {:ok, data} =
            ToolTestResource
            |> Ash.ActionInput.for_action(:execute_weather, %{
              city: tool.city,
              units: tool.units
            })
            |> Ash.run_action()

          {:weather, data}

        %Ash.Union{type: :calculator_tool, value: %BamlClient.CalculatorTool{} = tool} ->
          {:ok, result} =
            ToolTestResource
            |> Ash.ActionInput.for_action(:execute_calculator, %{
              operation: tool.operation,
              numbers: tool.numbers
            })
            |> Ash.run_action()

          {:calculator, result}
      end
    end

    test "integration test documentation - tool calling pattern" do
      simulated_weather_tool = %BamlClient.WeatherTool{
        city: "Paris",
        units: "celsius"
      }

      simulated_union = %Ash.Union{
        type: :weather_tool,
        value: simulated_weather_tool
      }

      result = dispatch_tool_union(simulated_union)

      assert {:weather, %{city: "Paris", units: "celsius"}} = result

      simulated_calc_tool = %BamlClient.CalculatorTool{
        operation: "multiply",
        numbers: [3.0, 7.0]
      }

      simulated_calc_union = %Ash.Union{
        type: :calculator_tool,
        value: simulated_calc_tool
      }

      calc_result = dispatch_tool_union(simulated_calc_union)

      assert {:calculator, 21.0} = calc_result
    end
  end

  describe "error handling patterns" do
    defp classify_tool(tool) do
      case tool do
        %BamlClient.WeatherTool{} = _tool -> :weather
        %BamlClient.CalculatorTool{} = _tool -> :calculator
        _ -> :unknown
      end
    end

    test "handles unknown tool types gracefully" do
      unknown_tool = %{unknown_field: "value"}

      result = classify_tool(unknown_tool)

      assert result == :unknown
    end

    test "validates required arguments in execution actions" do
      assert_raise Ash.Error.Invalid, fn ->
        ToolTestResource
        |> Ash.ActionInput.for_action(:execute_weather, %{city: "Tokyo"})
        |> Ash.run_action!()
      end
    end
  end

  describe "enum constraints validation" do
    test "LLM respects enum constraints in tool selection" do
      {:ok, response} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "What is 100 plus 50 plus 25?"
        })
        |> Ash.run_action()

      assert %AshBaml.Response{} = response
      tool_call = response.data
      assert %Ash.Union{type: :calculator_tool, value: calc_tool} = tool_call

      assert calc_tool.operation in ["add", "subtract", "multiply", "divide"]
      assert calc_tool.operation == "add"

      assert 100.0 in calc_tool.numbers
      assert 50.0 in calc_tool.numbers
      assert 25.0 in calc_tool.numbers
    end

    @tag :skip
    test "LLM correctly maps natural language to enum values" do
      # Test skipped until we have:
      # 1. Mocked LLM responses for deterministic testing
      # 2. More precise prompts that eliminate ambiguity
      #
      # NOTE: This test requires either mocked responses or unambiguous prompts
      # to handle the subtraction ambiguity (100-50 vs 50-100). Current LLM
      # behavior is non-deterministic for this edge case.
    end
  end
end
