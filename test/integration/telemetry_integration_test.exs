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
  end
end
