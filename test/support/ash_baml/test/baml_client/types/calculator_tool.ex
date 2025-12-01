defmodule AshBaml.Test.BamlClient.Types.CalculatorTool do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field(:operation, :string, allow_nil?: false)
    field(:numbers, {:array, :float}, allow_nil?: false)
  end
end
