defmodule AshBaml.Test.BamlClient.Types.NestedObjectResponse do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field(:formatted_address, :string, allow_nil?: false)
    field(:distance_category, :string, allow_nil?: false)
    field(:is_international, :boolean, allow_nil?: false)
  end
end
