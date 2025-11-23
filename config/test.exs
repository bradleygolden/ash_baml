import Config

existing_clients = Application.get_env(:ash_baml, :clients, [])

config :ash_baml,
  clients:
    Keyword.merge(
      existing_clients,
      [test: {AshBaml.Test.BamlClient, baml_src: "test/support/fixtures/baml_src"}]
    )
