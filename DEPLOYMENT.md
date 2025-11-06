# Deployment Guide

This guide covers deploying applications that use ash_baml with the official `baml_elixir` package.

## Overview

Since `baml_elixir` provides precompiled NIFs for common platforms (Linux, macOS, Windows), deployment follows standard Elixir practices. No Rust toolchain or custom build steps are required.

## Dockerfile Example

Use a standard multi-stage build for Elixir applications:

```dockerfile
# Build stage
FROM hexpm/elixir:1.18.4-erlang-27.3.1-debian-bookworm-20250124 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

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

# Compile dependencies
RUN mix deps.compile

# Copy application code
COPY lib lib/
COPY priv priv/
COPY baml_src baml_src/

# Compile application
RUN mix compile

# Build release
RUN mix release

# Runtime stage - minimal image
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
- First build: 1-3 minutes (standard Elixir compilation)
- Subsequent builds with layer caching: 30-60 seconds

**Layer caching optimization:**
- Dependencies are installed before copying application code
- Changes to your code don't invalidate dependency cache
- Precompiled NIFs are downloaded during `mix deps.get`

## Platform Considerations

### Supported Platforms

`baml_elixir` provides precompiled NIFs for:
- Linux (x86_64, aarch64)
- macOS (x86_64, aarch64/Apple Silicon)
- Windows (x86_64)

### Platform Mismatch

If you're deploying to a platform without precompiled NIFs, you'll see an error during `mix deps.get`. In this case:

1. Check the [baml_elixir releases](https://hex.pm/packages/baml_elixir) for platform availability
2. Consider using a different deployment target (e.g., standard x86_64 Linux)
3. Contact the BAML team about platform support

### Cross-Platform Development

You can develop on macOS or Windows and deploy to Linux without any special configuration. The correct precompiled NIF for your deployment platform is automatically selected during the build process.

## Troubleshooting

### Missing NIF errors at runtime

If you see errors like "could not load NIF" at runtime:

1. **Verify the NIF was included in the release:**
   ```bash
   # In your build container
   ls -la _build/prod/rel/my_app/lib/baml_elixir-*/priv/
   ```

2. **Check platform compatibility:**
   Ensure you're building on the same platform as your deployment target (typically x86_64 Linux).

3. **Verify dependencies were compiled for production:**
   ```bash
   MIX_ENV=prod mix deps.compile --force
   ```

### Build fails during deps.get

If `mix deps.get` fails to download the precompiled NIF:

1. **Check network connectivity** to hex.pm and GitHub
2. **Verify your platform is supported** by checking the package on hex.pm
3. **Clear the dependency cache:**
   ```bash
   mix deps.clean baml_elixir
   mix deps.get
   ```

### Out of memory during compilation

While the Rust NIF is no longer compiled, Elixir compilation can still be memory-intensive for large projects. Ensure your build environment has at least 1GB RAM available.

## Production Checklist

**Required for ash_baml deployment:**
- [ ] Standard Elixir dependencies installed (no Rust required)
- [ ] BAML source files (`baml_src/`) included in Docker image
- [ ] Environment variables configured for LLM providers (API keys, etc.)
- [ ] Multi-stage build used to minimize runtime image size
- [ ] Building on same platform as deployment target (typically x86_64 Linux)
- [ ] Release includes all necessary priv/ directories

**Optional optimizations:**
- [ ] Layer caching optimized (dependencies before app code)
- [ ] BuildKit enabled for faster builds
- [ ] Health checks configured
- [ ] Logging and telemetry configured
- [ ] Resource limits set appropriately

## Cloud Platform Examples

### Fly.io

```bash
# Standard Elixir deployment
fly launch
fly deploy
```

### Heroku

Add to your `elixir_buildpack.config`:

```
erlang_version=27.3
elixir_version=1.18.4
```

Then deploy:

```bash
git push heroku main
```

### AWS/GCP/Azure

Use the standard Dockerfile example above with your platform's container service (ECS, Cloud Run, Container Apps, etc.).

## Security Considerations

1. **API Keys**: Never hardcode LLM provider API keys. Use environment variables.
2. **Runtime User**: Run as non-root user (see Dockerfile example).
3. **Image Scanning**: Scan Docker images for vulnerabilities before deployment.
4. **Network**: Limit outbound network access to required LLM provider endpoints only.
5. **Updates**: Keep `baml_elixir` and dependencies updated for security patches.
