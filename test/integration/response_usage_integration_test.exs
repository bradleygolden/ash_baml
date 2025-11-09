defmodule AshBaml.ResponseUsageIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  defmodule ResponseTestDomain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshBaml.ResponseUsageIntegrationTest.ResponseTestResource)
    end
  end

  defmodule ResponseTestResource do
    @moduledoc false

    use Ash.Resource,
      domain: AshBaml.ResponseUsageIntegrationTest.ResponseTestDomain,
      extensions: [AshBaml.Resource]

    baml do
      client_module(AshBaml.Test.BamlClient)

      telemetry do
        enabled(true)
      end
    end

    actions do
      action :test_response, :map do
        argument(:message, :string, allow_nil?: false)
        run(call_baml(:TestFunction))
      end

      action :test_short_message, :map do
        argument(:message, :string, allow_nil?: false)
        run(call_baml(:TestFunction))
      end

      action :test_long_message, :map do
        argument(:message, :string, allow_nil?: false)
        run(call_baml(:TestFunction))
      end
    end
  end

  describe "Response wrapper with real API calls" do
    test "returns Response struct with usage data" do
      {:ok, response} =
        ResponseTestResource
        |> Ash.ActionInput.for_action(:test_response, %{
          message: "Hello, world!"
        })
        |> Ash.run_action()

      # Verify it's a Response struct
      assert %AshBaml.Response{} = response

      # Verify data field contains the BAML result
      assert is_struct(response.data)
      assert Map.has_key?(response.data, :content)
      assert Map.has_key?(response.data, :confidence)
      assert is_binary(response.data.content)
      assert is_float(response.data.confidence)

      # Verify usage field contains token counts
      assert is_map(response.usage)
      assert Map.has_key?(response.usage, :input_tokens)
      assert Map.has_key?(response.usage, :output_tokens)
      assert Map.has_key?(response.usage, :total_tokens)

      assert is_integer(response.usage.input_tokens)
      assert is_integer(response.usage.output_tokens)
      assert is_integer(response.usage.total_tokens)

      # Verify token counts are positive
      assert response.usage.input_tokens > 0
      assert response.usage.output_tokens > 0
      assert response.usage.total_tokens > 0

      # Verify total = input + output
      assert response.usage.total_tokens ==
               response.usage.input_tokens + response.usage.output_tokens

      # Verify collector is present
      assert response.collector != nil
    end

    test "unwrap/1 extracts data from Response" do
      {:ok, response} =
        ResponseTestResource
        |> Ash.ActionInput.for_action(:test_response, %{
          message: "Test unwrap"
        })
        |> Ash.run_action()

      # Unwrap should extract the data field
      data = AshBaml.Response.unwrap(response)

      assert is_struct(data)
      assert data == response.data
      assert Map.has_key?(data, :content)
      assert Map.has_key?(data, :confidence)
    end

    test "unwrap/1 works on already unwrapped data" do
      {:ok, response} =
        ResponseTestResource
        |> Ash.ActionInput.for_action(:test_response, %{
          message: "Test double unwrap"
        })
        |> Ash.run_action()

      # First unwrap
      data1 = AshBaml.Response.unwrap(response)

      # Second unwrap should return same data (idempotent)
      data2 = AshBaml.Response.unwrap(data1)

      assert data1 == data2
      assert is_struct(data2)
    end

    test "usage/1 extracts usage metadata" do
      {:ok, response} =
        ResponseTestResource
        |> Ash.ActionInput.for_action(:test_response, %{
          message: "Test usage extraction"
        })
        |> Ash.run_action()

      usage = AshBaml.Response.usage(response)

      assert is_map(usage)
      assert %{input_tokens: _, output_tokens: _, total_tokens: _} = usage
      assert is_integer(usage.input_tokens)
      assert is_integer(usage.output_tokens)
      assert is_integer(usage.total_tokens)
      assert usage.total_tokens == usage.input_tokens + usage.output_tokens
    end

    test "usage varies with input size" do
      # Short message
      {:ok, short_response} =
        ResponseTestResource
        |> Ash.ActionInput.for_action(:test_short_message, %{
          message: "Hi"
        })
        |> Ash.run_action()

      # Long message
      long_message = String.duplicate("This is a longer test message. ", 10)

      {:ok, long_response} =
        ResponseTestResource
        |> Ash.ActionInput.for_action(:test_long_message, %{
          message: long_message
        })
        |> Ash.run_action()

      short_usage = AshBaml.Response.usage(short_response)
      long_usage = AshBaml.Response.usage(long_response)

      # Longer input should have more input tokens
      assert long_usage.input_tokens > short_usage.input_tokens,
             "Long message (#{long_usage.input_tokens} tokens) should have more input tokens than short message (#{short_usage.input_tokens} tokens)"

      # Output tokens might vary, but both should be positive
      assert short_usage.output_tokens > 0
      assert long_usage.output_tokens > 0

      # Total tokens should reflect the difference
      assert long_usage.total_tokens > short_usage.total_tokens,
             "Long message total (#{long_usage.total_tokens}) should exceed short message total (#{short_usage.total_tokens})"
    end

    test "usage data is accurate and reasonable" do
      {:ok, response} =
        ResponseTestResource
        |> Ash.ActionInput.for_action(:test_response, %{
          message: "What is the capital of France?"
        })
        |> Ash.run_action()

      usage = response.usage

      # Input tokens should be reasonable for this query
      # "What is the capital of France?" ≈ 7 tokens + system prompt
      assert usage.input_tokens >= 10, "Input tokens (#{usage.input_tokens}) seems too low"

      assert usage.input_tokens <= 200,
             "Input tokens (#{usage.input_tokens}) seems too high for simple query"

      # Output tokens should be reasonable for a simple answer
      # Expected: structured response with city name + confidence
      assert usage.output_tokens > 0, "Output tokens should be positive"

      assert usage.output_tokens <= 500,
             "Output tokens (#{usage.output_tokens}) seems too high for simple response"

      # Total should be sum
      assert usage.total_tokens == usage.input_tokens + usage.output_tokens
    end

    test "concurrent calls each have separate usage tracking" do
      messages = [
        "Call 1",
        "Call 2",
        "Call 3"
      ]

      tasks =
        Enum.map(messages, fn message ->
          Task.async(fn ->
            {:ok, response} =
              ResponseTestResource
              |> Ash.ActionInput.for_action(:test_response, %{message: message})
              |> Ash.run_action()

            response
          end)
        end)

      responses = Task.await_many(tasks, 30_000)

      assert length(responses) == 3

      # Each response should have its own usage data
      usages = Enum.map(responses, &AshBaml.Response.usage/1)

      Enum.each(usages, fn usage ->
        assert is_map(usage)
        assert %{input_tokens: _, output_tokens: _, total_tokens: _} = usage
        assert usage.input_tokens > 0
        assert usage.output_tokens > 0
        assert usage.total_tokens > 0
      end)

      # Each response should have different collectors
      collectors = Enum.map(responses, & &1.collector)
      assert length(Enum.uniq(collectors)) == 3, "Each call should have unique collector"
    end

    test "usage tracking works with telemetry enabled" do
      # Verify that Response wrapper and telemetry can coexist
      test_pid = self()
      ref = make_ref()
      handler_id = "test-response-telemetry-#{:erlang.ref_to_list(ref)}"

      :telemetry.attach(
        handler_id,
        [:ash_baml, :call, :stop],
        fn _event_name, measurements, _metadata, _config ->
          send(test_pid, {ref, :telemetry, measurements})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      {:ok, response} =
        ResponseTestResource
        |> Ash.ActionInput.for_action(:test_response, %{
          message: "Test both response and telemetry"
        })
        |> Ash.run_action()

      # Response should have usage
      response_usage = AshBaml.Response.usage(response)
      assert is_map(response_usage)

      # Telemetry should also fire with same usage data
      assert_receive {^ref, :telemetry, telemetry_measurements}, 5000

      # Both should report the same token counts
      assert response_usage.input_tokens == telemetry_measurements.input_tokens

      assert response_usage.output_tokens == telemetry_measurements.output_tokens

      assert response_usage.total_tokens == telemetry_measurements.total_tokens

      :telemetry.detach(handler_id)
    end

    test "usage data enables budget checking" do
      max_tokens = 250

      {:ok, response} =
        ResponseTestResource
        |> Ash.ActionInput.for_action(:test_response, %{
          message: "Short"
        })
        |> Ash.run_action()

      # This simple call should be under budget
      if response.usage.total_tokens > max_tokens do
        flunk(
          "Expected call to be under budget (#{max_tokens}), got #{response.usage.total_tokens} tokens"
        )
      end

      # Verify we can use usage for budget decisions
      assert is_integer(response.usage.total_tokens)
      assert response.usage.total_tokens > 0
    end

    test "usage data enables cost calculation" do
      # Mock pricing: $0.003 per 1K input tokens, $0.012 per 1K output tokens
      input_price_per_1k = 0.003
      output_price_per_1k = 0.012

      {:ok, response} =
        ResponseTestResource
        |> Ash.ActionInput.for_action(:test_response, %{
          message: "Calculate my cost"
        })
        |> Ash.run_action()

      usage = response.usage

      # Calculate cost from usage
      input_cost = usage.input_tokens / 1000 * input_price_per_1k
      output_cost = usage.output_tokens / 1000 * output_price_per_1k
      total_cost = input_cost + output_cost

      # Verify cost calculation is reasonable
      assert is_float(total_cost)
      assert total_cost > 0
      assert total_cost < 1.0, "Cost for simple call should be well under $1"

      # Typically this call costs $0.0001-0.001
      assert total_cost >= 0.00001,
             "Cost (#{total_cost}) seems unreasonably low"

      assert total_cost <= 0.01, "Cost (#{total_cost}) seems unreasonably high"
    end
  end
end
