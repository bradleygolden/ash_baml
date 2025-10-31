defmodule AshBaml.Test.BamlClient.Types.Reply do
  @moduledoc """
  Generated test type for Reply class from BAML schema.
  """

  use Ash.TypedStruct

  typed_struct do
    field(:content, :string, allow_nil?: false)
    field(:confidence, :float, allow_nil?: false)
  end
end
