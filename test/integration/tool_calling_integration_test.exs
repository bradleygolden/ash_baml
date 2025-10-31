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
end
