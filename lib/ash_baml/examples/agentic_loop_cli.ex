defmodule AshBaml.Examples.AgenticLoopCLI do
  @moduledoc """
  Example CLI interface for the agentic loop, similar to the Python example.

  This demonstrates how to use the AgenticLoopReactor in a continuous loop,
  processing user input until they type 'exit'.

  ## Running the CLI

  In IEx:

      iex> AshBaml.Examples.AgenticLoopCLI.run()
      Agent started! Type 'exit' to quit.
      You: What's the weather in Tokyo?
      Agent (weather_tool): The weather in Tokyo is sunny with a temperature of 22°C.

      You: Calculate 15 * 3
      Agent (calculator_tool): The result of multiply [15.0, 3.0] is 45.0

      You: exit
      Goodbye!

  ## Programmatic Usage

  You can also call individual iterations programmatically:

      iex> AshBaml.Examples.AgenticLoopCLI.process_message("What's the weather in Paris?")
      {:ok, %{response: "...", tool_used: :weather_tool}}

  ## GenServer Alternative

  For a more production-ready approach, consider using a GenServer to maintain
  conversation state across multiple interactions. See `AshBaml.Examples.AgenticLoopServer`.
  """

  @doc """
  Starts the interactive CLI loop.

  Reads user input from stdin and processes it through the agentic loop reactor
  until the user types 'exit'.
  """
  def run do
    IO.puts("Agent started! Type 'exit' to quit.\n")
    loop()
  end

  defp loop do
    user_input = IO.gets("You: ") |> String.trim()

    case String.downcase(user_input) do
      "exit" ->
        IO.puts("Goodbye!")
        :ok

      "" ->
        loop()

      message ->
        case process_message(message) do
          {:ok, result} ->
            tool_name = format_tool_name(result.tool_used)
            IO.puts("Agent (#{tool_name}): #{result.response}\n")
            loop()

          {:error, error} ->
            IO.puts("Error: #{inspect(error)}\n")
            loop()
        end
    end
  end

  @doc """
  Processes a single message through the agentic loop reactor.

  ## Examples

      iex> process_message("What's the weather in London?")
      {:ok, %{response: "...", tool_used: :weather_tool, ...}}

      iex> process_message("Add 5 and 10")
      {:ok, %{response: "...", tool_used: :calculator_tool, ...}}
  """
  def process_message(message) when is_binary(message) do
    AshBaml.AgenticLoopReactor.run(%{message: message})
  end

  defp format_tool_name(:weather_tool), do: "Weather"
  defp format_tool_name(:calculator_tool), do: "Calculator"
  defp format_tool_name(other), do: to_string(other)
end
