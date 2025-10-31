defmodule AshBaml.ToolCallingIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  alias AshBaml.Test.{BamlClient, ToolTestResource}

  describe "complete tool calling workflow" do
    test "full workflow: select tool -> dispatch -> execute (weather)" do
      {:ok, tool_call} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "What's the weather like in Tokyo?"
        })
        |> Ash.run_action()

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
      {:ok, tool_call} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "Calculate 10 + 20 + 30"
        })
        |> Ash.run_action()

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

    test "ambiguous prompt makes consistent tool choice" do
      # This test verifies that when a prompt could match multiple tools,
      # the LLM makes a deterministic choice and sticks to it.
      # We don't prescribe WHICH tool it should choose, but it should be consistent.
      #
      # Ambiguous message: could be weather (numbers as temperature) or calculator (just numbers)
      ambiguous_message = "What about 72 degrees?"

      # Call it 3 times to verify consistency
      results =
        Enum.map(1..3, fn i ->
          {:ok, tool_call} =
            ToolTestResource
            |> Ash.ActionInput.for_action(:select_tool, %{
              message: ambiguous_message
            })
            |> Ash.run_action()

          IO.puts("Call #{i}: Selected tool type: #{tool_call.type}")
          tool_call
        end)

      # Verify all results are valid unions
      Enum.each(results, fn result ->
        assert %Ash.Union{} = result
        assert result.type in [:weather_tool, :calculator_tool]
      end)

      # Verify consistency: all 3 calls should select the same tool type
      [first | rest] = results

      Enum.each(rest, fn result ->
        assert result.type == first.type,
               "Expected consistent tool selection, but got #{result.type} vs #{first.type}"
      end)

      IO.puts("Ambiguous prompt test: Consistently selected #{first.type} across 3 calls ✓")
    end

    test "tool with all fields populated (weather)" do
      {:ok, tool_call} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "What's the temperature in Seattle in celsius?"
        })
        |> Ash.run_action()

      # Verify it's a union with weather_tool type
      assert %Ash.Union{type: :weather_tool, value: weather_tool} = tool_call

      # Verify ALL fields are populated (not nil, not empty)
      assert weather_tool.city != nil
      assert weather_tool.city != ""
      assert String.contains?(String.downcase(weather_tool.city), "seattle")

      assert weather_tool.units != nil
      assert weather_tool.units != ""
      assert weather_tool.units in ["celsius", "fahrenheit"]
      assert weather_tool.units == "celsius"
    end

    test "tool with all fields populated (calculator)" do
      {:ok, tool_call} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "Multiply 3.5 times 2.0 and 4.0"
        })
        |> Ash.run_action()

      # Verify it's a union with calculator_tool type
      assert %Ash.Union{type: :calculator_tool, value: calc_tool} = tool_call

      # Verify ALL fields are populated (not nil, not empty)
      assert calc_tool.operation != nil
      assert calc_tool.operation in ["add", "subtract", "multiply", "divide"]
      assert calc_tool.operation == "multiply"

      assert calc_tool.numbers != nil
      assert is_list(calc_tool.numbers)
      assert length(calc_tool.numbers) > 0
      # Check all numbers are floats
      Enum.each(calc_tool.numbers, fn num ->
        assert is_float(num)
      end)

      # Should include the numbers from the prompt
      assert 3.5 in calc_tool.numbers
      assert 2.0 in calc_tool.numbers
      assert 4.0 in calc_tool.numbers
    end

    test "3+ tool options in union (timer tool)" do
      {:ok, tool_call} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "Set a timer for 5 minutes called 'tea brewing'"
        })
        |> Ash.run_action()

      # Verify it's a union with timer_tool type
      assert %Ash.Union{type: :timer_tool, value: timer_tool} = tool_call

      # Verify fields are populated
      assert timer_tool.duration_seconds != nil
      assert is_integer(timer_tool.duration_seconds)
      # 5 minutes = 300 seconds
      assert timer_tool.duration_seconds == 300

      assert timer_tool.label != nil
      assert is_binary(timer_tool.label)
      assert String.contains?(String.downcase(timer_tool.label), "tea")
    end

    test "concurrent tool selection calls (cluster-safe)" do
      # This test verifies that multiple parallel tool selection calls work correctly
      # CRITICAL: This tests cluster safety - no shared mutable state or race conditions
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
            {:ok, tool_call} =
              ToolTestResource
              |> Ash.ActionInput.for_action(:select_tool, %{message: message})
              |> Ash.run_action()

            {message, tool_call}
          end,
          timeout: 30_000,
          max_concurrency: 5
        )
        |> Enum.to_list()

      duration = System.monotonic_time(:millisecond) - start_time

      # All tasks should succeed
      Enum.each(results, fn result ->
        assert {:ok, {_message, _tool_call}} = result
      end)

      # Extract the tool calls
      tool_calls =
        Enum.map(results, fn {:ok, {message, tool_call}} ->
          {message, tool_call}
        end)

      # Verify each tool call is a valid union
      Enum.each(tool_calls, fn {_message, tool_call} ->
        assert %Ash.Union{} = tool_call
        assert tool_call.type in [:weather_tool, :calculator_tool]
      end)

      # Verify correct tool selection based on message content
      weather_calls =
        Enum.filter(tool_calls, fn {msg, _} ->
          String.contains?(msg, "weather") or String.contains?(msg, "Temperature") or
            String.contains?(msg, "forecast")
        end)

      calc_calls =
        Enum.filter(tool_calls, fn {msg, _} ->
          String.contains?(msg, "Calculate") or String.contains?(msg, "Divide")
        end)

      # Should have 3 weather and 2 calculator calls
      assert length(weather_calls) == 3
      assert length(calc_calls) == 2

      # Verify weather calls selected weather_tool
      Enum.each(weather_calls, fn {_msg, tool_call} ->
        assert tool_call.type == :weather_tool
      end)

      # Verify calculator calls selected calculator_tool
      Enum.each(calc_calls, fn {_msg, tool_call} ->
        assert tool_call.type == :calculator_tool
      end)

      IO.puts("Concurrent tool selection: #{length(results)} calls completed in #{duration}ms ✓")
      IO.puts("Average time per call: #{div(duration, length(results))}ms")
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
      # This test documents the complete tool calling pattern without requiring LLM calls
      # Real usage would follow this same pattern but with actual LLM responses

      # In real usage, this would come from SelectTool BAML function
      simulated_weather_tool = %BamlClient.WeatherTool{
        city: "Paris",
        units: "celsius"
      }

      # Wrap in Ash.Union as BAML would do
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

      # Attempting to use it would not match the case patterns
      # This demonstrates that developers control the dispatch
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
      # Test that the LLM correctly selects one of the allowed enum values
      # for the calculator operation field: "add" | "subtract" | "multiply" | "divide"
      {:ok, tool_call} =
        ToolTestResource
        |> Ash.ActionInput.for_action(:select_tool, %{
          message: "What is 100 plus 50 plus 25?"
        })
        |> Ash.run_action()

      # Verify it's a calculator tool
      assert %Ash.Union{type: :calculator_tool, value: calc_tool} = tool_call

      # Verify the operation is one of the allowed enum values
      assert calc_tool.operation in ["add", "subtract", "multiply", "divide"]

      # For this specific prompt, should be "add"
      assert calc_tool.operation == "add"

      # Verify numbers are extracted correctly
      assert 100.0 in calc_tool.numbers
      assert 50.0 in calc_tool.numbers
      assert 25.0 in calc_tool.numbers
    end

    test "LLM correctly maps natural language to enum values" do
      # Test various natural language expressions and verify they map to correct enum values
      test_cases = [
        {"Subtract 50 from 100", "subtract"},
        {"Multiply 5 by 3 by 2", "multiply"},
        {"Divide 100 by 4", "divide"},
        {"Add 1 and 2 and 3", "add"}
      ]

      Enum.each(test_cases, fn {message, expected_operation} ->
        {:ok, tool_call} =
          ToolTestResource
          |> Ash.ActionInput.for_action(:select_tool, %{message: message})
          |> Ash.run_action()

        assert %Ash.Union{type: :calculator_tool, value: calc_tool} = tool_call

        assert calc_tool.operation == expected_operation,
               "Expected #{expected_operation} for '#{message}', got #{calc_tool.operation}"

        # Verify it's one of the allowed values
        assert calc_tool.operation in ["add", "subtract", "multiply", "divide"]
      end)
    end
  end
end
