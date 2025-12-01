defmodule AshBaml.Test.BamlClient.Types.TagAnalysisResponse do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field(:summary, :string, allow_nil?: false)
    field(:tag_count, :integer, allow_nil?: false)
    field(:most_common_tag, :string, allow_nil?: true)
  end
end
