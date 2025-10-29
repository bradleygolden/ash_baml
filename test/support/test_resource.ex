defmodule AshBaml.Test.TestResource do
  @moduledoc false

  use Ash.Resource,
    domain: AshBaml.Test.TestDomain,
    extensions: [AshBaml.Resource]

  import AshBaml.Helpers

  baml do
    client_module(AshBaml.Test.BamlClient)
  end

  actions do
    action :test_action, :map do
      argument(:message, :string, allow_nil?: false)
      run(call_baml(:TestFunction))
    end
  end
end
