# How to Configure Telemetry

Step-by-step guide to setting up telemetry for monitoring ash_baml applications.

## Quick Setup

Add telemetry handlers to your `Application.start/2`:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # Attach telemetry handler
    :telemetry.attach_many(
      "ash-baml-handler",
      [
        [:ash_baml, :call, :start],
        [:ash_baml, :call, :stop],
        [:ash_baml, :call, :exception]
      ],
      &MyApp.Telemetry.handle_event/4,
      nil
    )

    children = [
      # Your other children
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

## Step 1: Create Telemetry Handler Module

```elixir
defmodule MyApp.Telemetry do
  require Logger

  def handle_event([:ash_baml, :call, :start], _measurements, metadata, _config) do
    Logger.info("BAML call started: #{metadata.function_name}")
  end

  def handle_event([:ash_baml, :call, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.info("BAML call completed",
      function: metadata.function_name,
      duration_ms: duration_ms,
      tokens: measurements.total_tokens
    )
  end

  def handle_event([:ash_baml, :call, :exception], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.error("BAML call failed",
      function: metadata.function_name,
      duration_ms: duration_ms,
      error: inspect(metadata.reason)
    )
  end
end
```

## Step 2: Add Metrics (Optional)

Install dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:telemetry_metrics, "~> 1.0"},
    {:telemetry_poller, "~> 1.0"}
  ]
end
```

Create metrics module:

```elixir
defmodule MyApp.Telemetry.Metrics do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: [], period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Duration distribution
      distribution("ash_baml.call.duration",
        event_name: [:ash_baml, :call, :stop],
        measurement: :duration,
        unit: {:native, :millisecond},
        tags: [:function_name, :model]
      ),

      # Token usage sum
      sum("ash_baml.call.tokens",
        event_name: [:ash_baml, :call, :stop],
        measurement: :total_tokens,
        tags: [:function_name, :model]
      ),

      # Call counter
      counter("ash_baml.call.count",
        event_name: [:ash_baml, :call, :stop],
        tags: [:function_name]
      ),

      # Error counter
      counter("ash_baml.call.errors",
        event_name: [:ash_baml, :call, :exception],
        tags: [:function_name, :kind]
      )
    ]
  end
end
```

Add to supervision tree:

```elixir
children = [
  MyApp.Telemetry.Metrics,
  # other children
]
```

## Step 3: Track Costs

```elixir
defmodule MyApp.CostTracker do
  use GenServer
  require Logger

  @costs %{
    "gpt-5" => %{prompt: 0.003, completion: 0.012},
    "gpt-5-mini" => %{prompt: 0.0002, completion: 0.0008}
  }

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{total: 0.0, calls: 0}, name: __MODULE__)
  end

  def init(state) do
    :telemetry.attach(
      "cost-tracker",
      [:ash_baml, :call, :stop],
      &__MODULE__.handle_telemetry/4,
      nil
    )

    {:ok, state}
  end

  def handle_telemetry(_event, measurements, metadata, _config) do
    cost = calculate_cost(
      metadata[:model],
      measurements[:input_tokens],
      measurements[:output_tokens]
    )

    GenServer.cast(__MODULE__, {:add_cost, cost})
  end

  def handle_cast({:add_cost, cost}, state) do
    new_state = %{
      total: state.total + cost,
      calls: state.calls + 1
    }

    Logger.info("Total LLM cost: $#{Float.round(new_state.total, 4)}")

    {:noreply, new_state}
  end

  defp calculate_cost(nil, _, _), do: 0.0

  defp calculate_cost(model, input_tokens, output_tokens) do
    case @costs[model] do
      nil ->
        0.0

      rates ->
        prompt_cost = (input_tokens || 0) / 1000 * rates.prompt
        completion_cost = (output_tokens || 0) / 1000 * rates.completion
        prompt_cost + completion_cost
    end
  end

  # Public API
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state, state}
  end
end
```

Add to supervision tree:

```elixir
children = [
  MyApp.CostTracker,
  # other children
]
```

## Step 4: Phoenix LiveDashboard Integration

Install dependency:

```elixir
{:phoenix_live_dashboard, "~> 0.8"}
```

Add to router:

```elixir
import Phoenix.LiveDashboard.Router

scope "/" do
  live_dashboard "/dashboard",
    metrics: MyApp.Telemetry.Metrics
end
```

## Step 5: Export to External Systems

### Datadog

```elixir
# mix.exs
{:statix, "~> 1.4"}

# config/config.exs
config :statix, MyApp.Statix,
  host: System.get_env("DATADOG_HOST", "localhost"),
  port: 8125

# lib/my_app/telemetry/datadog.ex
defmodule MyApp.Telemetry.Datadog do
  use Statix

  def attach do
    :telemetry.attach(
      "datadog-reporter",
      [:ash_baml, :call, :stop],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event(_event, measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    histogram("baml.call.duration", duration_ms,
      tags: ["function:#{metadata.function_name}", "model:#{metadata.model}"]
    )

    if tokens = measurements.total_tokens do
      histogram("baml.call.tokens", tokens,
        tags: ["function:#{metadata.function_name}"]
      )
    end
  end
end
```

Call in `Application.start/2`:

```elixir
MyApp.Telemetry.Datadog.attach()
```

### Prometheus

```elixir
# mix.exs
{:telemetry_metrics_prometheus, "~> 1.1"}

# lib/my_app/telemetry/prometheus.ex
defmodule MyApp.Telemetry.Prometheus do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {TelemetryMetricsPrometheus, metrics: MyApp.Telemetry.Metrics.metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

Add to supervision tree and configure endpoint in `config.exs`:

```elixir
config :telemetry_metrics_prometheus, port: 9568
```

## Testing Telemetry

```elixir
defmodule MyApp.TelemetryTest do
  use ExUnit.Case

  test "emits telemetry events on BAML call" do
    # Attach test handler
    ref = make_ref()

    :telemetry.attach(
      "test-handler-#{inspect(ref)}",
      [:ash_baml, :call, :stop],
      fn _event, measurements, metadata, _config ->
        send(self(), {:telemetry_event, measurements, metadata})
      end,
      nil
    )

    # Make BAML call
    {:ok, _result} = MyApp.Assistant
      |> Ash.ActionInput.for_action(:say_hello, %{name: "Test"})
      |> Ash.run_action()

    # Assert event received
    assert_receive {:telemetry_event, measurements, metadata}, 1000

    assert is_integer(measurements.duration)
    assert metadata.function_name == "SayHello"

    # Cleanup
    :telemetry.detach("test-handler-#{inspect(ref)}")
  end
end
```

## Next Steps

- [Topic: Telemetry](../topics/telemetry.md) - Complete telemetry reference
- [Topic: Patterns](../topics/patterns.md) - Observability patterns

## Related

- [Topic: Telemetry](../topics/telemetry.md) - Deep dive into telemetry events
