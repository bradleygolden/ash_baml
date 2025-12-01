defmodule AshBaml.Test.BamlClient.Types.WeatherTool do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field(:city, :string, allow_nil?: false)
    field(:units, :string, allow_nil?: false)
  end
end
