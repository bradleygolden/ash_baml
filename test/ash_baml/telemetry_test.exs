defmodule AshBaml.TelemetryTest do
  use ExUnit.Case, async: false

  alias AshBaml.Telemetry

  describe "with_telemetry/4" do
    setup do
      handler_id = "test-handler-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:ash_baml, :call, :start],
        &__MODULE__.handle_event/4,
        %{test_pid: self()}
      )

      :telemetry.attach(
        "#{handler_id}-stop",
        [:ash_baml, :call, :stop],
        &__MODULE__.handle_event/4,
        %{test_pid: self()}
      )

      :telemetry.attach(
        "#{handler_id}-exception",
        [:ash_baml, :call, :exception],
        &__MODULE__.handle_event/4,
        %{test_pid: self()}
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
        :telemetry.detach("#{handler_id}-stop")
        :telemetry.detach("#{handler_id}-exception")
      end)

      :ok
    end

    test "emits start and stop events when enabled" do
      input = build_input()
      config = [enabled: true, events: [:start, :stop, :exception]]

      result =
        Telemetry.with_telemetry(input, :TestFunction, config, fn _collector_opts ->
          {:ok, :test_result}
        end)

      assert result == {:ok, :test_result}

      assert_receive {:telemetry_event, [:ash_baml, :call, :start], measurements, metadata}
      assert Map.has_key?(measurements, :monotonic_time)
      assert Map.has_key?(measurements, :system_time)
      assert metadata.function_name == "TestFunction"

      assert_receive {:telemetry_event, [:ash_baml, :call, :stop], measurements, metadata}
      assert Map.has_key?(measurements, :duration)
      assert Map.has_key?(measurements, :input_tokens)
      assert Map.has_key?(measurements, :output_tokens)
      assert Map.has_key?(measurements, :total_tokens)
      assert metadata.function_name == "TestFunction"
    end

    test "does not emit events when disabled" do
      input = build_input()
      config = [enabled: false, events: [:start, :stop, :exception]]

      result =
        Telemetry.with_telemetry(input, :TestFunction, config, fn _collector_opts ->
          {:ok, :test_result}
        end)

      assert result == {:ok, :test_result}

      refute_receive {:telemetry_event, _, _, _}, 100
    end

    test "emits exception event on error" do
      input = build_input()
      config = [enabled: true, events: [:start, :stop, :exception]]

      assert_raise RuntimeError, "test error", fn ->
        Telemetry.with_telemetry(input, :TestFunction, config, fn _collector_opts ->
          raise "test error"
        end)
      end

      assert_receive {:telemetry_event, [:ash_baml, :call, :start], _, _}

      assert_receive {:telemetry_event, [:ash_baml, :call, :exception], measurements, metadata}
      assert Map.has_key?(measurements, :duration)
      assert metadata.kind == :error
      assert metadata.reason == "test error"
      assert is_list(metadata.stacktrace)
    end

    test "respects custom event prefix" do
      handler_id = "custom-prefix-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:my_app, :ai, :call, :start],
        &__MODULE__.handle_event/4,
        %{test_pid: self()}
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      input = build_input()
      config = [enabled: true, prefix: [:my_app, :ai], events: [:start]]

      Telemetry.with_telemetry(input, :TestFunction, config, fn _collector_opts ->
        {:ok, :result}
      end)

      assert_receive {:telemetry_event, [:my_app, :ai, :call, :start], _, _}
    end

    test "respects event filtering" do
      input = build_input()
      config = [enabled: true, events: [:stop]]

      Telemetry.with_telemetry(input, :TestFunction, config, fn _collector_opts ->
        {:ok, :result}
      end)

      refute_receive {:telemetry_event, [:ash_baml, :call, :start], _, _}, 100
      assert_receive {:telemetry_event, [:ash_baml, :call, :stop], _, _}
    end

    test "includes metadata fields" do
      input = build_input()
      config = [enabled: true, events: [:start], metadata: [:llm_client, :stream]]

      Telemetry.with_telemetry(input, :TestFunction, config, fn _collector_opts ->
        {:ok, :result}
      end)

      assert_receive {:telemetry_event, [:ash_baml, :call, :start], _measurements, metadata}
      assert Map.has_key?(metadata, :resource)
      assert Map.has_key?(metadata, :action)
      assert Map.has_key?(metadata, :function_name)
    end

    test "respects sampling rate" do
      input = build_input()

      config = [enabled: true, sample_rate: 0.0, events: [:start]]

      for _ <- 1..10 do
        Telemetry.with_telemetry(input, :TestFunction, config, fn _collector_opts ->
          {:ok, :result}
        end)
      end

      refute_receive {:telemetry_event, _, _, _}, 100
    end

    test "always samples at 100%" do
      input = build_input()
      config = [enabled: true, sample_rate: 1.0, events: [:start]]

      for _ <- 1..5 do
        Telemetry.with_telemetry(input, :TestFunction, config, fn _collector_opts ->
          {:ok, :result}
        end)
      end

      for _ <- 1..5 do
        assert_receive {:telemetry_event, [:ash_baml, :call, :start], _, _}
      end
    end

    test "passes collector to function" do
      input = build_input()
      config = [enabled: true, events: [:stop]]

      Telemetry.with_telemetry(input, :TestFunction, config, fn collector_opts ->
        assert Keyword.has_key?(collector_opts, :collectors)
        collectors = Keyword.get(collector_opts, :collectors)
        assert is_list(collectors)
        assert length(collectors) == 1
        [collector] = collectors
        assert is_struct(collector, BamlElixir.Collector)
        {:ok, :result}
      end)

      assert_receive {:telemetry_event, [:ash_baml, :call, :stop], measurements, _}
      assert Map.has_key?(measurements, :input_tokens)
      assert Map.has_key?(measurements, :output_tokens)
      assert Map.has_key?(measurements, :total_tokens)
    end

    test "handles missing collector gracefully" do
      input = build_input()
      config = [enabled: true, events: [:stop]]

      # Even if collector fails, should not crash
      result =
        Telemetry.with_telemetry(input, :TestFunction, config, fn _collector_opts ->
          {:ok, :result}
        end)

      assert result == {:ok, :result}
      assert_receive {:telemetry_event, [:ash_baml, :call, :stop], measurements, _}
      assert measurements.input_tokens >= 0
      assert measurements.output_tokens >= 0
      assert measurements.total_tokens >= 0
    end

    test "fast path returns empty collector opts when disabled" do
      input = build_input()
      config = [enabled: false]

      Telemetry.with_telemetry(input, :TestFunction, config, fn collector_opts ->
        assert collector_opts == []
        {:ok, :fast_path}
      end)
    end
  end

  # Test helper to build input struct
  defp build_input do
    %{
      resource: TestResource,
      action: %{name: :test_action},
      arguments: %{},
      context: %{}
    }
  end

  # Telemetry handler that sends events to test process
  def handle_event(event, measurements, metadata, %{test_pid: pid}) do
    send(pid, {:telemetry_event, event, measurements, metadata})
  end

  # Mock resource for testing
  defmodule TestResource do
    use Ash.Resource, domain: nil

    actions do
      action(:test_action, :map)
    end
  end
end
