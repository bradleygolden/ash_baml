defmodule Helpdesk.BamlClient.Types.PriorityLevel do
  use Ash.Type.Enum, values: [:low, :medium, :high, :urgent]

  @moduledoc """
  Generated from BAML enum: PriorityLevel
  Source: baml_src/...

  ## Values
  - `:low` - Low
  - `:medium` - Medium
  - `:high` - High
  - `:urgent` - Urgent

  This enum is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """
end