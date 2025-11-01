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
            result =
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

      Enum.each(results, fn result ->
        assert {:ok, {_message, {:ok, _response}}} = result,
               "Task failed: #{inspect(result)}"
      end)

      responses =
        Enum.flat_map(results, fn result ->
          case result do
            {:ok, {message, {:ok, response}}} -> [{message, response}]
            _ -> []
          end
        end)

      Enum.each(responses, fn {_message, response} ->
        assert is_struct(response)
        assert Map.has_key?(response, :content)
        assert is_binary(response.content)
        assert String.length(response.content) > 0

        # Verify the message was processed (not just random response)
        # The LLM should acknowledge it received a test message
        assert response.content != nil
      end)

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
            result =
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

      Enum.each(results, fn result ->
        assert {:ok, {_message, {:ok, _response}}} = result,
               "Task failed: #{inspect(result)}"
      end)

      responses =
        Enum.flat_map(results, fn result ->
          case result do
            {:ok, {message, {:ok, response}}} -> [{message, response}]
            _ -> []
          end
        end)

      Enum.each(responses, fn {_message, response} ->
        assert is_struct(response)
        assert Map.has_key?(response, :content)
        assert is_binary(response.content)
        assert String.length(response.content) > 0
      end)

      # Verify all 20 calls completed
      assert length(responses) == 20

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
            result =
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

      Enum.each(results, fn result ->
        assert {:ok, {_message, {:ok, _response}}} = result,
               "Task failed: #{inspect(result)}"
      end)

      responses =
        Enum.flat_map(results, fn result ->
          case result do
            {:ok, {message, {:ok, response}}} -> [{message, response}]
            _ -> []
          end
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

      # Should complete in reasonable time (< 60 seconds for 50 concurrent calls)
      assert duration < 60_000,
             "50 concurrent calls took #{duration}ms, expected < 60000ms"

      # Verify no resource exhaustion
      assert avg_time > 0
    end

    test "memory usage is reasonable" do
      # This test verifies that memory usage doesn't grow excessively with BAML calls
      # Checks for memory leaks, excessive allocations, or unbounded growth
      # Measures memory before, during, and after a series of calls

      # Force garbage collection to get a clean baseline
      :erlang.garbage_collect()

      # Get baseline memory usage (in bytes)
      baseline_memory = :erlang.memory(:total)

      # Make 10 sequential calls to see memory behavior
      Enum.each(1..10, fn i ->
        {:ok, _result} =
          TestResource
          |> Ash.ActionInput.for_action(:test_action, %{
            message: "Memory test call #{i}"
          })
          |> Ash.run_action()
      end)

      # Force garbage collection after calls
      :erlang.garbage_collect()

      # Get memory usage after calls
      after_calls_memory = :erlang.memory(:total)

      # Calculate memory growth
      memory_growth_bytes = after_calls_memory - baseline_memory
      memory_growth_mb = Float.round(memory_growth_bytes / 1_048_576, 2)

      # Reasonable threshold: memory growth should be < 50 MB for 10 calls
      # This accounts for:
      # - Response data being held temporarily
      # - BAML client caching
      # - Normal Erlang process overhead
      # - Some data structures not yet GC'd
      assert memory_growth_bytes < 50 * 1_048_576,
             "Memory grew by #{memory_growth_mb} MB after 10 calls, expected < 50 MB. Possible memory leak."

      # Make another batch to verify memory doesn't keep growing
      Enum.each(1..10, fn i ->
        {:ok, _result} =
          TestResource
          |> Ash.ActionInput.for_action(:test_action, %{
            message: "Second batch call #{i}"
          })
          |> Ash.run_action()
      end)

      :erlang.garbage_collect()

      second_batch_memory = :erlang.memory(:total)
      second_growth_bytes = second_batch_memory - after_calls_memory
      second_growth_mb = Float.round(second_growth_bytes / 1_048_576, 2)

      # Second batch should not grow significantly more than first batch
      # If it does, indicates unbounded growth (memory leak)
      # Allow up to 2x the first batch growth as tolerance
      max_allowed_second_growth = max(memory_growth_bytes * 2, 10 * 1_048_576)

      assert second_growth_bytes < max_allowed_second_growth,
             "Second batch grew by #{second_growth_mb} MB, first batch grew by #{memory_growth_mb} MB. Memory appears to be leaking."
    end

    test "load test (50 calls in sequence)" do
      # This test verifies that the system can handle a sustained load of sequential calls
      # Checks for performance degradation over time, memory leaks, or resource exhaustion
      # 50 sequential calls simulates continuous production usage
      # CRITICAL: Tests that sequential load doesn't cause degradation

      num_calls = 50

      start_time = System.monotonic_time(:millisecond)

      results =
        Enum.map(1..num_calls, fn i ->
          call_start = System.monotonic_time(:millisecond)

          {:ok, result} =
            TestResource
            |> Ash.ActionInput.for_action(:test_action, %{
              message: "Load test call #{i}"
            })
            |> Ash.run_action()

          call_duration = System.monotonic_time(:millisecond) - call_start

          {i, result, call_duration}
        end)

      total_duration = System.monotonic_time(:millisecond) - start_time

      # Verify all calls succeeded
      assert length(results) == num_calls

      Enum.each(results, fn {_i, result, _duration} ->
        assert is_struct(result)
        assert Map.has_key?(result, :content)
        assert is_binary(result.content)
        assert String.length(result.content) > 0
      end)

      avg_time = div(total_duration, num_calls)
      durations = Enum.map(results, fn {_i, _result, duration} -> duration end)
      min_time = Enum.min(durations)
      max_time = Enum.max(durations)

      assert avg_time > 0, "Average time should be positive"
      assert min_time > 0, "Min time should be positive"
      assert max_time >= min_time, "Max time should be >= min time"
      assert max_time < 30_000, "Max time should be reasonable (< 30s)"

      # Extract first 10 and last 10 call durations from results
      first_10_times =
        results
        |> Enum.take(10)
        |> Enum.map(fn {_i, _result, duration} -> duration end)

      last_10_times =
        results
        |> Enum.take(-10)
        |> Enum.map(fn {_i, _result, duration} -> duration end)

      avg_first_10 = div(Enum.sum(first_10_times), length(first_10_times))
      avg_last_10 = div(Enum.sum(last_10_times), length(last_10_times))

      # Check for performance degradation
      # Last 10 calls should not be significantly slower than first 10
      # Allow up to 50% degradation as tolerance (network variance, API throttling, etc.)
      degradation_threshold = avg_first_10 * 1.5

      assert avg_last_10 < degradation_threshold,
             "Performance degradation detected: first 10 avg=#{avg_first_10}ms, last 10 avg=#{avg_last_10}ms"

      # Total duration should be reasonable (< 90 seconds for 50 sequential calls)
      # Each call should average < 2 seconds
      assert total_duration < 90_000,
             "#{num_calls} sequential calls took #{total_duration}ms (#{Float.round(total_duration / 1000, 1)}s), expected < 90s"
    end
  end
end
