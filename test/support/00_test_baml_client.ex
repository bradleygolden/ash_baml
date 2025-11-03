defmodule AshBaml.Test.BamlClient do
  @moduledoc false

  use BamlElixir.Client,
    path: "test/support/fixtures/baml_src"
end
