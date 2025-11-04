# BAML Integration Investigation

**Date**: 2025-11-04
**Investigator**: Claude (via Ralph loop investigation)
**Goal**: Investigate how to emulate Python/JavaScript BAML clients in Elixir and evaluate pulling all BAML logic (including Rust NIFs) into ash_baml

---

## Executive Summary

BAML is a prompt engineering language that compiles into type-safe client code for multiple languages. Python and TypeScript clients use `baml-cli` for project initialization and code generation. AshBaml currently wraps the `baml_elixir` fork which provides Rust NIF bindings to the BAML parser, but lacks the seamless CLI experience of other language implementations.

**Key Recommendation**: Create Elixir-idiomatic equivalents of `baml-cli init` and `baml-cli generate` using Mix tasks that leverage the existing Rust NIF infrastructure.

---

## 1. BAML Architecture Overview

### Core Components

1. **BAML Language**: Domain-specific language for defining LLM prompts as typed functions
2. **Rust Compiler/Engine**: Core compilation engine in `BoundaryML/baml` repository
3. **Language Bindings**: Language-specific clients (Python, TypeScript, Ruby, Go, etc.)
4. **CLI Tool**: `baml-cli` for project initialization and code generation

### Design Philosophy (from README)

> "Any file editor and any terminal should be enough to use it."

- Plain text `.baml` files
- Version-controlled via Git
- No cloud dependency
- Schema-Aligned Parsing (SAP) achieves 91-94% accuracy

### Project Structure (Python/TypeScript)

```
project/
├── baml_src/              # BAML source files
│   ├── generators.baml    # Code generation config
│   ├── clients.baml       # LLM client configurations
│   └── *.baml            # Functions and types
└── baml_client/          # Generated code (auto-generated)
    ├── async_client.py   # Python async client
    ├── sync_client.py    # Python sync client
    └── types/            # Generated types (Pydantic models)
```

---

## 2. Python Client Implementation

### Installation & Setup

```bash
pip install baml-py
baml-cli init  # Creates baml_src/ with starter files
baml-cli generate  # Generates baml_client/ directory
```

### Architecture

- **CLI**: `baml-cli` handles project initialization and code generation
- **Runtime**: `baml-py` package provides the runtime library
- **Generated Code**: Creates `baml_client/` with:
  - Async client for Python asyncio
  - Sync client for synchronous calls
  - Pydantic models for all BAML classes/enums
- **Rust Integration**: Uses PyO3 for Python-Rust bindings

### Key Features

- Type-safe function calls
- Streaming support
- Pydantic models for validation
- Full async/await support

---

## 3. TypeScript/JavaScript Client Implementation

### Installation & Setup

```bash
npm install @boundaryml/baml
npx baml-cli init
npx baml-cli generate
```

### Architecture

- **CLI**: `baml-cli` (same as Python)
- **Runtime**: `@boundaryml/baml` npm package
- **Generated Code**: Creates `baml_client/` with:
  - Async client (default)
  - Sync client (`./baml_client/sync_client`)
  - TypeScript interfaces for all types
- **Rust Integration**: Uses NAPI-RS for Node.js-Rust bindings
- **Configuration**: Supports ESM/CommonJS via `module_format` option

### Key Features

- Full TypeScript type safety
- Streaming support
- ESM/CommonJS compatibility
- ~30ms compilation time

---

## 4. Current AshBaml Implementation

### Architecture

**Dependencies**:
- `baml_elixir` (fork at `bradleygolden/baml_elixir`) - Rust NIF wrapper
- `rustler` - Rust NIF build tooling
- `ash` - Resource/action framework

**Current Capabilities**:
1. ✅ Parse BAML schemas via `BamlElixir.Native.parse_baml/1`
2. ✅ Generate Elixir TypedStruct modules via `mix ash_baml.gen.types`
3. ✅ Call BAML functions via `BamlElixir.Client`
4. ✅ Streaming support
5. ✅ Config-driven client setup via `mix ash_baml.install`
6. ✅ Auto-generate Ash actions from BAML functions

### What's Different from Python/TypeScript

| Feature | Python/TypeScript | AshBaml (Current) |
|---------|-------------------|-------------------|
| CLI init command | `baml-cli init` | `mix ash_baml.install` |
| Client generation | `baml-cli generate` | Handled by `use BamlElixir.Client` macro |
| Type generation | Auto-generated with client | Manual: `mix ash_baml.gen.types` |
| Runtime execution | Direct function calls | Through Ash actions |
| Streaming | Native streaming | Ash.Type.Stream wrapper |
| Multiple clients | Via config files | Via Elixir config |

### Current Project Structure

```
ash_baml/
├── baml_src/              # User's BAML source (via mix task)
│   ├── clients.baml
│   └── *.baml
├── lib/
│   ├── my_app/
│   │   └── baml_client/
│   │       └── types/     # Generated via mix ash_baml.gen.types
│   │           ├── user.ex
│   │           └── *.ex
│   └── my_resource.ex     # Ash resource with baml do ... end
```

---

## 5. The baml_elixir Fork

### Current Usage

```elixir
# mix.exs
{:baml_elixir,
 git: "https://github.com/bradleygolden/baml_elixir.git",
 branch: "main",
 override: true}
```

**Note**: GitHub search shows no public repository at `bradleygolden/baml_elixir`. This could be:
1. A private repository
2. Not yet created (user planning to fork)
3. Actually referring to `emilsoman/baml_elixir`

### emilsoman/baml_elixir (Original)

**Architecture**:
- Rust NIF in `native/baml_elixir/`
- Git submodule to `BoundaryML/baml` Rust library
- `BamlElixir.Client` macro for module generation
- `BamlElixir.Native` module for NIF functions

**Key Functions**:
- `BamlElixir.Native.parse_baml/1` - Parse BAML files
- `BamlElixir.Native.call_function/4` - Call BAML functions
- `BamlElixir.Native.stream_function/4` - Streaming calls

**Status**: Pre-release (v1.0.0-pre.23)

---

## 6. What Would "Pulling BAML Into Project" Entail?

### Option A: Full Integration (Pull Everything)

**What This Means**:
Incorporate the entire Rust BAML compiler/engine into ash_baml, eliminating the external dependency.

**Required Steps**:

1. **Git Submodule**:
   ```bash
   git submodule add https://github.com/BoundaryML/baml.git native/baml
   ```

2. **Rust NIF Structure**:
   ```
   ash_baml/
   ├── native/
   │   └── ash_baml_nif/
   │       ├── Cargo.toml
   │       ├── src/
   │       │   └── lib.rs
   │       └── baml/  (git submodule)
   ```

3. **Rustler Integration**:
   - Add Rustler dependency
   - Create NIF wrapper functions
   - Handle Rust compilation in mix.exs

4. **NIF Functions Needed**:
   - `parse_baml(path)` - Parse schema
   - `call_function(fn_name, args, client, options)` - Execute function
   - `stream_function(...)` - Streaming execution
   - `validate_schema(path)` - Schema validation

**Pros**:
- ✅ Complete control over BAML integration
- ✅ No external dependency on baml_elixir fork
- ✅ Can customize/extend Rust functionality
- ✅ Single repository for everything

**Cons**:
- ❌ Large maintenance burden (keeping up with BAML upstream)
- ❌ Complex Rust NIF development required
- ❌ Deployment complexity (Rust compilation needed)
- ❌ Duplicate effort with baml_elixir

### Option B: Enhanced Fork (Current + Improvements)

**What This Means**:
Continue using baml_elixir but contribute improvements back or maintain enhanced fork.

**Improvements to Add**:

1. **Elixir-Idiomatic Mix Tasks**:
   - `mix baml.init` (like `baml-cli init`)
   - `mix baml.generate` (explicit generation)
   - `mix baml.validate` (schema validation)

2. **Generator.baml Support**:
   Add support for `generators.baml` configuration:
   ```baml
   generator elixir {
     output_type elixir/ash
     output_dir lib/my_app/baml_client
     module_prefix MyApp.BamlClient
   }
   ```

3. **Enhanced Type Generation**:
   - Auto-generate on BAML file changes (file watcher)
   - Support for dynamic types
   - Better enum handling

**Pros**:
- ✅ Leverages existing baml_elixir work
- ✅ Smaller maintenance burden
- ✅ Can contribute improvements upstream
- ✅ Focus on Elixir-specific enhancements

**Cons**:
- ⚠️ Still depends on external repository
- ⚠️ Limited by baml_elixir's API

### Option C: Hybrid Approach (Recommended)

**What This Means**:
Use baml_elixir for low-level Rust bindings, but add comprehensive Elixir tooling in ash_baml.

**Implementation**:

1. **Keep baml_elixir dependency** for Rust NIF layer
2. **Add CLI-equivalent Mix tasks** in ash_baml:
   - `mix ash_baml.init` (enhanced version of current install)
   - `mix ash_baml.generate` (explicit type generation)
   - `mix ash_baml.validate` (schema validation)
3. **Create Elixir-idiomatic client generation**
4. **File watcher for development** (optional)

**Pros**:
- ✅ Best of both worlds
- ✅ Elixir-idiomatic experience
- ✅ Minimal maintenance burden
- ✅ Can transition to Option A later if needed

---

## 7. Blockers & Challenges Encountered

### GitHub Access Issues

**Blocker**: Cannot verify bradleygolden/baml_elixir repository status
- Public search shows no repository at this URL
- Could be private repository
- May not exist yet

**Impact**: Cannot analyze current fork modifications or contribute improvements

**Workaround**: Use emilsoman/baml_elixir as reference

### Missing BAML CLI Equivalent

**Challenge**: No Elixir equivalent of `baml-cli`
- Python/TypeScript: `baml-cli init` creates full project structure
- AshBaml: `mix ash_baml.install` only creates basic files

**Gap Analysis**:
| Feature | baml-cli | ash_baml |
|---------|----------|----------|
| Create baml_src/ | ✅ | ✅ |
| Create generators.baml | ✅ | ❌ |
| Create example functions | ✅ | ✅ (partial) |
| Generate client code | ✅ | ⚠️ (implicit) |
| Validate schema | ✅ | ❌ |
| Watch mode | ✅ | ❌ |

### Type Generation Friction

**Challenge**: Two-step process for types
1. Define BAML schema
2. Run `mix ash_baml.gen.types`

**Python/TypeScript**: Single `baml-cli generate` command creates client + types

**Elixir**: Separated because:
- BAML client generation happens at compile time (via macro)
- Type generation is optional (for Ash integration)

**Improvement**: Could unify under `mix ash_baml.generate`

### Rust Compilation Complexity

**Challenge**: Deployment requires Rust toolchain
- First compile: several minutes
- Requires cargo in PATH
- Platform-specific precompiled NIFs help, but not always available

**Python/TypeScript**: Pre-built wheels/packages available via pip/npm

**Mitigation**:
- rustler_precompiled can handle prebuilt NIFs
- GitHub Actions can build releases
- Documented in DEPLOYMENT.md

### Generator.baml Not Supported

**Challenge**: BAML's `generators.baml` configuration not utilized
```baml
generator python {
  output_type python/pydantic
  output_dir ../baml_client
}
```

**Current State**: AshBaml ignores this file
- Client path configured in Elixir code
- No generator-level configuration

**Impact**: Less consistency with other BAML ecosystems

---

## 8. Emulating Python/JavaScript Clients: Implementation Plan

### Goal
Create an Elixir experience that feels as seamless as Python/TypeScript while remaining idiomatic to Elixir/Ash.

### Phase 1: Enhanced Project Initialization

**New Mix Task**: `mix ash_baml.init`

```bash
mix ash_baml.init --client support --path baml_src
```

**Creates**:
```
baml_src/
├── generators.baml      # NEW: Generator configuration
├── clients.baml         # LLM client configs
└── example.baml         # Example functions
```

**generators.baml** content:
```baml
generator elixir {
  output_type elixir/ash
  output_dir lib/my_app/baml_clients/support/types
  module_prefix MyApp.BamlClients.Support
}
```

**Changes to existing install task**:
- Create generators.baml
- More comprehensive examples
- Interactive prompts for API keys (optional)

### Phase 2: Unified Client Generation

**New Mix Task**: `mix ash_baml.generate`

```bash
# Generate all configured clients
mix ash_baml.generate

# Generate specific client
mix ash_baml.generate --client support

# Watch mode (regenerate on .baml changes)
mix ash_baml.generate --watch
```

**Functionality**:
1. Parse generators.baml (if present)
2. Generate types to configured location
3. Validate generated modules
4. Report any errors

**Implementation**:
```elixir
defmodule Mix.Tasks.AshBaml.Generate do
  def run(args) do
    # Parse options
    # Load all configured clients
    # For each client:
    #   - Parse BAML schema
    #   - Generate types
    #   - Validate
    # Report results
  end
end
```

### Phase 3: Schema Validation

**New Mix Task**: `mix ash_baml.validate`

```bash
mix ash_baml.validate
```

**Checks**:
- ✅ All .baml files parse correctly
- ✅ No duplicate class/function names
- ✅ All client references exist
- ✅ Type references are valid
- ✅ Required environment variables documented

### Phase 4: Development Workflow Improvements

**File Watcher** (Optional):
```bash
mix ash_baml.watch
```
- Watches baml_src/ for changes
- Auto-regenerates types on save
- Shows validation errors in real-time

**VSCode Extension Integration**:
- Language server support (may need to wrap BAML's LSP)
- Syntax highlighting
- Go-to-definition

### Phase 5: Client API Improvements

**Goal**: More Pythonic/TypeScript-like API while staying idiomatic

**Current**:
```elixir
MyResource
|> Ash.ActionInput.for_action(:extract_user, %{text: "..."})
|> Ash.run_action()
```

**Enhanced** (optional convenience):
```elixir
# Direct client access (like Python/TS)
MyApp.BamlClient.ExtractUser.call(%{text: "..."})
MyApp.BamlClient.ExtractUser.stream(%{text: "..."})

# Still supports Ash actions
MyResource.extract_user!(%{text: "..."})
```

**Implementation**:
- Add convenience functions to generated client modules
- Keep Ash action integration as primary path
- Document both approaches

### Phase 6: Documentation Parity

**Add Documentation**:
1. "Coming from Python" guide
2. "Coming from TypeScript" guide
3. Side-by-side comparison examples
4. Migration guide from baml_elixir

---

## 9. Detailed Implementation Roadmap

### Stage 1: Foundation (Week 1)

**Tasks**:
- [ ] Create `mix ash_baml.init` task
- [ ] Add generators.baml creation
- [ ] Parse generators.baml in BamlParser
- [ ] Update install task documentation

**Deliverables**:
- Working `mix ash_baml.init` command
- Generated projects include generators.baml
- Documentation updated

### Stage 2: Unified Generation (Week 2)

**Tasks**:
- [ ] Create `mix ash_baml.generate` task
- [ ] Support reading generators.baml config
- [ ] Integrate with existing type generation
- [ ] Add --watch flag support (optional)

**Deliverables**:
- Single command generates all types
- Respects generators.baml configuration
- Clear error messages

### Stage 3: Validation (Week 3)

**Tasks**:
- [ ] Create `mix ash_baml.validate` task
- [ ] Add schema validation via NIF
- [ ] Check for common errors
- [ ] Integration with compile step

**Deliverables**:
- Validation command catches errors early
- Helpful error messages
- Optional: integrate with mix compile

### Stage 4: Polish & Documentation (Week 4)

**Tasks**:
- [ ] Comparison guides
- [ ] Migration documentation
- [ ] Example projects
- [ ] Video walkthrough

**Deliverables**:
- Comprehensive documentation
- Example repositories
- Clear migration path

---

## 10. Decision Matrix: Which Approach?

### Evaluation Criteria

| Criterion | Option A (Full) | Option B (Fork) | Option C (Hybrid) |
|-----------|----------------|-----------------|-------------------|
| **Development Effort** | ⚠️ High | ✅ Low | ✅ Medium |
| **Maintenance Burden** | ❌ Very High | ⚠️ Medium | ✅ Low |
| **Control** | ✅ Complete | ⚠️ Limited | ✅ Good |
| **Time to Market** | ❌ 3-6 months | ✅ 2-4 weeks | ✅ 1-2 months |
| **Upstream Compatibility** | ⚠️ Manual sync | ✅ Easy sync | ✅ Easy sync |
| **Learning Curve** | ❌ High (Rust) | ✅ Low | ✅ Low |
| **Deployment Complexity** | ❌ High | ✅ Medium | ✅ Medium |

### Recommendation: Option C (Hybrid)

**Rationale**:
1. **Pragmatic**: Leverages existing work in baml_elixir
2. **Elixir-Idiomatic**: Add Mix tasks for seamless DX
3. **Maintainable**: Focus on Elixir layer, not Rust internals
4. **Future-Proof**: Can transition to Option A later if needed
5. **Quick Wins**: Can deliver value in 1-2 months

**Next Steps**:
1. Implement Phase 1: Enhanced initialization
2. Implement Phase 2: Unified generation
3. Gather user feedback
4. Decide if Option A is needed based on limitations

---

## 11. Open Questions

1. **Repository Access**: Is bradleygolden/baml_elixir private or not yet created?
2. **Fork Strategy**: Should we fork emilsoman/baml_elixir or create fresh?
3. **Upstream Contributions**: Can we contribute improvements to emilsoman/baml_elixir?
4. **BAML Version Pinning**: Which BAML version should we target?
5. **Generator.baml Schema**: Is there official documentation for generator configuration?
6. **VSCode Extension**: Should we wrap BAML's language server or create new?

---

## 12. Resources & References

### Official BAML Resources
- Main Repository: https://github.com/BoundaryML/baml
- Documentation: https://docs.boundaryml.com
- README: https://raw.githubusercontent.com/BoundaryML/baml/refs/heads/canary/README.md

### Elixir Ecosystem
- baml_elixir (original): https://github.com/emilsoman/baml_elixir
- AshBaml: https://github.com/bradleygolden/ash_baml

### Language Comparisons
- Python: https://docs.boundaryml.com/guide/installation-language/python
- TypeScript: https://docs.boundaryml.com/guide/installation-language/typescript
- CLI: https://docs.boundaryml.com/ref/baml-cli/init

---

## 13. Conclusion

**Summary**:
AshBaml already provides solid BAML integration for Elixir/Ash, but can achieve Python/TypeScript-level DX by adding CLI-equivalent Mix tasks. The Hybrid Approach (Option C) balances pragmatism with long-term flexibility.

**Immediate Action Items**:
1. ✅ Document current state (this file)
2. ⏭️ Create `mix ash_baml.init` enhancement
3. ⏭️ Implement `mix ash_baml.generate`
4. ⏭️ Add comparison documentation
5. ⏭️ Resolve bradleygolden/baml_elixir repository status

**Long-term Vision**:
Position AshBaml as the definitive BAML integration for Elixir, with DX on par with or exceeding Python/TypeScript clients, while leveraging Ash Framework's strengths for production AI agents.

---

**End of Investigation**
