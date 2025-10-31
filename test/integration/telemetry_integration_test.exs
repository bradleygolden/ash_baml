defmodule AshBaml.TelemetryIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  # Define a test domain for telemetry tests
  defmodule TelemetryTestDomain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshBaml.TelemetryIntegrationTest.TelemetryTestResource)
    end
  end

  # Define a test resource with telemetry enabled
  defmodule TelemetryTestResource do
    @moduledoc false

    use Ash.Resource,
      domain: AshBaml.TelemetryIntegrationTest.TelemetryTestDomain,
      extensions: [AshBaml.Resource]

    baml do
      client_module(AshBaml.Test.BamlClient)

      telemetry do
        enabled(true)
        events([:start, :stop, :exception])
        prefix([:ash_baml])
      end
    end

    actions do
      action :test_telemetry, :map do
        argument(:message, :string, allow_nil?: false)
        run(call_baml(:TestFunction))
      end
    end
  end

  describe "telemetry events" do
    test "start and stop events emitted with real API call" do
      # Attach telemetry handler to capture events
      test_pid = self()
      ref = make_ref()
      handler_id = "test-telemetry-#{:erlang.ref_to_list(ref)}"

      :telemetry.attach_many(
        handler_id,
        [
          [:ash_baml, :call, :start],
          [:ash_baml, :call, :stop]
        ],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {ref, event_name, measurements, metadata})
        end,
        nil
      )

      # Make BAML call
      {:ok, _result} =
        TelemetryTestResource
        |> Ash.ActionInput.for_action(:test_telemetry, %{
          message: "Hello, world!"
        })
        |> Ash.run_action()

      # Verify :start event was emitted
      assert_receive {^ref, [:ash_baml, :call, :start], start_measurements, start_metadata}, 1000

      # :start event should have monotonic_time and system_time
      assert is_integer(start_measurements.monotonic_time)
      assert is_integer(start_measurements.system_time)

      # :start event metadata should include resource, action, and function_name
      assert start_metadata.resource == TelemetryTestResource
      assert start_metadata.action == :test_telemetry
      assert start_metadata.function_name == "TestFunction"

      # Verify :stop event was emitted
      assert_receive {^ref, [:ash_baml, :call, :stop], stop_measurements, stop_metadata}, 5000

      # :stop event should have duration and token counts
      assert is_integer(stop_measurements.duration)
      assert stop_measurements.duration > 0

      assert is_integer(stop_measurements.input_tokens)
      assert stop_measurements.input_tokens > 0

      assert is_integer(stop_measurements.output_tokens)
      assert stop_measurements.output_tokens > 0

      assert is_integer(stop_measurements.total_tokens)

      assert stop_measurements.total_tokens ==
               stop_measurements.input_tokens + stop_measurements.output_tokens

      # :stop event metadata should match :start event
      assert stop_metadata.resource == TelemetryTestResource
      assert stop_metadata.action == :test_telemetry
      assert stop_metadata.function_name == "TestFunction"

      # Cleanup
      :telemetry.detach(handler_id)
    end

    test "duration timing is reasonable and accurate" do
      # This test verifies that the telemetry duration measurement accurately reflects
      # the actual time taken for the BAML API call
      test_pid = self()
      ref = make_ref()
      handler_id = "test-duration-#{:erlang.ref_to_list(ref)}"

      :telemetry.attach(
        handler_id,
        [:ash_baml, :call, :stop],
        fn _event_name, measurements, _metadata, _config ->
          send(test_pid, {ref, measurements})
        end,
        nil
      )

      # Measure wall clock time around the BAML call
      wall_start = System.monotonic_time(:millisecond)

      {:ok, _result} =
        TelemetryTestResource
        |> Ash.ActionInput.for_action(:test_telemetry, %{
          message: "What is the capital of France?"
        })
        |> Ash.run_action()

      wall_duration = System.monotonic_time(:millisecond) - wall_start

      # Receive telemetry duration (in native units, need to convert)
      assert_receive {^ref, measurements}, 5000

      telemetry_duration_ms =
        System.convert_time_unit(measurements.duration, :native, :millisecond)

      # Telemetry duration should be:
      # 1. Greater than 0 (sanity check)
      # 2. Less than wall clock duration (since it measures just the BAML call)
      # 3. Reasonably close to wall clock duration (within 500ms overhead allowance)
      assert telemetry_duration_ms > 0, "Telemetry duration should be positive"

      assert telemetry_duration_ms <= wall_duration,
             "Telemetry duration (#{telemetry_duration_ms}ms) should not exceed wall duration (#{wall_duration}ms)"

      # Allow up to 500ms overhead for Ash framework, telemetry dispatch, etc.
      overhead = wall_duration - telemetry_duration_ms

      assert overhead < 500,
             "Overhead (#{overhead}ms) between wall clock (#{wall_duration}ms) and telemetry (#{telemetry_duration_ms}ms) should be < 500ms"

      # Typical LLM API calls take 200ms-5000ms, verify we're in reasonable range
      assert telemetry_duration_ms >= 100,
             "API call duration (#{telemetry_duration_ms}ms) seems too fast"

      assert telemetry_duration_ms <= 10_000,
             "API call duration (#{telemetry_duration_ms}ms) seems too slow"

      IO.puts(
        "Duration timing: Wall=#{wall_duration}ms, Telemetry=#{telemetry_duration_ms}ms, Overhead=#{overhead}ms ✓"
      )

      # Cleanup
      :telemetry.detach(handler_id)
    end
  end
end
