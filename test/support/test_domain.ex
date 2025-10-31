defmodule AshBaml.Test.TestDomain do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshBaml.Test.TestResource)
    resource(AshBaml.Test.ToolTestResource)
    resource(AshBaml.AgenticToolHandler)
  end
end
