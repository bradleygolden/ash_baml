defmodule AshBamlTest do
  use ExUnit.Case
  doctest AshBaml

  test "has version" do
    assert AshBaml.version() == "0.1.0"
  end
end
