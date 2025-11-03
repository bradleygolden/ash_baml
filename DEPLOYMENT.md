# Deployment Guide

This guide covers deploying applications that use ash_baml with the custom [baml_elixir fork](https://github.com/bradleygolden/baml_elixir).

## Requirements

The custom baml_elixir fork requires:
1. **Rust and Cargo** available during the build process to compile the NIF
2. **Git submodules** initialized before compilation (baml_elixir uses submodules for BAML sources)

## Dockerfile Example

Use a multi-stage build to compile the Rust NIF and create a minimal runtime image.

```dockerfile
# Build stage - includes Rust toolchain
FROM hexpm/elixir:1.18.4-erlang-27.3.1-debian-bookworm-20250124 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Verify Rust installation
RUN rustc --version && cargo --version

# Prepare build dir
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy config files
COPY config/config.exs config/prod.exs config/

# Initialize git submodules for baml_elixir
RUN cd deps/baml_elixir && git submodule update --init --recursive

# Compile dependencies (this will build the Rust NIF)
RUN mix deps.compile

# Copy application code
COPY lib lib/
COPY priv priv/

# Compile application
RUN mix compile

# Build release
RUN mix release

# Runtime stage - minimal image without Rust
FROM debian:bookworm-20250124-slim

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    libssl3 \
    libncurses6 \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

# Copy the release from builder
COPY --from=builder /app/_build/prod/rel/my_app ./

# Create non-root user
RUN useradd -m -u 1000 app && chown -R app:app /app
USER app

CMD ["/app/bin/my_app", "start"]
```

## Build Notes

**Build times:**
- First build: 5-10 minutes (compiling Rust NIF + BAML dependencies)
- Subsequent builds with layer caching: 1-3 minutes

## Troubleshooting

### "cargo: not found" during build

Rust must be installed in the Dockerfile build stage. Verify:

```dockerfile
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
```

### Git submodule errors

baml_elixir uses git submodules for BAML source code. Initialize them before compiling:

```dockerfile
RUN cd deps/baml_elixir && git submodule update --init --recursive
```

### Platform mismatch (NIF compiled for wrong architecture)

NIFs are platform-specific. If you develop on macOS but deploy to Linux, you must build in Docker targeting Linux. The macOS-compiled NIF will not work in production.

### Out of memory during compilation

The Rust compilation is memory-intensive. Ensure your build environment has at least 2GB RAM available.

## Deployment Checklist

**Required for ash_baml with custom baml_elixir fork:**
- [ ] Rust and Cargo installed in Dockerfile build stage
- [ ] `PATH` includes `~/.cargo/bin` during build
- [ ] Git submodules initialized before running `mix deps.compile`
- [ ] Building on same platform as deployment target (typically Linux)
- [ ] Multi-stage build used (Rust removed from runtime image)
