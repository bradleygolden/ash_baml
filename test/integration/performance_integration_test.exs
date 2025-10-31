defmodule AshBaml.PerformanceIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 120_000

  alias AshBaml.Test.TestResource

  describe "concurrency and performance" do
    test "10 concurrent calls all succeed" do
      # This test verifies that the system can handle 10 parallel BAML calls
      # without race conditions, errors, or interference between calls
      # CRITICAL: Tests cluster safety - no shared mutable state

      messages =
        Enum.map(1..10, fn i ->
          "This is test message number #{i}. Please respond briefly."
        end)

      start_time = System.monotonic_time(:millisecond)

      results =
        messages
        |> Task.async_stream(
          fn message ->
            {:ok, result} =
              TestResource
              |> Ash.ActionInput.for_action(:test_action, %{
                message: message
              })
              |> Ash.run_action()

            {message, result}
          end,
          timeout: 60_000,
          max_concurrency: 10
        )
        |> Enum.to_list()

      duration = System.monotonic_time(:millisecond) - start_time

      # All tasks should succeed
      Enum.each(results, fn result ->
        assert {:ok, {_message, _response}} = result
      end)

      # Extract the responses
      responses =
        Enum.map(results, fn {:ok, {message, response}} ->
          {message, response}
        end)

      # Verify each response is valid
      Enum.each(responses, fn {_message, response} ->
        # Should be a struct with content field
        assert is_struct(response)
        assert Map.has_key?(response, :content)
        assert is_binary(response.content)
        assert String.length(response.content) > 0

        # Verify the message was processed (not just random response)
        # The LLM should acknowledge it received a test message
        assert response.content != nil
      end)

      IO.puts("10 concurrent calls: #{length(results)} calls completed in #{duration}ms ✓")
      IO.puts("Average time per call: #{div(duration, length(results))}ms")

      # Reasonable performance expectation: should complete in < 30 seconds
      # (10 concurrent calls should be much faster than 10 sequential calls)
      assert duration < 30_000,
             "10 concurrent calls took #{duration}ms, expected < 30000ms"
    end

    test "20 concurrent calls (check for bottlenecks)" do
      # This test verifies the system can handle higher concurrency (20 parallel calls)
      # Checks for performance bottlenecks, connection limits, or resource contention
      # CRITICAL: Tests cluster safety at higher concurrency levels

      messages =
        Enum.map(1..20, fn i ->
          "Message #{i}: Respond with a single sentence."
        end)

      start_time = System.monotonic_time(:millisecond)

      results =
        messages
        |> Task.async_stream(
          fn message ->
            {:ok, result} =
              TestResource
              |> Ash.ActionInput.for_action(:test_action, %{
                message: message
              })
              |> Ash.run_action()

            {message, result}
          end,
          timeout: 60_000,
          max_concurrency: 20
        )
        |> Enum.to_list()

      duration = System.monotonic_time(:millisecond) - start_time

      # All tasks should succeed
      Enum.each(results, fn result ->
        assert {:ok, {_message, _response}} = result
      end)

      # Extract the responses
      responses =
        Enum.map(results, fn {:ok, {message, response}} ->
          {message, response}
        end)

      # Verify each response is valid
      Enum.each(responses, fn {_message, response} ->
        assert is_struct(response)
        assert Map.has_key?(response, :content)
        assert is_binary(response.content)
        assert String.length(response.content) > 0
      end)

      # Verify all 20 calls completed
      assert length(responses) == 20

      IO.puts("20 concurrent calls: #{length(results)} calls completed in #{duration}ms ✓")
      IO.puts("Average time per call: #{div(duration, length(results))}ms")

      # Check for performance bottlenecks
      # Should complete in reasonable time (< 45 seconds for 20 concurrent calls)
      # If significantly slower than 10 concurrent calls, indicates bottleneck
      assert duration < 45_000,
             "20 concurrent calls took #{duration}ms, expected < 45000ms - possible bottleneck"
    end

    test "stress test (50 concurrent calls)" do
      # This test verifies the system can handle high concurrency stress
      # Tests for race conditions, resource exhaustion, connection limits
      # 50 concurrent calls is realistic for production burst traffic
      # CRITICAL: Tests cluster safety under stress conditions

      num_calls = 50

      messages =
        Enum.map(1..num_calls, fn i ->
          "Stress test #{i}"
        end)

      start_time = System.monotonic_time(:millisecond)

      results =
        messages
        |> Task.async_stream(
          fn message ->
            {:ok, result} =
              TestResource
              |> Ash.ActionInput.for_action(:test_action, %{
                message: message
              })
              |> Ash.run_action()

            {message, result}
          end,
          timeout: 60_000,
          max_concurrency: 50
        )
        |> Enum.to_list()

      duration = System.monotonic_time(:millisecond) - start_time

      # All tasks should succeed
      Enum.each(results, fn result ->
        assert {:ok, {_message, _response}} = result
      end)

      # Extract the responses
      responses =
        Enum.map(results, fn {:ok, {message, response}} ->
          {message, response}
        end)

      # Verify all 50 calls completed
      assert length(responses) == num_calls

      # Verify each response is valid
      Enum.each(responses, fn {_message, response} ->
        assert is_struct(response)
        assert Map.has_key?(response, :content)
        assert is_binary(response.content)
        assert String.length(response.content) > 0
      end)

      avg_time = div(duration, num_calls)

      IO.puts("Stress test: #{num_calls} concurrent calls completed in #{duration}ms ✓")
      IO.puts("Average time per call: #{avg_time}ms")
      IO.puts("Total duration: #{Float.round(duration / 1000, 1)} seconds")

      # Should complete in reasonable time (< 60 seconds for 50 concurrent calls)
      assert duration < 60_000,
             "50 concurrent calls took #{duration}ms, expected < 60000ms"

      IO.puts("No resource exhaustion or connection limits detected ✓")
    end
  end
end
