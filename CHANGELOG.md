# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-11-26

### Added

- Initial release
- `AshBaml.Resource` extension for integrating BAML with Ash resources
- Auto-generated actions from BAML functions via `import_functions` DSL
- Streaming support with automatic stream cancellation when consumers exit
- Type generation from BAML schemas via `mix ash_baml.gen.types`
- `call_baml/1` helper for manual action definitions
- Support for union types in tool calling patterns
- Telemetry events for monitoring BAML function calls
- `mix ash_baml.install` task for quick project setup
- Config-driven BAML client setup with auto-generation at compile time
- Comprehensive documentation with tutorials, how-to guides, and topic guides

### Dependencies

- Requires Ash ~> 3.0
- Requires baml_elixir ~> 1.0.0-pre.23
- Requires Spark ~> 2.2
