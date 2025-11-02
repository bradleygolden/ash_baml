defmodule AshBaml.BamlParserTest do
  use ExUnit.Case, async: true
  alias AshBaml.BamlParser

  describe "get_baml_path/1" do
    test "returns path when module has __baml_src_path__/0 callback" do
      assert {:ok, _path} = BamlParser.get_baml_path(AshBaml.Test.BamlClient)
    end

    test "returns error when module doesn't exist and has no source" do
      assert {:error, message} = BamlParser.get_baml_path(NonExistent.Module)
      assert message =~ "does not implement __baml_src_path__/0"
    end
  end
end
