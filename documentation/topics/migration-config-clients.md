# Migrating to Config-Driven Clients

This guide shows how to migrate from manually created client modules to
config-driven clients.

## Before (Manual Modules)

```elixir
# lib/my_app/baml_client.ex
defmodule MyApp.BamlClient do
  use BamlElixir.Client, baml_src: "baml_src"

  def __baml_src_path__ do
    Path.join(File.cwd!(), "baml_src")
  end
end

# lib/my_app/tickets.ex
defmodule MyApp.Tickets do
  use Ash.Resource, extensions: [AshBaml.Resource]

  baml do
    client_module MyApp.BamlClient
    import_functions [:AnalyzeTicket]
  end
end
```

## After (Config-Driven)

```elixir
# config/config.exs
config :ash_baml,
  clients: [
    default: {MyApp.BamlClient, baml_src: "baml_src"}
  ]

# lib/my_app/tickets.ex
defmodule MyApp.Tickets do
  use Ash.Resource, extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:AnalyzeTicket]
  end
end

# Delete lib/my_app/baml_client.ex - no longer needed!
```

## Benefits

- No boilerplate client files
- Config in one place
- Multiple resources can share clients
- Environment-specific overrides via config
- Release-safe (no File.cwd!/0)

## Migration Steps

1. Add client config to `config/config.exs`
2. Update resources to use `client :identifier`
3. Delete manual client module files
4. Run `mix compile` to verify
5. Run `mix test` to ensure everything works

## Multiple Clients

You can configure multiple clients for different purposes:

```elixir
# config/config.exs
config :ash_baml,
  clients: [
    support: {MyApp.BamlClients.Support, baml_src: "baml_src/support"},
    content: {MyApp.BamlClients.Content, baml_src: "baml_src/content"},
    analytics: {MyApp.BamlClients.Analytics, baml_src: "baml_src/analytics"}
  ]
```

Then use them in different resources:

```elixir
defmodule MyApp.Tickets do
  use Ash.Resource, extensions: [AshBaml.Resource]

  baml do
    client :support
    import_functions [:AnalyzeTicket, :SuggestResolution]
  end
end

defmodule MyApp.Posts do
  use Ash.Resource, extensions: [AshBaml.Resource]

  baml do
    client :content
    import_functions [:ModerateContent, :GenerateSummary]
  end
end
```

## Environment-Specific Configuration

Override clients for different environments:

```elixir
# config/config.exs
config :ash_baml,
  clients: [
    support: {MyApp.BamlClients.Support, baml_src: "baml_src/support"}
  ]

# config/test.exs
config :ash_baml,
  clients: [
    support: {MyApp.BamlClients.Support, baml_src: "test/fixtures/baml_src/support"}
  ]
```

## Keeping Legacy Pattern

The legacy `client_module` pattern continues to work. You don't need to migrate
immediately. Both patterns can coexist:

```elixir
# Some resources use config-driven clients
defmodule MyApp.Tickets do
  baml do
    client :support
  end
end

# Others use legacy explicit modules
defmodule MyApp.LegacyResource do
  baml do
    client_module MyApp.LegacyBamlClient
  end
end
```

## Troubleshooting

### Client not found error

If you see an error like "BAML client :support not found in application config":

1. Check that you've added the client to `config/config.exs`
2. Ensure the config key is `:ash_baml` (not `:ash_baml_clients`)
3. Verify the identifier matches (`:support` not `"support"`)

### Module not generated

If the client module isn't being generated:

1. Run `mix clean && mix compile` to force recompilation
2. Check that your config is in `config/config.exs`, not just `config/runtime.exs`
3. Verify the transformer is registered (should happen automatically)

### Type generation

When migrating, regenerate types for the new module names:

```bash
mix ash_baml.gen.types MyApp.BamlClients.Support
```
