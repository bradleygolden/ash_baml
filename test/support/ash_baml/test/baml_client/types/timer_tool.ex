defmodule AshBaml.Test.BamlClient.Types.TimerTool do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field(:duration_seconds, :integer, allow_nil?: false)
    field(:label, :string, allow_nil?: false)
  end
end
