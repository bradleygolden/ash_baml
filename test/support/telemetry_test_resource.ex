defmodule AshBaml.Test.TelemetryTestResource do
  @moduledoc false
  # Test resource with telemetry enabled for streaming tests

  use Ash.Resource,
    domain: AshBaml.Test.TestDomain,
    extensions: [AshBaml.Resource]

  baml do
    client_module(AshBaml.Test.BamlClient)
    import_functions([:TestFunction])

    telemetry do
      enabled(true)
    end
  end
end
