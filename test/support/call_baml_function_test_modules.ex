defmodule AshBaml.Test.CallBamlFunction.UnionResponse do
  @moduledoc false

  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:message, :string)
  end
end

defmodule AshBaml.Test.CallBamlFunction.SimpleResponse do
  @moduledoc false

  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:value, :string)
  end
end
