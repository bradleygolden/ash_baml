defmodule AshBaml.Test.BamlClient.Types.Priority do
  @moduledoc false
  use Ash.Type.Enum, values: [:low, :medium, :high, :urgent]
end
