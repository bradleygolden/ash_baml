defmodule AshBaml.PerformanceIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 120_000

  alias AshBaml.Test.TestResource

  describe "performance" do
    @tag timeout: 300_000
    test "memory usage is reasonable" do
      # This test verifies that memory usage doesn't grow excessively with BAML calls
      # Checks for memory leaks, excessive allocations, or unbounded growth
      # Measures memory before, during, and after a series of calls

      :erlang.garbage_collect()

      baseline_memory = :erlang.memory(:total)

      Enum.each(1..10, fn i ->
        {:ok, _result} =
          TestResource
          |> Ash.ActionInput.for_action(:test_action, %{
            message: "Memory test call #{i}"
          })
          |> Ash.run_action()
      end)

      :erlang.garbage_collect()

      after_calls_memory = :erlang.memory(:total)

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
  end
end
