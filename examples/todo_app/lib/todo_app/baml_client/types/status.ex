defmodule TodoApp.BamlClient.Types.Status do
  use Ash.Type.Enum, values: [:todo, :in_progress, :blocked, :done, :archived]

  @moduledoc """
  Generated from BAML enum: Status
  Source: baml_src/...

  ## Values
  - `:todo` - Todo
  - `:in_progress` - InProgress
  - `:blocked` - Blocked
  - `:done` - Done
  - `:archived` - Archived

  This enum is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """
end