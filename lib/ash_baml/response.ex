defmodule AshBaml.Response do
  @moduledoc """
  Wrapper for BAML function responses including usage metadata.

  This struct wraps the result of a BAML function call with token usage information,
  enabling integration with observability systems like AshAgent's `response_usage/1`.

  ## Fields

  - `:data` - The actual BAML function result (struct or primitive)
  - `:usage` - Token usage map with `:input_tokens`, `:output_tokens`, `:total_tokens`
  - `:collector` - The BamlElixir.Collector reference used for the call
  - `:model_name` - LLM model name (e.g., "gpt-4", "claude-3-opus")
  - `:provider` - LLM provider (e.g., "openai", "anthropic")
  - `:client_name` - BAML client name used for the call
  - `:timing` - Timing information map with `:duration_ms`, `:start_time_utc_ms`, `:time_to_first_token_ms`
  - `:num_attempts` - Number of LLM call attempts (tracks retries/fallbacks)
  - `:function_name` - BAML function name that was called
  - `:request_id` - Unique identifier for this request

  ## Example

      response = AshBaml.Response.new(result, collector)
      response.data           # => %ChatResponse{message: "Hello!"}
      response.usage          # => %{input_tokens: 10, output_tokens: 5, total_tokens: 15}
      response.model_name     # => "gpt-4"
      response.provider       # => "openai"
      response.timing         # => %{duration_ms: 234, start_time_utc_ms: 1699123456789}
      response.num_attempts   # => 1
      response.function_name  # => "ChatAgent"

      # Extract just the data
      data = AshBaml.Response.unwrap(response)

      # Get usage for observability
      usage = AshBaml.Response.usage(response)
  """

  require Logger

  defstruct [
    :data,
    :usage,
    :collector,
    :model_name,
    :provider,
    :client_name,
    :timing,
    :num_attempts,
    :function_name,
    :request_id
  ]

  @type t :: %__MODULE__{
          data: term(),
          usage:
            %{
              input_tokens: non_neg_integer(),
              output_tokens: non_neg_integer(),
              total_tokens: non_neg_integer()
            }
            | nil,
          collector: %BamlElixir.Collector{reference: reference()} | nil,
          model_name: String.t() | nil,
          provider: String.t() | nil,
          client_name: String.t() | nil,
          timing:
            %{
              duration_ms: number(),
              start_time_utc_ms: number(),
              time_to_first_token_ms: number() | nil
            }
            | nil,
          num_attempts: non_neg_integer() | nil,
          function_name: String.t() | nil,
          request_id: String.t() | nil
        }

  @doc """
  Creates a new Response wrapping BAML function result with usage metadata.

  ## Arguments

  - `data` - The BAML function result to wrap
  - `collector` - The BamlElixir.Collector used for the call (may be nil)

  ## Returns

  Returns a `%AshBaml.Response{}` struct with extracted usage information.
  """
  def new(data, collector) do
    function_log = get_function_log(collector)

    %__MODULE__{
      data: data,
      usage: extract_usage(collector),
      collector: collector,
      model_name: extract_model_name(function_log),
      provider: extract_provider(function_log),
      client_name: extract_client_name(function_log),
      timing: extract_timing(function_log),
      num_attempts: extract_num_attempts(function_log),
      function_name: extract_function_name(function_log),
      request_id: extract_request_id(function_log)
    }
  end

  @doc """
  Extracts the original data from a Response struct.

  This is a convenience function that handles both Response structs
  and raw data, making it safe to use in contexts where you're unsure
  if the data has been wrapped.

  ## Arguments

  - `response` - Either a `%AshBaml.Response{}` struct or raw data

  ## Returns

  Returns the unwrapped data.

  ## Examples

      iex> response = %AshBaml.Response{data: "hello"}
      iex> AshBaml.Response.unwrap(response)
      "hello"

      iex> AshBaml.Response.unwrap("hello")
      "hello"
  """
  @spec unwrap(t() | term()) :: term()
  def unwrap(%__MODULE__{data: data}), do: data
  def unwrap(data), do: data

  @doc """
  Extracts usage metadata from a Response struct.

  ## Arguments

  - `response` - A `%AshBaml.Response{}` struct

  ## Returns

  Returns a map with `:input_tokens`, `:output_tokens`, and `:total_tokens`,
  or `nil` if usage information is unavailable.

  ## Example

      iex> response = %AshBaml.Response{usage: %{input_tokens: 10, output_tokens: 5, total_tokens: 15}}
      iex> AshBaml.Response.usage(response)
      %{input_tokens: 10, output_tokens: 5, total_tokens: 15}
  """
  @spec usage(t()) :: map() | nil
  def usage(%__MODULE__{usage: usage}), do: usage

  defp extract_usage(nil), do: nil

  defp extract_usage(collector) do
    usage_result = BamlElixir.Collector.usage(collector)

    case usage_result do
      %{"input_tokens" => input, "output_tokens" => output} ->
        %{
          input_tokens: input || 0,
          output_tokens: output || 0,
          total_tokens: (input || 0) + (output || 0)
        }

      _ ->
        nil
    end
  rescue
    exception ->
      Logger.debug("Failed to extract token usage from collector: #{inspect(exception)}")
      nil
  end

  defp get_function_log(nil), do: nil

  defp get_function_log(collector) do
    BamlElixir.Collector.last_function_log(collector)
  rescue
    exception ->
      Logger.debug("Failed to get function log from collector: #{inspect(exception)}")
      nil
  end

  defp extract_model_name(nil), do: nil

  defp extract_model_name(function_log) do
    case get_in(function_log, ["calls", Access.at(0), "request", "body"]) do
      body when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, %{"model" => model}} when is_binary(model) -> model
          _ -> nil
        end

      _ ->
        nil
    end
  rescue
    exception ->
      Logger.debug("Failed to extract model name from function log: #{inspect(exception)}")
      nil
  end

  defp extract_provider(nil), do: nil

  defp extract_provider(function_log) do
    get_in(function_log, ["calls", Access.at(0), "provider"])
  rescue
    exception ->
      Logger.debug("Failed to extract provider from function log: #{inspect(exception)}")
      nil
  end

  defp extract_client_name(nil), do: nil

  defp extract_client_name(function_log) do
    get_in(function_log, ["calls", Access.at(0), "client_name"])
  rescue
    exception ->
      Logger.debug("Failed to extract client name from function log: #{inspect(exception)}")
      nil
  end

  defp extract_timing(nil), do: nil

  defp extract_timing(function_log) do
    case Map.get(function_log, "timing") do
      timing when is_map(timing) ->
        %{
          duration_ms: Map.get(timing, "duration_ms"),
          start_time_utc_ms: Map.get(timing, "start_time_utc_ms"),
          time_to_first_token_ms: Map.get(timing, "time_to_first_token_ms")
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
    exception ->
      Logger.debug("Failed to extract timing from function log: #{inspect(exception)}")
      nil
  end

  defp extract_num_attempts(nil), do: nil

  defp extract_num_attempts(function_log) do
    case Map.get(function_log, "calls") do
      calls when is_list(calls) -> length(calls)
      _ -> nil
    end
  rescue
    exception ->
      Logger.debug("Failed to extract num_attempts from function log: #{inspect(exception)}")
      nil
  end

  defp extract_function_name(nil), do: nil

  defp extract_function_name(function_log) do
    Map.get(function_log, "function_name")
  rescue
    exception ->
      Logger.debug("Failed to extract function_name from function log: #{inspect(exception)}")
      nil
  end

  defp extract_request_id(nil), do: nil

  defp extract_request_id(function_log) do
    Map.get(function_log, "id")
  rescue
    exception ->
      Logger.debug("Failed to extract request_id from function log: #{inspect(exception)}")
      nil
  end
end
