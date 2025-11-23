import Config

config :ash_baml,
  clients: [
    test: {AshBaml.Test.BamlClient, baml_src: "test/support/fixtures/baml_src"}
  ]
