# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `AshBaml.Response` wrapper struct that includes usage metadata alongside BAML function results
- Token usage tracking via `response.usage` containing `input_tokens`, `output_tokens`, and `total_tokens`
- `AshBaml.Response.unwrap/1` helper function for extracting data from wrapped responses
- `AshBaml.Response.usage/1` function for accessing usage metadata
- Integration support for observability systems like AshAgent's `response_usage/1`

### Changed

- **BREAKING**: All BAML function calls now return `{:ok, %AshBaml.Response{}}` instead of `{:ok, data}`
  - Access the original data via `response.data`
  - Access usage metadata via `response.usage`
  - Error responses remain unwrapped for backward compatibility
- `AshBaml.Telemetry.with_telemetry/4` now returns `{result, collector}` tuple internally

### Migration Guide

**Before:**
```elixir
{:ok, user} = MyApp.Extractor
  |> Ash.ActionInput.for_action(:extract_user, %{text: "Alice alice@example.com"})
  |> Ash.run_action()

IO.inspect(user.name)  # => "Alice"
```

**After:**
```elixir
{:ok, response} = MyApp.Extractor
  |> Ash.ActionInput.for_action(:extract_user, %{text: "Alice alice@example.com"})
  |> Ash.run_action()

user = response.data
IO.inspect(user.name)  # => "Alice"
IO.inspect(response.usage)  # => %{input_tokens: 10, output_tokens: 5, total_tokens: 15}
```

**Alternative - Using unwrap helper:**
```elixir
{:ok, response} = MyApp.Extractor |> Ash.ActionInput.for_action(...) |> Ash.run_action()
user = AshBaml.Response.unwrap(response)
```

**Error handling remains unchanged:**
```elixir
{:error, reason} = MyApp.Extractor |> Ash.ActionInput.for_action(...) |> Ash.run_action()
# Errors are NOT wrapped, so no changes needed
```
