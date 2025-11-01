# Integration Tests - QA Fixes Implementation Guide

This guide provides concrete code examples for each identified issue with before/after comparisons.

---

## Fix 1: Remove Redundant Error Handling Pattern

**File**: `test/integration/performance_integration_test.exs`
**Severity**: CRITICAL
**Effort**: 5 minutes

### Issue Location 1: Lines 42-48

**BEFORE**:
```elixir
test "10 concurrent calls all succeed" do
  # ... setup code ...

  results =
    messages
    |> Task.async_stream(...)
    |> Enum.to_list()

  duration = System.monotonic_time(:millisecond) - start_time

  # REDUNDANT: This block does nothing useful
  Enum.each(results, fn result ->
    case result do
      {:ok, {_message, {:ok, _response}}} -> :ok
      {:ok, {_message, {:error, _error}}} -> :ok
      {:exit, _reason} -> :ok
    end
  end)

  # This is the actual validation that matters
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
    # ... more assertions ...
  end)
end
```

**AFTER**:
```elixir
test "10 concurrent calls all succeed" do
  # ... setup code ...

  results =
    messages
    |> Task.async_stream(...)
    |> Enum.to_list()

  duration = System.monotonic_time(:millisecond) - start_time

  # Filter for successful responses - this is the only validation needed
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
    # ... more assertions ...
  end)
end
```

**Rationale**:
- The first `Enum.each` with the case statement doesn't perform any actual validation
- All error patterns (success, error, exit) are handled identically (`:ok`)
- The `Enum.flat_map` already filters properly, making the case statement redundant
- Removing it makes the test intent clearer

### Issue Location 2: Lines 107-113

Same pattern in "20 concurrent calls" test - apply same fix (remove the redundant Enum.each)

### Issue Location 3: Lines 175-181

Same pattern in "stress test (50 concurrent calls)" - apply same fix (remove the redundant Enum.each)

---

## Fix 2: Add Custom Assertion Messages

**File**: `test/integration/baml_integration_test.exs`
**Severity**: WARNING
**Effort**: 15 minutes
**Locations**: 7 assertions

### Issue Location 1: Line 59

**BEFORE**:
```elixir
test "can call BAML function with multiple arguments" do
  # ... setup code ...

  # Verify content makes sense
  assert String.contains?(result.greeting, "Alice") or String.contains?(result.greeting, "30")
  assert result.age_category in ["child", "teen", "adult", "senior"]
  assert String.length(result.description) > 0
end
```

**AFTER**:
```elixir
test "can call BAML function with multiple arguments" do
  # ... setup code ...

  # Verify content makes sense
  assert String.contains?(result.greeting, "Alice") or String.contains?(result.greeting, "30"),
         "Expected greeting to contain either 'Alice' or '30', got: #{inspect(result.greeting)}"

  assert result.age_category in ["child", "teen", "adult", "senior"],
         "Expected age_category to be one of [child, teen, adult, senior], got: #{inspect(result.age_category)}"

  assert String.length(result.description) > 0,
         "Expected non-empty description, got: #{inspect(result.description)}"
end
```

### Issue Location 2: Line 80

**BEFORE**:
```elixir
assert result_with_location.location == "San Francisco"
```

**AFTER**:
```elixir
assert result_with_location.location == "San Francisco",
       "Expected location to be 'San Francisco', got: #{inspect(result_with_location.location)}"
```

### Issue Location 3: Line 96

**BEFORE**:
```elixir
assert is_nil(result_without_location.location)
```

**AFTER**:
```elixir
assert is_nil(result_without_location.location),
       "Expected location to be nil when not provided, got: #{inspect(result_without_location.location)}"
```

### Issue Location 4: Line 118

**BEFORE**:
```elixir
assert result.tag_count == length(tags)
```

**AFTER**:
```elixir
assert result.tag_count == length(tags),
       "Expected tag_count to be #{length(tags)}, got: #{result.tag_count}"
```

### Issue Location 5: Lines 156-159

**BEFORE**:
```elixir
assert String.length(result.formatted_address) > 0
assert result.distance_category in ["local", "regional", "international"]
```

**AFTER**:
```elixir
assert String.length(result.formatted_address) > 0,
       "Expected non-empty formatted_address, got: #{inspect(result.formatted_address)}"

assert result.distance_category in ["local", "regional", "international"],
       "Expected distance_category to be one of [local, regional, international], got: #{inspect(result.distance_category)}"
```

### Issue Location 6: Line 162

**BEFORE**:
```elixir
assert result.is_international == true
```

**AFTER**:
```elixir
assert result.is_international == true,
       "Expected is_international to be true (Canada is international), got: #{result.is_international}"
```

### Issue Location 7: Line 243

**BEFORE**:
```elixir
assert String.contains?(summary_lower, "ai") or
         String.contains?(summary_lower, "artificial")
```

**AFTER**:
```elixir
assert String.contains?(summary_lower, "ai") or
         String.contains?(summary_lower, "artificial"),
       "Expected summary to contain 'ai' or 'artificial', got: #{inspect(result.summary)}"
```

---

## Fix 3: Document Performance Test Limitations

**File**: `test/integration/performance_integration_test.exs`
**Severity**: WARNING
**Effort**: 10 minutes
**Locations**: 5 timing assertions

### Add Comment Block at Top of Test Module

**BEFORE**:
```elixir
defmodule AshBaml.PerformanceIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 120_000

  alias AshBaml.Test.TestResource

  describe "concurrency and performance" do
    test "10 concurrent calls all succeed" do
```

**AFTER**:
```elixir
defmodule AshBaml.PerformanceIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 120_000
  @moduletag :flaky

  # WARNING: Performance timing assertions in this module depend on:
  # - External OpenAI API latency (not controllable)
  # - Network conditions (variable in CI environments)
  # - CI system load and hardware performance (unpredictable)
  # - API rate limiting and throttling behavior
  #
  # These timing thresholds are INFORMATIONAL EXPECTATIONS, not hard SLAs.
  # Test failures due to timing may indicate performance issues, but can also
  # be caused by environmental factors outside code control.
  #
  # For CI environments, consider:
  # 1. Running these tests in a separate performance test job
  # 2. Setting lenient thresholds or skipping strict timing checks in CI
  # 3. Using time-series tracking to identify performance trends
  # 4. Investigating timing failures contextually with system metrics

  alias AshBaml.Test.TestResource

  describe "concurrency and performance" do
    test "10 concurrent calls all succeed" do
```

### Update Timing Assertions with Expanded Messages

**Line 71-72 BEFORE**:
```elixir
assert duration < 30_000,
       "10 concurrent calls took #{duration}ms, expected < 30000ms"
```

**Line 71-72 AFTER**:
```elixir
# Performance expectations - informational only, not hard SLA
# Environmental factors (API latency, network, CI load) may cause variance
assert duration < 30_000,
       "10 concurrent calls took #{duration}ms (expected < 30000ms for dev environment). " <>
       "Note: CI environments may see slower times due to network/hardware variance."
```

**Apply similar changes to lines 136-137, 205-206, 323, 349-350**

---

## Fix 4: Improve Streaming Test Skip Behavior

**File**: `test/integration/streaming_integration_test.exs`
**Severity**: WARNING
**Effort**: 5 minutes
**Location**: Lines 10-16

**BEFORE**:
```elixir
setup do
  # Ensure we have an API key for these tests
  unless System.get_env("OPENAI_API_KEY") do
    flunk("OPENAI_API_KEY environment variable must be set for streaming integration tests")
  end

  :ok
end
```

**AFTER**:
```elixir
setup do
  # Gracefully skip all tests if API key not configured
  case System.get_env("OPENAI_API_KEY") do
    nil ->
      {:skip, "OPENAI_API_KEY not set - skipping streaming integration tests"}
    _api_key ->
      :ok
  end
end
```

**Why This Change**:
- `flunk` makes the entire test module FAIL (shows as red in CI)
- `{:skip, reason}` makes tests SKIP (shows as yellow/skipped in CI)
- Much clearer intent: "These tests need an API key and were skipped, not failed"
- Allows CI to run without API keys without reporting false failures

---

## Fix 5: Improve Skipped Test Documentation

**File**: `test/integration/streaming_integration_test.exs`
**Severity**: WARNING
**Effort**: 5 minutes
**Location**: Lines 315-340

**BEFORE**:
```elixir
@tag :skip
test "stream raises exception on API errors" do
  # This test requires mocking BAML client to inject errors
  # Will be implemented when error injection is available
  # For now, skip to document expected behavior

  # Expected behavior:
  # - API error during streaming should raise exception
  # - Exception should be caught by Task
  # - Caller should receive {:error, exception} tuple

  flunk("Test requires mocking infrastructure - see comments for details")
end
```

**AFTER**:
```elixir
@tag :skip
test "stream raises exception on API errors" do
  # SKIPPED: Requires error injection infrastructure not yet available
  # BLOCKED_BY: BamlElixir client mocking/error injection support
  # IMPLEMENTED_WHEN: Mock infrastructure added to test setup
  #
  # Purpose: Verify that streaming API errors are properly propagated to caller
  # and don't cause hanging processes or silent failures.
  #
  # Success criteria when implemented:
  # 1. Inject error after N chunks arrive during streaming
  # 2. Verify exception is raised and surfaces to caller
  # 3. Verify stream cleanup (no hanging processes)
  # 4. Verify Task wrapper handles error correctly
  # 5. Verify caller receives {:error, reason} tuple in error context
  #
  # Related passing tests that provide indirect coverage:
  # - "stream handles missing required arguments" (line 496)
  # - "stream validates argument types" (line 504)
  # - "multiple concurrent streams work correctly" (line 244)
  #
  # Implementation notes:
  # - Use Mox or similar mock library to inject errors
  # - Create a test BAML client that fails after N chunks
  # - Verify error handling at both Stream and Task levels

  flunk("Test requires mocking infrastructure - see comments for implementation plan")
end
```

---

## Fix 6: Mark Flaky Tests with @tag :flaky

**File**: `test/integration/performance_integration_test.exs`
**Severity**: WARNING (already done for module - verify)
**Effort**: 1 minute

**Verify the module tag is already present** (it is, at line 5):

```elixir
defmodule AshBaml.PerformanceIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 120_000
  @moduletag :flaky  # This marks entire module as flaky
```

If individual tests need to be marked (instead of module-wide), add:

```elixir
test "memory usage is reasonable" do
  @tag :flaky
  # ... test code ...
end
```

But module-level `@moduletag :flaky` is preferred for this file since all tests have timing/environmental dependencies.

---

## Implementation Checklist

- [ ] Fix 1: Remove redundant error handling (3 locations, 5 min)
  - [ ] Line 42-48: Remove Enum.each block
  - [ ] Line 107-113: Remove Enum.each block
  - [ ] Line 175-181: Remove Enum.each block

- [ ] Fix 2: Add custom assertion messages (7 locations, 15 min)
  - [ ] Line 59: greeting assertion
  - [ ] Line 80: location assertion
  - [ ] Line 96: location nil assertion
  - [ ] Line 118: tag_count assertion
  - [ ] Line 159: distance_category assertion
  - [ ] Line 162: is_international assertion
  - [ ] Line 243: summary content assertion

- [ ] Fix 3: Document performance test limitations (10 min)
  - [ ] Add module-level comment explaining timing assertion limitations
  - [ ] Update 5 timing assertion messages with environment notes

- [ ] Fix 4: Improve streaming test skip behavior (5 min)
  - [ ] Change flunk to {:skip, reason} in setup block

- [ ] Fix 5: Improve skipped test documentation (5 min)
  - [ ] Expand documentation with implementation plan and criteria

- [ ] Fix 6: Verify @tag :flaky is present (1 min)
  - [ ] Confirm module-level @moduletag :flaky exists

**Total Estimated Time**: 45 minutes

---

## Testing Your Fixes

After implementing fixes, verify:

```bash
# Run the integration tests
mix test test/integration/ --include integration

# Run with warnings and tags
mix test test/integration/ --include integration --include flaky

# Run specific file to verify no syntax errors
mix test test/integration/baml_integration_test.exs
mix test test/integration/performance_integration_test.exs
mix test test/integration/streaming_integration_test.exs

# Run format check (no changes to code structure needed)
mix format test/integration/
```

---

## File Paths

```
/Users/bradleygolden/Development/bradleygolden/ash_baml/test/integration/baml_integration_test.exs
/Users/bradleygolden/Development/bradleygolden/ash_baml/test/integration/performance_integration_test.exs
/Users/bradleygolden/Development/bradleygolden/ash_baml/test/integration/streaming_integration_test.exs
```

---

## Next Steps

After implementing these fixes:

1. **Verify Tests Pass**: Run full test suite to ensure no regressions
2. **Commit Changes**: Create a focused commit with all fixes
3. **Update CI**: Consider configuring CI to handle @tag :flaky tests specially
4. **Consider Performance Baselines**: Set up monitoring for timing assertions to track performance trends
5. **Plan Error Injection**: Schedule implementation of Fix 5 (error injection testing) when mocking infrastructure is available

