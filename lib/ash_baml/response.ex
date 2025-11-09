defmodule AshBaml.Response do
  @moduledoc """
  Wrapper for BAML function responses including usage metadata.

  This struct wraps the result of a BAML function call with token usage information,
  enabling integration with observability systems like AshAgent's `response_usage/1`.

  ## Fields

  - `:data` - The actual BAML function result (struct or primitive)
  - `:usage` - Token usage map with `:input_tokens`, `:output_tokens`, `:total_tokens`
  - `:collector` - The BamlElixir.Collector reference used for the call

  ## Example

      response = AshBaml.Response.new(result, collector)
      response.data        # => %ChatResponse{message: "Hello!"}
      response.usage       # => %{input_tokens: 10, output_tokens: 5, total_tokens: 15}

      # Extract just the data
      data = AshBaml.Response.unwrap(response)

      # Get usage for observability
      usage = AshBaml.Response.usage(response)
  """

  require Logger

  defstruct [:data, :usage, :collector]

  @type t :: %__MODULE__{
          data: term(),
          usage:
            %{
              input_tokens: non_neg_integer(),
              output_tokens: non_neg_integer(),
              total_tokens: non_neg_integer()
            }
            | nil,
          collector: %BamlElixir.Collector{reference: reference()} | nil
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
    %__MODULE__{
      data: data,
      usage: extract_usage(collector),
      collector: collector
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
end
