defmodule TodoApp.BamlClient.Types.TaskCategory do
  use Ash.Type.Enum, values: [:personal, :work, :shopping, :health, :other]

  @moduledoc """
  Generated from BAML enum: TaskCategory
  Source: baml_src/...

  ## Values
  - `:personal` - Personal
  - `:work` - Work
  - `:shopping` - Shopping
  - `:health` - Health
  - `:other` - Other

  This enum is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """
end