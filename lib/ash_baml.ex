defmodule AshBaml do
  @moduledoc """
  AshBaml provides Ash integration for BAML (Boundary ML) functions.

  ## Usage

  ### Regular BAML Functions

  Add `AshBaml.Resource` as an extension to your Ash resources:

      defmodule MyApp.ChatResource do
        use Ash.Resource,
          domain: MyApp.Domain,
          extensions: [AshBaml.Resource]

        import AshBaml.Helpers

        baml do
          client_module MyApp.BamlClient
        end

        actions do
          action :chat, MyApp.BamlClient.Reply do
            argument :message, :string
            run call_baml(:ChatAgent)
          end
        end
      end

  ### Tool Calling with Union Types

  AshBaml supports BAML tool calling using Ash union types. When a BAML function
  returns a union of tool classes (e.g., `ToolA | ToolB`), the LLM selects which
  tool to use and populates its parameters. BAML parses the response into the
  appropriate struct, and you receive it wrapped in an `Ash.Union`.

  **Key Concept**: Tool calling is about **parameter extraction**, not execution.
  The LLM chooses a tool and fills in the parameters. You decide what to do with it.

  Define your action with a `:union` return type:

      defmodule MyApp.AssistantResource do
        use Ash.Resource,
          domain: MyApp.Domain,
          extensions: [AshBaml.Resource]

        import AshBaml.Helpers

        baml do
          client_module MyApp.BamlClient
        end

        actions do
          # Tool selection action - returns union of tool types
          action :select_tool, :union do
            argument :message, :string

            constraints [
              types: [
                weather_tool: [
                  type: :struct,
                  constraints: [instance_of: MyApp.BamlClient.WeatherTool]
                ],
                calculator_tool: [
                  type: :struct,
                  constraints: [instance_of: MyApp.BamlClient.CalculatorTool]
                ]
              ]
            ]

            run call_baml(:SelectTool)
          end

          # Tool execution actions
          action :execute_weather, :map do
            argument :city, :string
            argument :units, :string
            run fn input, _ctx ->
              # Call weather API
              {:ok, get_weather(input.arguments.city, input.arguments.units)}
            end
          end

          action :execute_calculator, :float do
            argument :operation, :string
            argument :numbers, {:array, :float}
            run fn input, _ctx ->
              # Perform calculation
              {:ok, calculate(input.arguments.operation, input.arguments.numbers)}
            end
          end
        end
      end

  **BAML Tool Definition:**

  In your BAML files, define tool classes as parameter schemas:

      class WeatherTool {
        city string @description("City name")
        units string @description("celsius or fahrenheit")
      }

      class CalculatorTool {
        operation "add" | "subtract" | "multiply" | "divide"
        numbers float[] @description("Numbers to perform operation on")
      }

      function SelectTool(message: string) -> WeatherTool | CalculatorTool {
        client GPT4  // Configure your LLM client
        prompt #"
          Based on the user's message, determine which tool to call.
          Extract the necessary parameters for the selected tool.

          {{ ctx.output_format }}

          User message: {{ message }}
        "#
      }

  **Using Tool Calling:**

      # Step 1: LLM selects tool and populates parameters
      {:ok, tool_call} =
        MyApp.AssistantResource
        |> Ash.ActionInput.for_action(:select_tool, %{message: "Weather in NYC?"})
        |> Ash.run_action()

      # Step 2: You decide what to do with the tool selection
      result = case tool_call do
        %Ash.Union{type: :weather_tool, value: %WeatherTool{city: city, units: units}} ->
          # You control execution - call API, trigger action, whatever you need
          MyApp.AssistantResource
          |> Ash.ActionInput.for_action(:execute_weather, %{city: city, units: units})
          |> Ash.run_action()

        %Ash.Union{type: :calculator_tool, value: %CalculatorTool{operation: op, numbers: nums}} ->
          # Different tool, different handling
          MyApp.AssistantResource
          |> Ash.ActionInput.for_action(:execute_calculator, %{operation: op, numbers: nums})
          |> Ash.run_action()
      end

  ## Prerequisites

  You must:
  1. Write BAML files manually (e.g., in `priv/baml_src/`)
  2. Create a module using `BamlElixir.Client` to generate Elixir code
  3. Reference the generated client in your resource's `baml` block
  """

  @version "0.1.0"

  @doc """
  Returns the current version of the AshBaml library.
  """
  def version, do: @version
end
