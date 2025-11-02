defmodule Helpdesk.BamlClient.Types.ResolutionTime do
  use Ash.Type.Enum, values: [:immediate, :hours, :days, :needs_investigation]

  @moduledoc """
  Generated from BAML enum: ResolutionTime
  Source: baml_src/...

  ## Values
  - `:immediate` - Immediate
  - `:hours` - Hours
  - `:days` - Days
  - `:needs_investigation` - NeedsInvestigation

  This enum is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """
end