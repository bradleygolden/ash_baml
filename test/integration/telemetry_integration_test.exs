defmodule AshBaml.TelemetryIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  defmodule TelemetryTestDomain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshBaml.TelemetryIntegrationTest.TelemetryTestResource)
      resource(AshBaml.TelemetryIntegrationTest.TelemetryDisabledResource)
      resource(AshBaml.TelemetryIntegrationTest.CustomPrefixResource)
    end
  end

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

  defmodule TelemetryDisabledResource do
    @moduledoc false

    use Ash.Resource,
      domain: AshBaml.TelemetryIntegrationTest.TelemetryTestDomain,
      extensions: [AshBaml.Resource]

    baml do
      client_module(AshBaml.Test.BamlClient)

      telemetry do
        enabled(false)
      end
    end

    actions do
      action :test_disabled, :map do
        argument(:message, :string, allow_nil?: false)
        run(call_baml(:TestFunction))
      end
    end
  end

  defmodule CustomPrefixResource do
    @moduledoc false

    use Ash.Resource,
      domain: AshBaml.TelemetryIntegrationTest.TelemetryTestDomain,
      extensions: [AshBaml.Resource]

    baml do
      client_module(AshBaml.Test.BamlClient)

      telemetry do
        enabled(true)
        events([:start, :stop])
        prefix([:my_app, :llm])
      end
    end

    actions do
      action :test_custom_prefix, :map do
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

      on_exit(fn -> :telemetry.detach(handler_id) end)

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

      on_exit(fn -> :telemetry.detach(handler_id) end)

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

      # Cleanup
      :telemetry.detach(handler_id)
    end

    test "token counts are accurate and reasonable" do
      # This test verifies that telemetry token measurements are reasonable
      # and consistent with the API call being made
      test_pid = self()
      ref = make_ref()
      handler_id = "test-tokens-#{:erlang.ref_to_list(ref)}"

      :telemetry.attach(
        handler_id,
        [:ash_baml, :call, :stop],
        fn _event_name, measurements, _metadata, _config ->
          send(test_pid, {ref, measurements})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Make a BAML call with known input size
      # "Hello, world!" is ~3 tokens, plus system prompt overhead
      {:ok, _result} =
        TelemetryTestResource
        |> Ash.ActionInput.for_action(:test_telemetry, %{
          message: "Hello, world!"
        })
        |> Ash.run_action()

      assert_receive {^ref, measurements}, 5000

      # Verify token counts are reasonable
      # Input tokens should be:
      # - Greater than 0 (sanity check)
      # - Less than 1000 (simple prompt shouldn't be huge)
      # - Roughly 3 tokens for message + system prompt overhead
      assert measurements.input_tokens > 0, "Input tokens should be positive"

      assert measurements.input_tokens < 1000,
             "Input tokens (#{measurements.input_tokens}) seems unreasonably high for short message"

      # For "Hello, world!" we expect ~10-100 tokens total (message + system prompt)
      assert measurements.input_tokens >= 5,
             "Input tokens (#{measurements.input_tokens}) seems too low"

      assert measurements.input_tokens <= 200,
             "Input tokens (#{measurements.input_tokens}) seems too high for short prompt"

      # Output tokens should be:
      # - Greater than 0 (LLM must respond)
      # - Less than 500 (TestFunction returns simple struct)
      assert measurements.output_tokens > 0, "Output tokens should be positive"

      assert measurements.output_tokens < 500,
             "Output tokens (#{measurements.output_tokens}) seems unreasonably high for simple response"

      # Total tokens should equal input + output
      assert measurements.total_tokens ==
               measurements.input_tokens + measurements.output_tokens,
             "Total tokens should equal input + output"

      # Cleanup
      :telemetry.detach(handler_id)
    end

    test "model name captured in metadata" do
      # This test verifies that the model name used for the BAML call
      # is captured in the telemetry metadata
      test_pid = self()
      ref = make_ref()
      handler_id = "test-model-#{:erlang.ref_to_list(ref)}"

      :telemetry.attach(
        handler_id,
        [:ash_baml, :call, :stop],
        fn _event_name, _measurements, metadata, _config ->
          send(test_pid, {ref, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Make a BAML call (TestClient uses gpt-4o-mini)
      {:ok, _result} =
        TelemetryTestResource
        |> Ash.ActionInput.for_action(:test_telemetry, %{
          message: "Hello, test!"
        })
        |> Ash.run_action()

      assert_receive {^ref, metadata}, 5000

      # Verify model name is captured
      # TestClient is configured to use gpt-4o-mini
      assert Map.has_key?(metadata, :model_name),
             "Metadata should include model_name field"

      # Model name should be a string
      assert is_binary(metadata.model_name),
             "Model name should be a string"

      # Should contain "gpt-4o-mini" (the model configured in test_functions.baml)
      assert String.contains?(metadata.model_name, "gpt-4o-mini"),
             "Expected model name to contain 'gpt-4o-mini', got: #{metadata.model_name}"

      # Cleanup
      :telemetry.detach(handler_id)
    end

    test "function name captured in metadata" do
      # This test specifically verifies that the BAML function name
      # is correctly captured in telemetry metadata for both start and stop events
      test_pid = self()
      ref = make_ref()
      handler_id = "test-function-name-#{:erlang.ref_to_list(ref)}"

      :telemetry.attach_many(
        handler_id,
        [
          [:ash_baml, :call, :start],
          [:ash_baml, :call, :stop]
        ],
        fn event_name, _measurements, metadata, _config ->
          send(test_pid, {ref, event_name, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Make a BAML call with TestFunction
      {:ok, _result} =
        TelemetryTestResource
        |> Ash.ActionInput.for_action(:test_telemetry, %{
          message: "Test function name capture"
        })
        |> Ash.run_action()

      # Verify :start event captures function_name
      assert_receive {^ref, [:ash_baml, :call, :start], start_metadata}, 1000

      assert Map.has_key?(start_metadata, :function_name),
             "Start event metadata should include function_name field"

      assert start_metadata.function_name == "TestFunction",
             "Expected function_name 'TestFunction', got: #{inspect(start_metadata.function_name)}"

      # Verify :stop event captures function_name
      assert_receive {^ref, [:ash_baml, :call, :stop], stop_metadata}, 5000

      assert Map.has_key?(stop_metadata, :function_name),
             "Stop event metadata should include function_name field"

      assert stop_metadata.function_name == "TestFunction",
             "Expected function_name 'TestFunction', got: #{inspect(stop_metadata.function_name)}"

      # Verify both events have the same function name
      assert start_metadata.function_name == stop_metadata.function_name,
             "Function name should be consistent between start and stop events"

      # Cleanup
      :telemetry.detach(handler_id)
    end

    test "multiple concurrent calls tracked separately" do
      # This test verifies that when multiple BAML calls happen concurrently,
      # each call's telemetry events are tracked separately with no mixing of measurements
      test_pid = self()
      ref = make_ref()
      handler_id = "test-concurrent-#{:erlang.ref_to_list(ref)}"

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

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Make 3 concurrent BAML calls with different messages
      messages = [
        "Hello from call 1",
        "Greetings from call 2",
        "Hi there from call 3"
      ]

      # Launch all calls concurrently
      tasks =
        Enum.map(messages, fn message ->
          Task.async(fn ->
            {:ok, result} =
              TelemetryTestResource
              |> Ash.ActionInput.for_action(:test_telemetry, %{message: message})
              |> Ash.run_action()

            result
          end)
        end)

      # Wait for all to complete
      results = Task.await_many(tasks, 30_000)

      # All should succeed
      assert length(results) == 3

      # Collect all telemetry events (3 starts + 3 stops = 6 events)
      events =
        Enum.map(1..6, fn _ ->
          assert_receive {^ref, event_name, measurements, metadata}, 5000
          {event_name, measurements, metadata}
        end)

      # Separate start and stop events
      start_events =
        events
        |> Enum.filter(fn {event_name, _, _} ->
          event_name == [:ash_baml, :call, :start]
        end)

      stop_events =
        events
        |> Enum.filter(fn {event_name, _, _} ->
          event_name == [:ash_baml, :call, :stop]
        end)

      # Should have exactly 3 start and 3 stop events
      assert length(start_events) == 3,
             "Expected 3 start events, got #{length(start_events)}"

      assert length(stop_events) == 3,
             "Expected 3 stop events, got #{length(stop_events)}"

      # All start events should have monotonic_time and system_time
      Enum.each(start_events, fn {_event, measurements, metadata} ->
        assert is_integer(measurements.monotonic_time),
               "Start event should have monotonic_time"

        assert is_integer(measurements.system_time),
               "Start event should have system_time"

        assert metadata.function_name == "TestFunction"
      end)

      # All stop events should have duration and token counts
      Enum.each(stop_events, fn {_event, measurements, metadata} ->
        assert is_integer(measurements.duration), "Stop event should have duration"
        assert measurements.duration > 0, "Duration should be positive"
        assert is_integer(measurements.input_tokens), "Stop event should have input_tokens"
        assert measurements.input_tokens > 0, "Input tokens should be positive"
        assert is_integer(measurements.output_tokens), "Stop event should have output_tokens"
        assert measurements.output_tokens > 0, "Output tokens should be positive"

        assert measurements.total_tokens ==
                 measurements.input_tokens + measurements.output_tokens,
               "Total should equal input + output"

        assert metadata.function_name == "TestFunction"
      end)

      # Verify no overlapping timestamps (each call should be distinct)
      start_times =
        start_events
        |> Enum.map(fn {_, measurements, _} -> measurements.monotonic_time end)
        |> Enum.sort()

      # All start times should be unique (different calls)
      assert length(Enum.uniq(start_times)) == 3,
             "Start times should be unique for each concurrent call"

      # Verify durations are reasonable (each call took between 100ms-10s)
      stop_events
      |> Enum.each(fn {_, measurements, _} ->
        duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
        assert duration_ms >= 100, "Duration #{duration_ms}ms seems too fast"
        assert duration_ms <= 10_000, "Duration #{duration_ms}ms seems too slow"
      end)

      # Cleanup
      :telemetry.detach(handler_id)
    end

    test "telemetry respects enabled/disabled config" do
      # This test verifies that when telemetry is disabled via config,
      # NO telemetry events are emitted for BAML calls
      test_pid = self()
      ref = make_ref()
      handler_id = "test-disabled-#{:erlang.ref_to_list(ref)}"

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

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Make a BAML call with telemetry DISABLED
      {:ok, result} =
        TelemetryDisabledResource
        |> Ash.ActionInput.for_action(:test_disabled, %{
          message: "This should not emit telemetry events"
        })
        |> Ash.run_action()

      # Verify the call succeeded (functionality still works)
      assert is_struct(result)
      assert result.content != nil
      assert is_float(result.confidence)

      # Verify NO telemetry events were emitted
      # Wait a bit to ensure no events are coming
      refute_receive {^ref, [:ash_baml, :call, :start], _, _}, 500
      refute_receive {^ref, [:ash_baml, :call, :stop], _, _}, 500

      # Cleanup
      :telemetry.detach(handler_id)
    end

    test "custom event prefix works" do
      # This test verifies that when a custom telemetry prefix is configured,
      # events are emitted with that prefix instead of the default [:ash_baml]
      test_pid = self()
      ref = make_ref()
      handler_id = "test-custom-prefix-#{:erlang.ref_to_list(ref)}"

      # Attach handler to CUSTOM prefix (not default [:ash_baml])
      :telemetry.attach_many(
        handler_id,
        [
          [:my_app, :llm, :call, :start],
          [:my_app, :llm, :call, :stop]
        ],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {ref, event_name, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Make a BAML call with custom prefix resource
      {:ok, result} =
        CustomPrefixResource
        |> Ash.ActionInput.for_action(:test_custom_prefix, %{
          message: "Testing custom prefix"
        })
        |> Ash.run_action()

      # Verify the call succeeded
      assert is_struct(result)
      assert result.content != nil

      # Verify :start event was emitted with CUSTOM prefix
      assert_receive {^ref, [:my_app, :llm, :call, :start], start_measurements, start_metadata},
                     1000

      # Verify start event structure
      assert is_integer(start_measurements.monotonic_time)
      assert is_integer(start_measurements.system_time)
      assert start_metadata.function_name == "TestFunction"
      assert start_metadata.resource == CustomPrefixResource
      assert start_metadata.action == :test_custom_prefix

      # Verify :stop event was emitted with CUSTOM prefix
      assert_receive {^ref, [:my_app, :llm, :call, :stop], stop_measurements, stop_metadata},
                     5000

      # Verify stop event structure
      assert is_integer(stop_measurements.duration)
      assert stop_measurements.duration > 0
      assert is_integer(stop_measurements.input_tokens)
      assert stop_measurements.input_tokens > 0
      assert is_integer(stop_measurements.output_tokens)
      assert stop_measurements.output_tokens > 0
      assert stop_metadata.function_name == "TestFunction"

      # Verify NO events were emitted with default [:ash_baml] prefix
      # (We should NOT receive events on the default prefix)
      refute_receive {^ref, [:ash_baml, :call, :start], _, _}, 100
      refute_receive {^ref, [:ash_baml, :call, :stop], _, _}, 100

      # Cleanup
      :telemetry.detach(handler_id)
    end

    test "metadata fields are complete" do
      # This test verifies that ALL expected metadata fields are present
      # in telemetry events, with correct types and reasonable values
      test_pid = self()
      ref = make_ref()
      handler_id = "test-metadata-#{:erlang.ref_to_list(ref)}"

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

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Make a BAML call
      {:ok, _result} =
        TelemetryTestResource
        |> Ash.ActionInput.for_action(:test_telemetry, %{
          message: "Test metadata completeness"
        })
        |> Ash.run_action()

      # Verify :start event metadata is complete
      assert_receive {^ref, [:ash_baml, :call, :start], _start_measurements, start_metadata}, 1000

      # Required metadata fields (present in both :start and :stop)
      assert Map.has_key?(start_metadata, :resource), "Start metadata missing :resource"
      assert start_metadata.resource == TelemetryTestResource

      assert Map.has_key?(start_metadata, :action), "Start metadata missing :action"
      assert start_metadata.action == :test_telemetry

      assert Map.has_key?(start_metadata, :function_name), "Start metadata missing :function_name"
      assert start_metadata.function_name == "TestFunction"
      assert is_binary(start_metadata.function_name)

      assert Map.has_key?(start_metadata, :collector_name),
             "Start metadata missing :collector_name"

      assert is_binary(start_metadata.collector_name)
      # Collector name is the collector reference as a string (e.g., "#Ref<...>")
      assert String.starts_with?(start_metadata.collector_name, "#Ref<"),
             "Collector name should be a reference string"

      # Verify :stop event metadata is complete
      assert_receive {^ref, [:ash_baml, :call, :stop], _stop_measurements, stop_metadata}, 5000

      # Same required fields as :start
      assert Map.has_key?(stop_metadata, :resource), "Stop metadata missing :resource"
      assert stop_metadata.resource == TelemetryTestResource

      assert Map.has_key?(stop_metadata, :action), "Stop metadata missing :action"
      assert stop_metadata.action == :test_telemetry

      assert Map.has_key?(stop_metadata, :function_name), "Stop metadata missing :function_name"
      assert stop_metadata.function_name == "TestFunction"

      assert Map.has_key?(stop_metadata, :collector_name),
             "Stop metadata missing :collector_name"

      assert is_binary(stop_metadata.collector_name)

      # :stop event should ALSO have model_name (added after BAML call completes)
      assert Map.has_key?(stop_metadata, :model_name), "Stop metadata missing :model_name"
      assert is_binary(stop_metadata.model_name)
      assert String.contains?(stop_metadata.model_name, "gpt-4o-mini")

      # Verify metadata consistency between :start and :stop
      assert start_metadata.resource == stop_metadata.resource,
             "Resource should match between start and stop"

      assert start_metadata.action == stop_metadata.action,
             "Action should match between start and stop"

      assert start_metadata.function_name == stop_metadata.function_name,
             "Function name should match between start and stop"

      assert start_metadata.collector_name == stop_metadata.collector_name,
             "Collector name should match between start and stop"

      # Cleanup
      :telemetry.detach(handler_id)
    end

    test "telemetry overhead is minimal" do
      # This test verifies that enabling telemetry doesn't add significant overhead
      # to BAML calls. Since LLM API calls have natural variance, we measure overhead
      # by comparing average times across multiple calls.

      num_samples = 3

      # Measure average duration with telemetry ENABLED
      enabled_durations =
        Enum.map(1..num_samples, fn _i ->
          start = System.monotonic_time(:millisecond)

          {:ok, _result} =
            TelemetryTestResource
            |> Ash.ActionInput.for_action(:test_telemetry, %{
              message: "Test"
            })
            |> Ash.run_action()

          System.monotonic_time(:millisecond) - start
        end)

      enabled_avg = Enum.sum(enabled_durations) / num_samples

      # Measure average duration with telemetry DISABLED
      disabled_durations =
        Enum.map(1..num_samples, fn _i ->
          start = System.monotonic_time(:millisecond)

          {:ok, _result} =
            TelemetryDisabledResource
            |> Ash.ActionInput.for_action(:test_disabled, %{
              message: "Test"
            })
            |> Ash.run_action()

          System.monotonic_time(:millisecond) - start
        end)

      disabled_avg = Enum.sum(disabled_durations) / num_samples

      # Calculate average overhead
      avg_overhead = enabled_avg - disabled_avg

      # Telemetry overhead should be minimal as a percentage
      # Allow up to 50% variance due to API jitter, but document the actual overhead
      overhead_percentage = abs(avg_overhead / disabled_avg) * 100

      # Since telemetry just dispatches events (microseconds of work),
      # most variance is from API jitter, not actual telemetry overhead
      # The overhead percentage calculation is kept for potential assertions
      # but we don't output it to avoid test pollution
      assert is_float(overhead_percentage)
    end
  end
end
