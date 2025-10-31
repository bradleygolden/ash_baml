defmodule AshBaml.Examples.AgenticLoopServer do
  @moduledoc """
  GenServer implementation of an agentic loop with conversation history.

  This server maintains state across multiple tool interactions, allowing for:
  - Conversation history tracking
  - Context-aware tool selection
  - Multi-turn agentic workflows
  - Stateful agent behavior

  ## Usage

  Start the server:

      iex> {:ok, pid} = AshBaml.Examples.AgenticLoopServer.start_link()
      {:ok, #PID<0.123.0>}

  Send messages:

      iex> AshBaml.Examples.AgenticLoopServer.send_message(pid, "What's the weather in Paris?")
      {:ok, %{response: "...", tool_used: :weather_tool, turn: 1}}

      iex> AshBaml.Examples.AgenticLoopServer.send_message(pid, "Calculate 5 + 3")
      {:ok, %{response: "...", tool_used: :calculator_tool, turn: 2}}

  Get conversation history:

      iex> AshBaml.Examples.AgenticLoopServer.get_history(pid)
      [
        %{turn: 1, message: "What's the weather in Paris?", response: "...", tool_used: :weather_tool},
        %{turn: 2, message: "Calculate 5 + 3", response: "...", tool_used: :calculator_tool}
      ]

  Reset the conversation:

      iex> AshBaml.Examples.AgenticLoopServer.reset(pid)
      :ok

  ## Multi-turn Agentic Loop

  For implementing a multi-turn agentic loop where the agent decides when to stop:

      defmodule MyAgenticLoop do
        def run_until_complete(pid, initial_task) do
          # Send initial task
          {:ok, result} = AgenticLoopServer.send_message(pid, initial_task)

          # Check if agent thinks task is complete
          if result.should_continue do
            # Generate next action based on result
            next_action = generate_next_action(result)
            run_until_complete(pid, next_action)
          else
            {:ok, result}
          end
        end
      end
  """
  use GenServer

  @type state :: %{
          history: list(history_entry()),
          turn_count: non_neg_integer()
        }

  @type history_entry :: %{
          turn: non_neg_integer(),
          message: String.t(),
          tool_used: atom(),
          response: String.t(),
          full_result: map(),
          timestamp: DateTime.t()
        }

  # Client API

  @doc """
  Starts the agentic loop server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc """
  Sends a message to the agentic loop and executes the appropriate tool.
  """
  def send_message(pid, message) when is_binary(message) do
    GenServer.call(pid, {:send_message, message}, :timer.seconds(30))
  end

  @doc """
  Retrieves the conversation history.
  """
  def get_history(pid) do
    GenServer.call(pid, :get_history)
  end

  @doc """
  Resets the conversation history.
  """
  def reset(pid) do
    GenServer.call(pid, :reset)
  end

  @doc """
  Gets the current turn count.
  """
  def get_turn_count(pid) do
    GenServer.call(pid, :get_turn_count)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      history: [],
      turn_count: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:send_message, message}, _from, state) do
    case AshBaml.AgenticLoopReactor.run(%{message: message}) do
      {:ok, result} ->
        new_turn = state.turn_count + 1

        history_entry = %{
          turn: new_turn,
          message: message,
          tool_used: result.tool_used,
          response: result.response,
          full_result: result,
          timestamp: DateTime.utc_now()
        }

        new_state = %{
          history: state.history ++ [history_entry],
          turn_count: new_turn
        }

        response = Map.put(result, :turn, new_turn)
        {:reply, {:ok, response}, new_state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, state.history, state}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    new_state = %{
      history: [],
      turn_count: 0
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_turn_count, _from, state) do
    {:reply, state.turn_count, state}
  end
end
