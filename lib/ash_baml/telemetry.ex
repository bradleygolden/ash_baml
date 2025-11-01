defmodule AshBaml.Telemetry do
  require Logger

  @moduledoc """
  Telemetry integration for AshBaml.

  Provides observability into BAML function calls through Elixir's
  `:telemetry` ecosystem. Integrates with `baml_elixir`'s collector
  API to track token usage, performance, and execution details.

  ## Events

  This module emits three telemetry events per BAML function call:

  - `[:ash_baml, :call, :start]` - Before function execution
  - `[:ash_baml, :call, :stop]` - After successful execution
  - `[:ash_baml, :call, :exception]` - On error

  Event names can be customized via the `prefix` DSL option.

  ## Measurements

  ### :start event

      %{
        system_time: System.system_time(),
        monotonic_time: System.monotonic_time()
      }

  ### :stop event

      %{
        duration: native_time,              # Time elapsed
        input_tokens: 150,                   # From collector
        output_tokens: 75,                   # From collector
        total_tokens: 225,                   # Sum of input + output
        monotonic_time: System.monotonic_time()
      }

  ### :exception event

      %{
        duration: native_time,
        monotonic_time: System.monotonic_time()
      }

  ## Metadata

  All events include standard metadata:

      %{
        resource: MyApp.Assistant,
        action: :chat,
        function_name: "ChatAgent",
        collector_name: "MyApp.Assistant-ChatAgent-12345"
      }

  Additional metadata can be configured via the DSL.

  ## Privacy

  By default, only safe, aggregate data is included:
  - Token counts
  - Timing information
  - Resource/action/function names

  Sensitive data (prompts, responses, arguments) is NEVER included
  without explicit configuration.

  ## Performance

  When telemetry is disabled (default), this module has near-zero
  overhead through early return checks. When enabled, overhead is
  minimal (~10µs per call for collector creation and usage reading).

  ## Example

      # In application.ex
      :telemetry.attach(
        "log-token-usage",
        [:ash_baml, :call, :stop],
        fn _event, measurements, metadata, _config ->
          Logger.info("BAML call completed",
            function: metadata.function_name,
            tokens: measurements.total_tokens,
            duration_ms: System.convert_time_unit(
              measurements.duration,
              :native,
              :millisecond
            )
          )
        end,
        nil
      )
  """

  @doc """
  Wraps a BAML function call with telemetry.

  Emits `:start`, `:stop`, and `:exception` events with measurements
  and metadata. Creates a `BamlElixir.Collector` to track token usage
  and execution details.

  ## Arguments

  - `input` - The Ash action input containing resource, action, and arguments
  - `function_name` - The BAML function name (atom)
  - `config` - Telemetry configuration (from DSL)
  - `func` - Function to wrap (receives collector options)

  ## Returns

  Returns the result of `func.()`, which should be `{:ok, result}` or
  `{:error, reason}`.

  ## Examples

      result = AshBaml.Telemetry.with_telemetry(
        input,
        :ChatAgent,
        config,
        fn collector_opts ->
          ClientModule.ChatAgent.call(args, collector_opts)
        end
      )
  """
  @spec with_telemetry(
          Ash.Resource.record(),
          atom(),
          keyword(),
          (map() -> {:ok, term()} | {:error, term()})
        ) :: {:ok, term()} | {:error, term()}
  def with_telemetry(input, function_name, config, func) do
    if enabled?(input, config) && should_sample?(config) do
      execute_with_telemetry(input, function_name, config, func)
    else
      func.(%{})
    end
  end

  defp execute_with_telemetry(input, function_name, config, func) do
    collector = create_collector(input, function_name, config)
    metadata = build_metadata(input, function_name, collector, config)

    start_time = System.monotonic_time()
    system_time = System.system_time()

    emit_event(
      :start,
      config,
      %{
        monotonic_time: start_time,
        system_time: system_time
      },
      metadata
    )

    try do
      result = func.(%{collectors: [collector]})

      duration = System.monotonic_time() - start_time

      usage = get_usage(collector)
      model_name = get_model_name(collector)

      metadata_with_model = Map.put(metadata, :model_name, model_name)

      emit_event(
        :stop,
        config,
        %{
          duration: duration,
          input_tokens: usage.input_tokens,
          output_tokens: usage.output_tokens,
          total_tokens: usage.total_tokens,
          monotonic_time: System.monotonic_time()
        },
        metadata_with_model
      )

      result
    rescue
      e ->
        duration = System.monotonic_time() - start_time

        emit_event(
          :exception,
          config,
          %{
            duration: duration,
            monotonic_time: System.monotonic_time()
          },
          Map.merge(metadata, %{
            kind: :error,
            reason: Exception.message(e),
            stacktrace: __STACKTRACE__
          })
        )

        reraise e, __STACKTRACE__
    end
  end

  defp emit_event(event_type, config, measurements, metadata) do
    if event_type in config[:events] do
      event_name = build_event_name(event_type, config)

      :telemetry.execute(event_name, measurements, metadata)
    end
  end

  defp build_event_name(event_type, config) do
    prefix = config[:prefix] || [:ash_baml]
    prefix ++ [:call, event_type]
  end

  defp enabled?(_input, config) do
    config[:enabled] == true
  end

  defp should_sample?(config) do
    sample_rate = config[:sample_rate] || 1.0

    if sample_rate >= 1.0 do
      true
    else
      :rand.uniform() <= sample_rate
    end
  end

  defp create_collector(input, function_name, config) do
    name = generate_collector_name(input, function_name, config)
    BamlElixir.Collector.new(name)
  end

  defp generate_collector_name(input, function_name, config) do
    case config[:collector_name] do
      func when is_function(func, 1) ->
        func.(input)

      name when is_binary(name) ->
        name

      _ ->
        "#{inspect(input.resource)}-#{function_name}-#{System.unique_integer([:positive])}"
    end
  end

  defp get_usage(collector) do
    usage_result = BamlElixir.Collector.usage(collector)

    case usage_result do
      %{"input_tokens" => input, "output_tokens" => output} when is_map(usage_result) ->
        %{
          input_tokens: input || 0,
          output_tokens: output || 0,
          total_tokens: (input || 0) + (output || 0)
        }

      _ ->
        %{input_tokens: 0, output_tokens: 0, total_tokens: 0}
    end
  rescue
    exception ->
      Logger.debug("Failed to extract token usage from collector: #{inspect(exception)}")
      %{input_tokens: 0, output_tokens: 0, total_tokens: 0}
  end

  defp get_model_name(collector) do
    log_result = BamlElixir.Collector.last_function_log(collector)

    case log_result do
      %{"calls" => [%{"request" => %{"body" => body}} | _]} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, %{"model" => model}} when is_binary(model) -> model
          _ -> nil
        end

      _ ->
        nil
    end
  rescue
    exception ->
      Logger.debug("Failed to extract model name from collector: #{inspect(exception)}")
      nil
  end

  defp build_metadata(input, function_name, collector, config) do
    base = %{
      resource: input.resource,
      action: get_action_name(input),
      function_name: to_string(function_name),
      collector_name: collector.reference |> :erlang.ref_to_list() |> to_string()
    }

    additional = collect_optional_metadata(input, config)

    Map.merge(base, additional)
  end

  defp get_action_name(input) do
    case input.action do
      %{name: name} -> name
      name when is_atom(name) -> name
      _ -> :unknown
    end
  end

  defp collect_optional_metadata(input, config) do
    allowed = config[:metadata] || []

    context = Map.get(input, :context, %{})

    available = %{
      llm_client: Map.get(context, :llm_client),
      stream: Map.get(context, :stream, false)
    }

    available
    |> Enum.filter(fn {key, _val} -> key in allowed end)
    |> Map.new()
  end
end
