defmodule HelpdeskTest do
  use ExUnit.Case
  doctest Helpdesk

  test "greets the world" do
    assert Helpdesk.hello() == :world
  end
end
