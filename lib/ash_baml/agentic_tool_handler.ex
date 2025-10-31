defmodule AshBaml.AgenticToolHandler do
  @moduledoc """
  Ash resource that handles tool execution in an agentic loop.

  This resource provides:
  - Tool selection via BAML
  - Individual tool execution actions
  - Tool result handling
  """
  use Ash.Resource,
    domain: AshBaml.Test.TestDomain,
    extensions: [AshBaml.Resource]

  baml do
    client_module(AshBaml.Test.BamlClient)
  end

  actions do
    # Main action that selects which tool to use based on user input
    action :select_tool, :union do
      argument :message, :string, allow_nil?: false

      constraints do
        types do
          weather_tool: [
            type: :struct,
            constraints: [instance_of: AshBaml.Test.BamlClient.WeatherTool]
          ]

          calculator_tool: [
            type: :struct,
            constraints: [instance_of: AshBaml.Test.BamlClient.CalculatorTool]
          ]
        end
      end

      run call_baml(:SelectTool)
    end

    # Execute weather tool
    action :execute_weather, :map do
      argument :city, :string, allow_nil?: false
      argument :units, :string, default: "celsius"

      run fn input, _ctx ->
        # Simulate weather API call
        result = %{
          city: input.arguments.city,
          units: input.arguments.units,
          temperature: Enum.random(10..30),
          condition: Enum.random(["sunny", "cloudy", "rainy", "partly cloudy"]),
          timestamp: DateTime.utc_now()
        }

        response = """
        The weather in #{result.city} is #{result.condition} with a temperature of #{result.temperature}°#{String.upcase(String.first(result.units))}.
        """

        {:ok, %{result: result, response: String.trim(response)}}
      end
    end

    # Execute calculator tool
    action :execute_calculator, :map do
      argument :operation, :string, allow_nil?: false
      argument :numbers, {:array, :float}, allow_nil?: false

      run fn input, _ctx ->
        numbers = input.arguments.numbers
        operation = input.arguments.operation

        result =
          case operation do
            "add" ->
              Enum.sum(numbers)

            "subtract" ->
              [first | rest] = numbers
              first - Enum.sum(rest)

            "multiply" ->
              Enum.reduce(numbers, 1, &(&1 * &2))

            "divide" ->
              [first | rest] = numbers
              Enum.reduce(rest, first, &(&2 / &1))

            _ ->
              {:error, "Unknown operation: #{operation}"}
          end

        case result do
          {:error, _} = error ->
            error

          value ->
            response = "The result of #{operation} #{inspect(numbers)} is #{value}"
            {:ok, %{result: value, response: response, operation: operation}}
        end
      end
    end

    # Execute tool based on union type (dispatcher)
    action :execute_tool, :map do
      argument :tool_selection, :union, allow_nil?: false do
        constraints do
          types do
            weather_tool: [
              type: :struct,
              constraints: [instance_of: AshBaml.Test.BamlClient.WeatherTool]
            ]

            calculator_tool: [
              type: :struct,
              constraints: [instance_of: AshBaml.Test.BamlClient.CalculatorTool]
            ]
          end
        end
      end

      run fn input, ctx ->
        tool = input.arguments.tool_selection

        case tool.type do
          :weather_tool ->
            Ash.ActionInput.for_action(
              __MODULE__,
              :execute_weather,
              %{
                city: tool.value.city,
                units: tool.value.units || "celsius"
              }
            )
            |> Ash.run_action()

          :calculator_tool ->
            Ash.ActionInput.for_action(
              __MODULE__,
              :execute_calculator,
              %{
                operation: tool.value.operation,
                numbers: tool.value.numbers
              }
            )
            |> Ash.run_action()

          _ ->
            {:error, "Unknown tool type: #{tool.type}"}
        end
      end
    end
  end
end
