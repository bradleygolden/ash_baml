defmodule AshBaml.Test.BamlClient.Types.SpecialCharsResponse do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field(:received_text, :string, allow_nil?: false)
    field(:char_count, :integer, allow_nil?: false)
    field(:has_quotes, :boolean, allow_nil?: false)
    field(:has_newlines, :boolean, allow_nil?: false)
    field(:has_special_symbols, :boolean, allow_nil?: false)
  end
end
