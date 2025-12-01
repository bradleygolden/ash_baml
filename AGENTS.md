# AshBaml Dev Notes

- Use imperative mood for all git commits
- Never use @spec annotations unless absolutely necessary due to some bug in a client library or similar.
- Do not add new code comments when editing files. Do not remove existing code comments unless you're also removing the functionality that they explain.

## Tooling

- `mix precommit` runs the same sequence as GitHub CI (deps.get, deps.compile, unused-dependency check, compile with `--warnings-as-errors`, test suite with warnings treated as errors, formatter check, Credo, Sobelow, Dialyzer with GitHub formatting, and docs generation with warnings as errors) so it should be used locally before opening a PR.

## Testing Practices

- Unit tests MUST be deterministic. A test must either pass or fail consistently, not accept both outcomes.
- Never call `Process.sleep/1` in tests; prefer synchronization helpers so suites stay deterministic.
- Keep unit tests in `test/ash_baml`, mirroring `lib/` structure with `<filename>_test.exs`, and default to `async: true` when isolation is possible.
- Integration tests should use `@moduletag :integration` and run with `mix test --only integration`.

## Reference Reading

- https://www.anthropic.com/engineering/building-effective-agents
