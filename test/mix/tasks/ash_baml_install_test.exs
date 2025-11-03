defmodule Mix.Tasks.AshBaml.InstallTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.AshBaml.Install

  describe "info/2" do
    test "returns task schema" do
      schema = Install.info([], %{})

      assert is_map(schema)
      assert Map.has_key?(schema, :schema)
    end
  end

  describe "supports_umbrella?/0" do
    test "returns false" do
      refute Install.supports_umbrella?()
    end
  end

  describe "installer?/0" do
    test "returns true" do
      assert Install.installer?()
    end
  end
end
