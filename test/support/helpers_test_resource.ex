defmodule AshBaml.Test.HelpersTestResource do
  @moduledoc false

  use Ash.Resource,
    domain: AshBaml.Test.HelpersTestDomain,
    extensions: [AshBaml.Resource]

  baml do
    client_module(AshBaml.Test.BamlClient)
  end

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read])

    action :test_call_baml, :string do
      run(call_baml(:TestFunction))
    end

    action :test_call_baml_with_opts, :string do
      run(call_baml(:TestFunction, telemetry: false))
    end

    action :test_call_baml_stream, AshBaml.Type.Stream do
      run(call_baml_stream(:TestFunction))
    end
  end
end
