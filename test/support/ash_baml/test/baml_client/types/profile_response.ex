defmodule AshBaml.Test.BamlClient.Types.ProfileResponse do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field(:bio, :string, allow_nil?: false)
    field(:interests, {:array, :string}, allow_nil?: false)
    field(:location, :string, allow_nil?: true)
  end
end
