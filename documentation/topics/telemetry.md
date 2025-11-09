# Telemetry

Complete guide to monitoring, observability, and telemetry in ash_baml applications.

## Overview

ash_baml emits telemetry events for all BAML function calls, giving you insight into:

- **Performance**: Duration, latency, throughput
- **Costs**: Token usage and API costs
- **Errors**: Failures, timeouts, rate limits
- **Usage**: Which functions are called, how often

All events follow Telemetry conventions and integrate with popular observability tools.

## Telemetry Events

### Function Call Events

Every BAML function call emits three events:

#### `[:ash_baml, :call, :start]`

Emitted when a BAML function call starts.

**Measurements:**
```elixir
%{
  system_time: integer()  # Monotonic time when call started
}
```

**Metadata:**
```elixir
%{
  resource: module(),                    # Ash resource (e.g., MyApp.Assistant)
  action: atom(),                        # Action name (e.g., :say_hello)
  function_name: String.t(),             # BAML function (e.g., "SayHello")
  collector_name: String.t()             # Collector reference identifier
  # Optional fields (configured via `metadata` DSL option):
  # llm_client: any()                    # LLM client used (opt-in)
  # stream: boolean()                    # true if streaming call (opt-in)
}
```

#### `[:ash_baml, :call, :stop]`

Emitted when a BAML function call completes successfully.

**Measurements:**
```elixir
%{
  duration: integer(),                   # Duration in native time units
  total_tokens: integer() | nil,         # Total tokens (input + output)
  input_tokens: integer() | nil,         # Tokens in input/prompt
  output_tokens: integer() | nil         # Tokens in output/completion
}
```

**Metadata:**
```elixir
%{
  resource: module(),
  action: atom(),
  function_name: String.t(),
  collector_name: String.t()
  # Optional fields (configured via `metadata` DSL option):
  # llm_client: any()                    # LLM client used (opt-in)
  # stream: boolean()                    # true if streaming call (opt-in)
}
```

#### `[:ash_baml, :call, :exception]`

Emitted when a BAML function call fails.

**Measurements:**
```elixir
%{
  duration: integer()  # Duration until failure
}
```

**Metadata:**
```elixir
%{
  resource: module(),
  action: atom(),
  function_name: String.t(),
  collector_name: String.t(),
  kind: :error | :exit | :throw,
  reason: any(),                         # Error reason
  stacktrace: list()
  # Optional fields (configured via `metadata` DSL option):
  # llm_client: any()                    # LLM client used (opt-in)
  # stream: boolean()                    # true if streaming call (opt-in)
}
```

## Response Usage Tracking

In addition to telemetry events, BAML function calls return an `AshBaml.Response` struct that includes usage metadata alongside the result data. This enables programmatic access to token usage without attaching telemetry handlers.

### Response Structure

Every successful BAML function call returns:

```elixir
{:ok, %AshBaml.Response{
  data: term(),           # Your BAML function result
  usage: %{               # Token usage metadata
    input_tokens: 10,
    output_tokens: 5,
    total_tokens: 15
  },
  collector: reference()  # Internal collector reference
}}
```

### Accessing Usage Data

Extract usage information from responses:

```elixir
{:ok, response} = MyApp.Assistant
  |> Ash.ActionInput.for_action(:say_hello, %{name: "Alice"})
  |> Ash.run_action()

# Access the result data
result = response.data
# or
result = AshBaml.Response.unwrap(response)

# Access token usage
usage = response.usage
# => %{input_tokens: 10, output_tokens: 5, total_tokens: 15}

# Or use the helper
usage = AshBaml.Response.usage(response)
```

### Integration with Application Logic

The Response wrapper enables programmatic integration with your application logic:

```elixir
defmodule MyApp.LLMService do
  def call_with_budget(action_input, max_tokens) do
    {:ok, response} = action_input |> Ash.run_action()

    # Check token usage against budget
    if response.usage.total_tokens > max_tokens do
      {:error, :budget_exceeded, response.usage}
    else
      {:ok, response.data, response.usage}
    end
  end

  def track_cost(response) do
    # Calculate cost based on usage
    cost = calculate_cost(response.usage)
    MyApp.CostTracker.record(cost)
    response
  end
end
```

This enables cost tracking, rate limiting, and usage analytics at the application level without relying solely on telemetry events.

### Usage vs Telemetry

**Response usage** is best for:
- Immediate cost calculations in-request
- Conditional logic based on token usage
- Returning usage info to API clients
- Single-call usage inspection

**Telemetry events** are best for:
- Aggregated metrics across many calls
- Long-term monitoring and alerting
- Integration with APM tools (Datadog, Honeycomb, etc.)
- Tracking failures and exceptions

Use both together for comprehensive observability:

```elixir
def expensive_operation(input) do
  # Make BAML call
  {:ok, response} = MyApp.Assistant
    |> Ash.ActionInput.for_action(:analyze, input)
    |> Ash.run_action()

  # Check usage immediately
  if response.usage.total_tokens > 10_000 do
    Logger.warning("High token usage: #{response.usage.total_tokens} tokens")
  end

  # Return both result and usage
  {:ok, response.data, response.usage}
end
```

## Metadata Configuration

By default, telemetry events include only **safe metadata fields**:
- `resource` - The Ash resource module
- `action` - The action name
- `function_name` - The BAML function name
- `collector_name` - The collector reference identifier

**Optional metadata fields** can be enabled per-resource using the `metadata` DSL option:

```elixir
defmodule MyApp.Assistant do
  use Ash.Resource, extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:SayHello]

    telemetry do
      enabled true
      # Enable optional metadata fields
      metadata [:llm_client, :stream]
    end
  end
end
```

**Available optional fields:**
- `:llm_client` - The LLM client used for the call
- `:stream` - Whether this was a streaming call (boolean)

These fields are opt-in for privacy and performance reasons. Only include metadata you need for your observability use case.

## Attaching Handlers

### Basic Handler

Log all BAML calls:

```elixir
# application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # Attach telemetry handler
    :telemetry.attach_many(
      "baml-logger",
      [
        [:ash_baml, :call, :start],
        [:ash_baml, :call, :stop],
        [:ash_baml, :call, :exception]
      ],
      &MyApp.TelemetryHandler.handle_event/4,
      nil
    )

    # Start your app...
  end
end

# lib/my_app/telemetry_handler.ex
defmodule MyApp.TelemetryHandler do
  require Logger

  def handle_event([:ash_baml, :call, :start], measurements, metadata, _config) do
    Logger.info("BAML call started: #{metadata.function_name}")
  end

  def handle_event([:ash_baml, :call, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.info("BAML call completed", [
      function: metadata.function_name,
      duration_ms: duration_ms,
      tokens: measurements.total_tokens
    ])
  end

  def handle_event([:ash_baml, :call, :exception], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.error("BAML call failed", [
      function: metadata.function_name,
      duration_ms: duration_ms,
      error: inspect(metadata.reason)
    ])
  end
end
```

### Metrics Handler

Track metrics with Telemetry.Metrics:

```elixir
# lib/my_app/telemetry.ex
defmodule MyApp.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      {TelemetryMetricsPrometheus, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Function call duration
      distribution(
        "ash_baml.call.duration",
        event_name: [:ash_baml, :call, :stop],
        measurement: :duration,
        unit: {:native, :millisecond},
        tags: [:function_name, :model, :resource],
        tag_values: &tag_values/1
      ),

      # Token usage
      sum(
        "ash_baml.call.tokens.total",
        event_name: [:ash_baml, :call, :stop],
        measurement: :total_tokens,
        tags: [:function_name, :model]
      ),

      # Call count
      counter(
        "ash_baml.call.count",
        event_name: [:ash_baml, :call, :stop],
        tags: [:function_name, :model, :resource]
      ),

      # Error count
      counter(
        "ash_baml.call.errors",
        event_name: [:ash_baml, :call, :exception],
        tags: [:function_name, :kind]
      )
    ]
  end

  defp tag_values(metadata) do
    Map.take(metadata, [:function_name, :model, :resource])
  end

  defp periodic_measurements do
    []
  end
end
```

Add to your application supervision tree:

```elixir
# application.ex
children = [
  MyApp.Telemetry,
  # ... other children
]
```

## Cost Tracking

Track LLM API costs:

```elixir
defmodule MyApp.CostTracker do
  use GenServer

  # Cost per 1K tokens (example prices)
  @costs %{
    "gpt-5" => %{prompt: 0.003, completion: 0.012},
    "gpt-5-mini" => %{prompt: 0.0002, completion: 0.0008}
  }

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    :telemetry.attach(
      "cost-tracker",
      [:ash_baml, :call, :stop],
      &__MODULE__.handle_event/4,
      nil
    )

    {:ok, %{total_cost: 0.0, calls: 0}}
  end

  def handle_event([:ash_baml, :call, :stop], measurements, metadata, _) do
    cost = calculate_cost(
      metadata.model,
      measurements.input_tokens,
      measurements.output_tokens
    )

    GenServer.cast(__MODULE__, {:track_cost, cost})
  end

  def handle_cast({:track_cost, cost}, state) do
    new_state = %{
      total_cost: state.total_cost + cost,
      calls: state.calls + 1
    }

    Logger.info("Current LLM costs: $#{Float.round(new_state.total_cost, 2)} over #{new_state.calls} calls")

    {:noreply, new_state}
  end

  defp calculate_cost(model, input_tokens, output_tokens) do
    case @costs[model] do
      nil ->
        0.0

      costs ->
        prompt_cost = (input_tokens || 0) / 1000 * costs.prompt
        completion_cost = (output_tokens || 0) / 1000 * costs.completion
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

## Performance Monitoring

### Tracking Slow Calls

Alert on slow BAML calls:

```elixir
defmodule MyApp.SlowCallTracker do
  require Logger

  @slow_threshold_ms 2000

  def attach do
    :telemetry.attach(
      "slow-call-tracker",
      [:ash_baml, :call, :stop],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:ash_baml, :call, :stop], measurements, metadata, _) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    if duration_ms > @slow_threshold_ms do
      Logger.warning("Slow BAML call detected", [
        function: metadata.function_name,
        duration_ms: duration_ms,
        threshold_ms: @slow_threshold_ms,
        resource: metadata.resource,
        action: metadata.action
      ])
    end
  end
end
```

### Percentile Tracking

Track p50, p95, p99 latencies:

```elixir
defmodule MyApp.LatencyTracker do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    :telemetry.attach(
      "latency-tracker",
      [:ash_baml, :call, :stop],
      &__MODULE__.handle_event/4,
      nil
    )

    # Store last 1000 durations per function
    {:ok, %{}}
  end

  def handle_event([:ash_baml, :call, :stop], measurements, metadata, _) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    GenServer.cast(__MODULE__, {:record, metadata.function_name, duration_ms})
  end

  def handle_cast({:record, function, duration}, state) do
    durations = Map.get(state, function, [])
    updated_durations = Enum.take([duration | durations], 1000)

    {:noreply, Map.put(state, function, updated_durations)}
  end

  # Calculate percentiles
  def get_percentiles(function) do
    GenServer.call(__MODULE__, {:percentiles, function})
  end

  def handle_call({:percentiles, function}, _from, state) do
    durations = Map.get(state, function, [])

    if Enum.empty?(durations) do
      {:reply, nil, state}
    else
      sorted = Enum.sort(durations)
      count = length(sorted)

      percentiles = %{
        p50: Enum.at(sorted, round(count * 0.50)),
        p95: Enum.at(sorted, round(count * 0.95)),
        p99: Enum.at(sorted, round(count * 0.99)),
        max: Enum.max(sorted),
        count: count
      }

      {:reply, percentiles, state}
    end
  end
end
```

## Integration with Observability Tools

### Phoenix LiveDashboard

Display BAML metrics in LiveDashboard:

```elixir
# lib/my_app_web/router.ex
import Phoenix.LiveDashboard.Router

scope "/" do
  pipe_through :browser

  live_dashboard "/dashboard",
    metrics: MyApp.Telemetry,
    additional_pages: [
      baml_metrics: {MyAppWeb.BamlMetricsLive, []}
    ]
end
```

### Datadog

Send metrics to Datadog:

```elixir
defmodule MyApp.DatadogReporter do
  require Logger

  def attach do
    :telemetry.attach_many(
      "datadog-reporter",
      [
        [:ash_baml, :call, :stop],
        [:ash_baml, :call, :exception]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:ash_baml, :call, :stop], measurements, metadata, _) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    # Send to Datadog
    Statix.histogram("baml.call.duration", duration_ms, [
      tags: [
        "function:#{metadata.function_name}",
        "resource:#{inspect(metadata.resource)}"
      ]
    ])

    if tokens = measurements.total_tokens do
      Statix.histogram("baml.call.tokens", tokens, [
        tags: ["function:#{metadata.function_name}"]
      ])
    end
  end

  def handle_event([:ash_baml, :call, :exception], _measurements, metadata, _) do
    Statix.increment("baml.call.errors", 1, [
      tags: [
        "function:#{metadata.function_name}",
        "kind:#{metadata.kind}"
      ]
    ])
  end
end
```

### Honeycomb

Send traces to Honeycomb:

```elixir
defmodule MyApp.HoneycombReporter do
  def attach do
    :telemetry.attach_many(
      "honeycomb-reporter",
      [
        [:ash_baml, :call, :start],
        [:ash_baml, :call, :stop],
        [:ash_baml, :call, :exception]
      ],
      &__MODULE__.handle_event/4,
      %{api_key: System.get_env("HONEYCOMB_API_KEY")}
    )
  end

  def handle_event([:ash_baml, :call, :start], _measurements, metadata, config) do
    span_id = generate_span_id()
    trace_id = Process.get(:honeycomb_trace_id, generate_trace_id())
    Process.put(:honeycomb_trace_id, trace_id)
    Process.put(:honeycomb_span_id, span_id)

    # Start span in Honeycomb
    # Note: metadata.stream is only available if configured via `metadata: [:stream]`
    Honeycomb.start_span(trace_id, span_id, %{
      name: "baml.#{metadata.function_name}",
      "baml.function": metadata.function_name,
      "baml.resource": inspect(metadata.resource),
      "baml.stream": Map.get(metadata, :stream, false)
    }, config.api_key)
  end

  def handle_event([:ash_baml, :call, :stop], measurements, metadata, config) do
    span_id = Process.get(:honeycomb_span_id)
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    # Finish span
    Honeycomb.finish_span(span_id, %{
      "duration_ms": duration_ms,
      "baml.tokens.total": measurements.total_tokens,
      "baml.tokens.prompt": measurements.input_tokens,
      "baml.tokens.completion": measurements.output_tokens,
      "baml.model": metadata.model
    }, config.api_key)
  end

  defp generate_span_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  defp generate_trace_id, do: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
end
```

## Custom Telemetry Events

Add your own telemetry events in custom actions:

```elixir
defmodule MyApp.CustomAction do
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    # Emit custom event
    :telemetry.execute(
      [:my_app, :custom_processing, :start],
      %{system_time: System.system_time()},
      %{input: input}
    )

    start_time = System.monotonic_time()

    result = case do_processing(input) do
      {:ok, result} ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:my_app, :custom_processing, :stop],
          %{duration: duration},
          %{result: result}
        )

        {:ok, result}

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:my_app, :custom_processing, :exception],
          %{duration: duration},
          %{reason: reason}
        )

        {:error, reason}
    end

    result
  end
end
```

## Testing with Telemetry

Verify telemetry events in tests:

```elixir
defmodule MyApp.TelemetryTest do
  use ExUnit.Case

  test "BAML call emits telemetry events" do
    # Attach test handler
    ref = :telemetry_test.attach_event_handlers(self(), [
      [:ash_baml, :call, :start],
      [:ash_baml, :call, :stop]
    ])

    # Make BAML call
    {:ok, _result} = MyApp.Assistant
      |> Ash.ActionInput.for_action(:say_hello, %{name: "Test"})
      |> Ash.run_action()

    # Assert events were emitted
    assert_received {[:ash_baml, :call, :start], ^ref, %{}, %{function_name: "SayHello"}}
    assert_received {[:ash_baml, :call, :stop], ^ref, %{duration: _}, %{function_name: "SayHello"}}
  end
end
```

## Best Practices

1. **Attach handlers in Application.start/2**: Ensure handlers are active before any BAML calls
2. **Use tags for filtering**: Tag metrics with `function_name`, `model`, `resource` for filtering
3. **Sample high-volume events**: For high-traffic apps, sample telemetry events
4. **Monitor both duration and tokens**: Track latency and cost separately
5. **Alert on errors**: Set up alerts for exception events
6. **Track percentiles**: p95/p99 latencies reveal tail performance
7. **Include business context**: Add custom metadata relevant to your domain

## Next Steps

- **How-to**: [Configure Telemetry](../how-to/configure-telemetry.md) - Step-by-step telemetry setup
- **Topic**: [Patterns](patterns.md) - Observability patterns
- **External**: [Telemetry Guide](https://hexdocs.pm/telemetry/readme.html) - Complete Telemetry documentation

## Reference

- Module: `AshBaml.Telemetry` - Telemetry event definitions
- Library: [:telemetry](https://hexdocs.pm/telemetry) - Telemetry library
- Library: [telemetry_metrics](https://hexdocs.pm/telemetry_metrics) - Metrics aggregation
