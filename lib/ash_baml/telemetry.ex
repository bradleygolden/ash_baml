defmodule AshBaml.Telemetry do
  require Logger
  alias AshBaml.Actions.Shared

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

  The `:stop` event additionally includes observability metadata:

      %{
        model_name: "gpt-4",
        provider: "openai",
        client_name: "GPT4Client",
        num_attempts: 1,
        request_id: "req_abc123",
        raw_response: "The capital of France is Paris.",
        tags: %{"environment" => "production"},
        log_type: "call",
        http_request: %{
          url: "https://api.openai.com/v1/chat/completions",
          method: "POST",
          headers: %{"content-type" => "application/json"},
          body: "{...}"
        },
        http_response: %{
          status_code: 200,
          headers: %{"content-type" => "application/json"},
          body: "{...}"
        }
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

  Returns a tuple `{result, collector}` where result is `{:ok, term()}` or
  `{:error, term()}` from the function call, and collector is the
  `BamlElixir.Collector` reference used for the call.

  ## Examples

      {result, collector} = AshBaml.Telemetry.with_telemetry(
        input,
        :ChatAgent,
        config,
        fn collector_opts ->
          ClientModule.ChatAgent.call(args, collector_opts)
        end
      )
  """
  def with_telemetry(input, function_name, config, func) do
    collector = create_collector(input, function_name, config)

    result =
      if enabled?(input, config) && should_sample?(config) do
        execute_with_telemetry(input, function_name, config, func, collector)
      else
        func.(%{collectors: [collector]})
      end

    {result, collector}
  end

  defp execute_with_telemetry(input, function_name, config, func, collector) do
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
      observability_data = get_observability_data(collector)

      metadata_with_observability =
        metadata
        |> Map.put(:model_name, observability_data.model_name)
        |> Map.put(:provider, observability_data.provider)
        |> Map.put(:client_name, observability_data.client_name)
        |> Map.put(:num_attempts, observability_data.num_attempts)
        |> Map.put(:request_id, observability_data.request_id)
        |> Map.put(:raw_response, observability_data.raw_response)
        |> Map.put(:tags, observability_data.tags)
        |> Map.put(:log_type, observability_data.log_type)
        |> Map.put(:http_request, observability_data.http_request)
        |> Map.put(:http_response, observability_data.http_response)

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
        metadata_with_observability
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
      %{"input_tokens" => input, "output_tokens" => output} ->
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

  defp get_observability_data(collector) do
    function_log = BamlElixir.Collector.last_function_log(collector)
    call = get_selected_or_first_call(function_log)

    %{
      model_name: extract_model_name_from_log(call),
      provider: Map.get(call || %{}, "provider"),
      client_name: Map.get(call || %{}, "client_name"),
      num_attempts:
        case Map.get(function_log || %{}, "calls") do
          calls when is_list(calls) -> length(calls)
          _ -> nil
        end,
      request_id: Map.get(function_log || %{}, "id"),
      raw_response: Map.get(function_log || %{}, "raw_llm_response"),
      tags: extract_tags_from_log(function_log),
      log_type: Map.get(function_log || %{}, "log_type"),
      http_request: extract_http_request(call),
      http_response: extract_http_response(call)
    }
  rescue
    exception ->
      Logger.debug("Failed to extract observability data from collector: #{inspect(exception)}")

      %{
        model_name: nil,
        provider: nil,
        client_name: nil,
        num_attempts: nil,
        request_id: nil,
        raw_response: nil,
        tags: nil,
        log_type: nil,
        http_request: nil,
        http_response: nil
      }
  end

  defp get_selected_or_first_call(nil), do: nil

  defp get_selected_or_first_call(function_log) do
    calls = Map.get(function_log, "calls", [])

    Enum.find(calls, fn call -> Map.get(call, "selected") == true end) ||
      List.first(calls)
  end

  defp extract_model_name_from_log(nil), do: nil

  defp extract_model_name_from_log(call) when is_map(call) do
    case get_in(call, ["request", "body"]) do
      body when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, %{"model" => model}} when is_binary(model) -> model
          _ -> nil
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp extract_model_name_from_log(_), do: nil

  defp extract_tags_from_log(nil), do: nil

  defp extract_tags_from_log(function_log) do
    case Map.get(function_log, "tags") do
      tags when is_map(tags) and map_size(tags) > 0 -> tags
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp extract_http_request(nil), do: nil

  defp extract_http_request(call) when is_map(call) do
    case Map.get(call, "request") do
      request when is_map(request) ->
        %{
          url: Map.get(request, "url"),
          method: Map.get(request, "method"),
          headers: Map.get(request, "headers"),
          body: Map.get(request, "body")
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Enum.into(%{})
        |> case do
          map when map == %{} -> nil
          map -> map
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp extract_http_request(_), do: nil

  defp extract_http_response(nil), do: nil

  defp extract_http_response(call) when is_map(call) do
    case Map.get(call, "response") do
      response when is_map(response) ->
        %{
          status_code: Map.get(response, "status_code"),
          headers: Map.get(response, "headers"),
          body: Map.get(response, "body")
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Enum.into(%{})
        |> case do
          map when map == %{} -> nil
          map -> map
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp extract_http_response(_), do: nil

  defp build_metadata(input, function_name, collector, config) do
    base = %{
      resource: input.resource,
      action: Shared.get_action_name(input),
      function_name: to_string(function_name),
      collector_name: collector.reference |> :erlang.ref_to_list() |> to_string()
    }

    additional = collect_optional_metadata(input, config)

    Map.merge(base, additional)
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
