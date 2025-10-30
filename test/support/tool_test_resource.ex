defmodule AshBaml.Test.ToolTestResource do
  @moduledoc false

  use Ash.Resource,
    domain: AshBaml.Test.TestDomain,
    extensions: [AshBaml.Resource]

  import AshBaml.Helpers

  baml do
    client_module(AshBaml.Test.BamlClient)
  end

  actions do
    action :select_tool, :union do
      argument(:message, :string, allow_nil?: false)

      constraints(
        types: [
          weather_tool: [
            type: :struct,
            constraints: [
              instance_of: AshBaml.Test.BamlClient.WeatherTool
            ]
          ],
          calculator_tool: [
            type: :struct,
            constraints: [
              instance_of: AshBaml.Test.BamlClient.CalculatorTool
            ]
          ]
        ]
      )

      run(call_baml(:SelectTool))
    end

    action :execute_weather, :map do
      argument(:city, :string, allow_nil?: false)
      argument(:units, :string, allow_nil?: false)

      run(fn input, _context ->
        {:ok,
         %{
           city: input.arguments.city,
           temperature: 72.0,
           units: input.arguments.units,
           condition: "sunny"
         }}
      end)
    end

    action :execute_calculator, :float do
      argument(:operation, :string, allow_nil?: false)
      argument(:numbers, {:array, :float}, allow_nil?: false)

      run(fn input, _context ->
        result =
          case input.arguments.operation do
            "add" -> Enum.sum(input.arguments.numbers)
            "subtract" -> Enum.reduce(input.arguments.numbers, fn x, acc -> acc - x end)
            "multiply" -> Enum.reduce(input.arguments.numbers, 1, &(&1 * &2))
            "divide" -> Enum.reduce(input.arguments.numbers, fn x, acc -> acc / x end)
          end

        {:ok, result}
      end)
    end
  end
end
