defmodule AshBaml.InfoTest do
  use ExUnit.Case, async: true

  describe "baml_client_module/1" do
    test "returns configured client module" do
      assert AshBaml.Test.BamlClient ==
               AshBaml.Info.baml_client_module(AshBaml.Test.TestResource)
    end
  end
end
