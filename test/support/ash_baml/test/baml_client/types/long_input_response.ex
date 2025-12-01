defmodule AshBaml.Test.BamlClient.Types.LongInputResponse do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field(:summary, :string, allow_nil?: false)
    field(:word_count, :integer, allow_nil?: false)
    field(:key_topics, {:array, :string}, allow_nil?: false)
  end
end
