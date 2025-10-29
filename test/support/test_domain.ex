defmodule AshBaml.Test.TestDomain do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshBaml.Test.TestResource)
  end
end
