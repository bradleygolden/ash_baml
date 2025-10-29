defmodule AshBaml.Test.BamlClient do
  @moduledoc false
  # This will generate modules from test BAML files
  use BamlElixir.Client, path: Path.expand("../../test/support/fixtures/baml_src", __DIR__)
end
