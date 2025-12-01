defmodule AshBaml.Test.BamlClient.Types.MultiArgResponse do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field(:greeting, :string, allow_nil?: false)
    field(:description, :string, allow_nil?: false)
    field(:age_category, :string, allow_nil?: false)
  end
end
