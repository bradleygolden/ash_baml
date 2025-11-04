# BAML Implementation Plan: Mix Task Interface

**Date**: 2025-11-04
**Goal**: Create Mix task interface that mirrors Python/TypeScript BAML clients while maintaining Ash integration
**Challenge**: baml_elixir library is open source but not fully featured with slow turnaround

---

## Problem Statement

### Current State
- ✅ AshBaml provides BAML functions via Ash actions (unique approach)
- ✅ Basic setup via `mix ash_baml.install`
- ✅ Type generation via `mix ash_baml.gen.types`
- ⚠️ Depends on baml_elixir which is not fully featured
- ⚠️ Missing Python/TypeScript-like CLI experience

### Core Challenge
> "The underlying BAML Elixir library is open source, but it's not fully featured, and there's going to be a slow turnaround for supporting certain functionality"

**Question**: How do we handle missing functionality in baml_elixir?

### Design Goal
Create Mix task interface that:
1. Mirrors Python/TypeScript BAML client experience
2. Is idiomatic to Elixir
3. Maintains Ash action integration (the differentiator)
4. Can extend/fork baml_elixir as needed

---

## Strategic Options for baml_elixir Dependency

### Option 1: Fork & Maintain Aggressively

**Approach**: Create bradleygolden/baml_elixir fork and add features as needed

**Pros**:
- ✅ Full control over features and timeline
- ✅ Can add Elixir-specific optimizations
- ✅ Fast iteration on missing functionality
- ✅ No waiting for upstream

**Cons**:
- ❌ Maintenance burden of keeping up with upstream BAML
- ❌ Need Rust expertise
- ❌ Community fragmentation

**When to Use**: If we need features quickly and have Rust expertise

### Option 2: Contribute Upstream + Temporary Patches

**Approach**: Contribute to emilsoman/baml_elixir, use temporary patches for urgent needs

**Pros**:
- ✅ Community benefits
- ✅ Less long-term maintenance
- ✅ Upstream does heavy lifting

**Cons**:
- ⚠️ Slower turnaround (the stated problem)
- ⚠️ Depends on maintainer responsiveness
- ⚠️ May need to maintain patches for extended periods

**When to Use**: If missing features are non-critical or we can wait

### Option 3: Wrapper Layer (Recommended)

**Approach**: Create abstraction layer in ash_baml that wraps baml_elixir and adds missing functionality

**Strategy**:
```elixir
# In ash_baml
defmodule AshBaml.BamlRuntime do
  @moduledoc """
  Runtime layer that wraps baml_elixir and adds missing functionality.

  When baml_elixir is missing features:
  1. Implement workaround here
  2. File issue upstream
  3. Gradually remove workarounds as upstream adds features
  """

  def call_function(client, function, args, opts) do
    # Try native baml_elixir first
    # Fall back to workarounds if needed
  end

  def parse_schema(path) do
    # Add validation/features missing from baml_elixir
  end
end
```

**Pros**:
- ✅ Decouples ash_baml from baml_elixir limitations
- ✅ Can add features without forking
- ✅ Gradual migration as upstream improves
- ✅ Clear separation of concerns

**Cons**:
- ⚠️ Some duplication of effort
- ⚠️ May not be possible for all missing features (especially Rust NIF-level)

**When to Use**: For Elixir-level functionality gaps

### Option 4: Full Integration (Nuclear Option)

**Approach**: Pull entire BAML Rust codebase into ash_baml as git submodule

**Only if**:
- baml_elixir becomes abandoned
- Critical blocking features need Rust-level changes
- Team has Rust expertise

**Not recommended initially** due to complexity

---

## Recommended Strategy: Hybrid Wrapper Approach

### Phase 0: Dependency Management

**Immediate Actions**:

1. **Create fork** of emilsoman/baml_elixir at bradleygolden/baml_elixir
   - Even if empty initially
   - Gives control over dependency

2. **Document known limitations** of baml_elixir
   ```markdown
   ## Known Limitations in baml_elixir

   - [ ] Missing feature X
   - [ ] Missing feature Y
   - Workarounds: See AshBaml.BamlRuntime
   ```

3. **Create abstraction layer** in ash_baml
   ```elixir
   defmodule AshBaml.BamlRuntime
   defmodule AshBaml.BamlCompiler
   defmodule AshBaml.BamlValidator
   ```

### Phase 1: Mix Task Interface (MVP)

**Goal**: Mirror Python/TypeScript CLI with Mix tasks

#### Task 1: `mix baml.init`

**Usage**:
```bash
mix baml.init --path baml_src
mix baml.init --path baml_src --generator elixir
```

**Creates**:
```
baml_src/
├── generators.baml    # Generator configuration
├── clients.baml       # LLM clients
└── main.baml          # Example function
```

**Implementation**:
```elixir
defmodule Mix.Tasks.Baml.Init do
  @shortdoc "Initialize a BAML project (mirrors baml-cli init)"

  def run(args) do
    # Parse args
    # Create baml_src directory
    # Create generators.baml
    # Create clients.baml
    # Create example function file
    # Output next steps
  end
end
```

#### Task 2: `mix baml.generate`

**Usage**:
```bash
mix baml.generate                    # Generate all
mix baml.generate --client support   # Generate one client
mix baml.generate --watch            # Watch mode (optional)
```

**Functionality**:
- Parse BAML schema
- Generate Elixir types
- Validate generated code
- Report any issues

**Implementation**:
```elixir
defmodule Mix.Tasks.Baml.Generate do
  @shortdoc "Generate Elixir types from BAML schemas (mirrors baml-cli generate)"

  def run(args) do
    # Load configuration
    # For each configured client:
    #   - Parse BAML schema
    #   - Generate types using AshBaml.TypeGenerator
    #   - Write to disk
    #   - Validate
    # Report results
  end
end
```

#### Task 3: `mix baml.validate`

**Usage**:
```bash
mix baml.validate
mix baml.validate --path baml_src
```

**Checks**:
- Parse errors
- Type consistency
- Client references
- Duplicate names

**Implementation**:
```elixir
defmodule Mix.Tasks.Baml.Validate do
  @shortdoc "Validate BAML schemas"

  def run(args) do
    # Parse all .baml files
    # Run validations via AshBaml.BamlValidator
    # Report errors with line numbers
  end
end
```

### Phase 2: Enhanced AshBaml Integration

**Goal**: Make Ash actions even better while keeping Mix tasks

#### Dual Interface Pattern

**Mix Tasks** (Python/TypeScript-like):
```bash
mix baml.init
mix baml.generate
mix baml.validate
```

**Ash Actions** (AshBaml differentiator):
```elixir
defmodule MyApp.Assistant do
  use Ash.Resource, extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:ExtractUser, :AnalyzeTicket]
  end
end

# Use via Ash
MyApp.Assistant.extract_user!(%{text: "..."})
```

**Both paths supported**:
- Mix tasks for development/tooling
- Ash actions for runtime usage

### Phase 3: Wrapper Layer for Missing Features

**Goal**: Handle baml_elixir limitations gracefully

**Architecture**:
```elixir
defmodule AshBaml.BamlRuntime do
  @moduledoc """
  Runtime wrapper around baml_elixir.

  Provides consistent API and fills gaps in baml_elixir functionality.
  """

  @doc "Call BAML function with fallback handling"
  def call_function(client, function, args, opts) do
    case BamlElixir.Native.call_function(client, function, args, opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, :unsupported_feature} ->
        # Implement workaround
        workaround_call_function(client, function, args, opts)

      error ->
        error
    end
  end

  @doc "Parse BAML with enhanced validation"
  def parse_schema(path) do
    # Call baml_elixir
    case BamlElixir.Native.parse_baml(path) do
      baml when is_map(baml) ->
        # Add additional validation
        validate_and_enhance(baml)

      error ->
        error
    end
  end

  defp validate_and_enhance(baml) do
    # Add validations missing from baml_elixir
    # Return enhanced schema
  end
end
```

**Features to Add**:
- Schema validation beyond what baml_elixir provides
- Better error messages
- Elixir-specific optimizations
- Workarounds for missing baml_elixir features

---

## Implementation Roadmap

### Sprint 1: Foundation (1 week)

**Goals**:
- Create fork of baml_elixir (even if initially empty)
- Set up wrapper layer architecture
- Document known limitations

**Tasks**:
- [ ] Fork emilsoman/baml_elixir to bradleygolden/baml_elixir
- [ ] Update mix.exs to point to fork
- [ ] Create AshBaml.BamlRuntime module
- [ ] Create AshBaml.BamlValidator module
- [ ] Document baml_elixir limitations in README

**Deliverables**:
- Fork exists and is referenced
- Wrapper layer scaffold in place
- Known limitations documented

### Sprint 2: Mix Task MVP (1 week)

**Goals**:
- Implement core Mix tasks
- Mirror Python/TypeScript CLI

**Tasks**:
- [ ] Implement `mix baml.init`
- [ ] Implement `mix baml.generate`
- [ ] Implement `mix baml.validate`
- [ ] Update documentation with Mix task usage
- [ ] Create migration guide from current approach

**Deliverables**:
- Working Mix tasks
- Documentation
- Migration guide

### Sprint 3: Wrapper Layer Features (1 week)

**Goals**:
- Add missing functionality
- Improve error handling

**Tasks**:
- [ ] Identify top 3 missing features in baml_elixir
- [ ] Implement workarounds in BamlRuntime
- [ ] Add enhanced validation
- [ ] Improve error messages
- [ ] Write tests for wrapper layer

**Deliverables**:
- Functional workarounds for missing features
- Better error messages
- Test coverage

### Sprint 4: Integration & Polish (1 week)

**Goals**:
- Seamless developer experience
- Production-ready

**Tasks**:
- [ ] Integrate Mix tasks with existing ash_baml.install
- [ ] Add --watch mode to baml.generate (optional)
- [ ] Create example projects
- [ ] Write comparison docs (Python/TS → Elixir)
- [ ] Video walkthrough

**Deliverables**:
- Complete developer experience
- Example projects
- Comprehensive documentation

---

## Handling Missing baml_elixir Features

### Decision Framework

**When you discover missing functionality:**

1. **Assess Level**:
   - Elixir-level? → Implement in AshBaml.BamlRuntime
   - Rust NIF-level? → Needs fork or upstream contribution
   - BAML core? → Needs upstream BAML update

2. **Urgency**:
   - **Critical**: Implement workaround + file upstream issue
   - **Important**: File issue, plan contribution
   - **Nice-to-have**: File issue, wait for upstream

3. **Implementation**:
   - **Workaround**: Add to BamlRuntime with clear comments
   - **Fork**: Add to bradleygolden/baml_elixir with upstream PR
   - **Wait**: Document limitation in README

### Example: Missing Streaming Feature

**Scenario**: baml_elixir doesn't support streaming with timeout

**Solution**:
```elixir
defmodule AshBaml.BamlRuntime do
  def stream_function_with_timeout(client, function, args, timeout) do
    # Workaround using Task and receive
    task = Task.async(fn ->
      BamlElixir.Native.stream_function(client, function, args)
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> {:ok, result}
      nil -> {:error, :timeout}
    end
  end
end
```

**Document**:
```markdown
## Workarounds

### Streaming with Timeout
- **Issue**: baml_elixir doesn't support timeout on streams
- **Workaround**: AshBaml.BamlRuntime.stream_function_with_timeout/4
- **Upstream Issue**: #123 in baml_elixir
- **Status**: Waiting for upstream
```

---

## Mix Task Interface Specification

### `mix baml.init`

**Purpose**: Initialize BAML project (mirrors `baml-cli init`)

**Usage**:
```bash
mix baml.init [OPTIONS]
```

**Options**:
- `--path PATH` - BAML source directory (default: baml_src)
- `--generator TYPE` - Generator type (default: elixir)
- `--client CLIENT` - Initial client name (default: default)

**Creates**:
```
baml_src/
├── generators.baml    # Code generation config
├── clients.baml       # LLM client configs
└── main.baml          # Example function
```

**Output**:
```
🎉 BAML project initialized!

Created:
  baml_src/generators.baml
  baml_src/clients.baml
  baml_src/main.baml

Next steps:
  1. Edit baml_src/clients.baml with your API keys
  2. Run: mix baml.generate
  3. Use in your Ash resources
```

### `mix baml.generate`

**Purpose**: Generate Elixir types from BAML (mirrors `baml-cli generate`)

**Usage**:
```bash
mix baml.generate [OPTIONS]
```

**Options**:
- `--client CLIENT` - Generate specific client only
- `--watch` - Watch mode (regenerate on file changes)
- `--verbose` - Detailed output
- `--dry-run` - Preview without writing

**Behavior**:
1. Reads config from generators.baml or config.exs
2. Parses all .baml files
3. Generates Elixir TypedStruct modules
4. Validates generated code
5. Reports results

**Output**:
```
Generating BAML client: default
  Source: baml_src/
  Output: lib/my_app/baml_client/types/

Found:
  Functions: 3
  Classes: 5
  Enums: 2

Generated:
  ✓ lib/my_app/baml_client/types/user.ex
  ✓ lib/my_app/baml_client/types/ticket.ex
  ...

✓ Successfully generated 7 modules
```

### `mix baml.validate`

**Purpose**: Validate BAML schemas

**Usage**:
```bash
mix baml.validate [OPTIONS]
```

**Options**:
- `--path PATH` - BAML source directory
- `--strict` - Fail on warnings

**Checks**:
- ✅ Syntax errors
- ✅ Type consistency
- ✅ Client references
- ✅ Duplicate names
- ✅ Environment variables

**Output**:
```
Validating BAML schemas in baml_src/

✓ clients.baml - OK
✓ main.baml - OK
⚠ functions.baml:23 - Unused type: OldUser

Summary:
  Files: 3
  Errors: 0
  Warnings: 1

✓ BAML schemas are valid
```

---

## Integration with Existing ash_baml.install

**Strategy**: Keep both, make them work together

### Option A: Deprecate ash_baml.install

**Replace** `mix ash_baml.install` with:
```bash
mix baml.init && mix baml.generate
```

**Pros**: Simpler, more aligned with Python/TS
**Cons**: Breaking change for existing users

### Option B: Wrap (Recommended)

**Update** `mix ash_baml.install` to call new tasks:
```elixir
defmodule Mix.Tasks.AshBaml.Install do
  def run(args) do
    # Parse args
    Mix.Task.run("baml.init", init_args)
    Mix.Task.run("baml.generate", gen_args)
    # Add to config.exs
  end
end
```

**Pros**: Backward compatible, high-level convenience
**Cons**: Slightly more complex

### Option C: Coexist

Keep both:
- `mix baml.*` - Low-level, mirrors Python/TS
- `mix ash_baml.install` - High-level, Ash-specific setup

**This is the recommended approach**: Provides both interfaces

---

## Example Workflow Comparison

### Python/TypeScript (Current)

```bash
# Python
pip install baml-py
baml-cli init
# Edit baml_src/*.baml
baml-cli generate
python main.py

# TypeScript
npm install @boundaryml/baml
npx baml-cli init
# Edit baml_src/*.baml
npx baml-cli generate
npm run dev
```

### AshBaml (Proposed)

```bash
# Add to mix.exs
# {:ash_baml, github: "bradleygolden/ash_baml"}

mix deps.get
mix baml.init
# Edit baml_src/*.baml
mix baml.generate

# Use in Ash resource
# MyApp.Assistant.extract_user!(...)
```

**Side-by-side**:

| Step | Python/TS | AshBaml (Proposed) |
|------|-----------|---------------------|
| Install | `pip install` / `npm install` | `mix deps.get` |
| Init | `baml-cli init` | `mix baml.init` |
| Edit | Edit `.baml` files | Edit `.baml` files |
| Generate | `baml-cli generate` | `mix baml.generate` |
| Use | Direct function calls | Ash actions + direct calls |

**Key Difference**: AshBaml adds Ash action integration layer on top

---

## Success Criteria

### Developer Experience

- [ ] Init project in < 1 minute
- [ ] Generate types in < 5 seconds
- [ ] Clear error messages with line numbers
- [ ] Documentation at Python/TypeScript parity

### Feature Completeness

- [ ] All core BAML features supported
- [ ] Workarounds for baml_elixir limitations
- [ ] Streaming support
- [ ] Multiple clients

### Production Ready

- [ ] Test coverage > 80%
- [ ] Documented deployment process
- [ ] Error handling
- [ ] Telemetry integration

### Community

- [ ] Migration guide from manual setup
- [ ] Comparison with Python/TypeScript
- [ ] Example projects
- [ ] Video walkthrough

---

## Risk Mitigation

### Risk: baml_elixir becomes stale

**Mitigation**:
- Maintain fork with active development
- Wrapper layer abstracts baml_elixir API
- Plan for full integration if needed (Option 4)

### Risk: BAML upstream breaking changes

**Mitigation**:
- Pin BAML version in fork
- Test suite catches breaks
- Gradual migration path

### Risk: Rust compilation issues

**Mitigation**:
- Pre-built NIFs for common platforms
- Clear deployment documentation
- Docker examples

### Risk: Community confusion (two ways to use)

**Mitigation**:
- Clear documentation on Mix tasks vs Ash actions
- Both are valid, serve different purposes
- Examples for each approach

---

## Next Steps

### Immediate (This Week)

1. **Create fork**: bradleygolden/baml_elixir
2. **Scaffold Mix tasks**: Empty implementations
3. **Document limitations**: Known gaps in baml_elixir
4. **Plan wrapper layer**: Identify first workarounds needed

### Short-term (Next 2 Weeks)

1. **Implement `mix baml.init`**: Working MVP
2. **Implement `mix baml.generate`**: Integration with existing type gen
3. **Implement `mix baml.validate`**: Basic validation
4. **Write documentation**: Migration guide + comparison

### Medium-term (Next Month)

1. **Wrapper layer**: Implement workarounds for missing features
2. **Enhanced validation**: Better error messages
3. **Example projects**: Show both approaches
4. **Community feedback**: Gather input, iterate

### Long-term (Next Quarter)

1. **Evaluate baml_elixir**: Contribute upstream or maintain fork?
2. **Consider full integration**: Is Option 4 needed?
3. **Advanced features**: Watch mode, LSP integration
4. **Production hardening**: Based on real usage

---

## Conclusion

**The Path Forward**:

1. ✅ **Create Mix task interface** that mirrors Python/TypeScript
2. ✅ **Maintain Ash action integration** as the differentiator
3. ✅ **Build wrapper layer** to handle baml_elixir limitations
4. ✅ **Fork baml_elixir** for control over timeline
5. ✅ **Keep options open** for full integration later if needed

**Key Insight**:
> AshBaml's Ash action integration is the killer feature. Mix tasks provide the familiar CLI experience. Both together create the best of both worlds.

**The Answer** to "how to deal with baml_elixir limitations":
- **Short-term**: Wrapper layer with workarounds
- **Medium-term**: Fork and add features
- **Long-term**: Contribute upstream or full integration

This approach balances pragmatism (use what exists), control (fork when needed), and long-term flexibility (can go full integration if required).

---

**Ready to implement?** Start with Sprint 1 tasks above. 🚀
