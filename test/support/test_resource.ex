defmodule AshBaml.Test.TestResource do
  @moduledoc false

  use Ash.Resource,
    domain: AshBaml.Test.TestDomain,
    extensions: [AshBaml.Resource]

  baml do
    client_module(AshBaml.Test.BamlClient)
  end

  actions do
    action :test_action, :map do
      argument(:message, :string, allow_nil?: false)
      run(call_baml(:TestFunction))
    end

    action :multi_arg_action, :map do
      argument(:name, :string, allow_nil?: false)
      argument(:age, :integer, allow_nil?: false)
      argument(:topic, :string, allow_nil?: false)
      run(call_baml(:MultiArgFunction))
    end

    action :optional_args_action, :map do
      argument(:name, :string, allow_nil?: false)
      argument(:age, :integer, allow_nil?: false)
      argument(:location, :string, allow_nil?: true)
      run(call_baml(:OptionalArgsFunction))
    end

    action :array_args_action, :map do
      argument(:tags, {:array, :string}, allow_nil?: false)
      run(call_baml(:ArrayArgsFunction))
    end
  end
end
