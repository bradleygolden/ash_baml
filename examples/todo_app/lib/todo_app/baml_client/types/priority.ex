defmodule TodoApp.BamlClient.Types.Priority do
  use Ash.Type.Enum, values: [:low, :medium, :high, :urgent]

  @moduledoc """
  Generated from BAML enum: Priority
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