defmodule AshBaml.BamlParserTest do
  use ExUnit.Case, async: true
  alias AshBaml.BamlParser

  describe "get_baml_path/1" do
    test "returns path when module has __baml_src_path__/0 callback" do
      assert {:ok, path} = BamlParser.get_baml_path(AshBaml.Test.BamlClient)
      assert is_binary(path)
      assert path == "test/support/fixtures/baml_src"
    end

    test "returns error when module doesn't exist" do
      assert {:error, message} = BamlParser.get_baml_path(NonExistent.Module)
      assert message =~ "does not implement __baml_src_path__/0"
      assert message =~ "For config-driven clients"
      assert message =~ "For explicit client modules"
    end
  end

  describe "parse_schema/1" do
    test "successfully parses BAML files" do
      path = "test/support/fixtures/baml_src"
      assert {:ok, schema} = BamlParser.parse_schema(path)
      assert is_map(schema)
      assert Map.has_key?(schema, :classes)
      assert Map.has_key?(schema, :enums)
      assert Map.has_key?(schema, :functions)
    end

    test "returns error when path doesn't exist" do
      assert {:error, reason} = BamlParser.parse_schema("/nonexistent/path")
      assert is_binary(reason)
      assert reason =~ "Failed to parse"
    end
  end

  describe "extract_classes/1" do
    test "extracts class definitions from schema" do
      path = "test/support/fixtures/baml_src"
      {:ok, schema} = BamlParser.parse_schema(path)

      classes = BamlParser.extract_classes(schema)
      assert is_map(classes)
    end
  end

  describe "extract_enums/1" do
    test "extracts enum definitions from schema" do
      path = "test/support/fixtures/baml_src"
      {:ok, schema} = BamlParser.parse_schema(path)

      enums = BamlParser.extract_enums(schema)
      assert is_map(enums)
    end
  end
end
