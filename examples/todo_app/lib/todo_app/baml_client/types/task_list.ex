defmodule TodoApp.BamlClient.Types.TaskList do
  use Ash.TypedStruct

  @moduledoc """
  Generated from BAML class: TaskList
  Source: baml_src/...

  This struct is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """

  typed_struct do
    field(:description, :string, allow_nil?: true)
    field(:name, :string, allow_nil?: false)
    field(:tasks, {:array, TodoApp.BamlClient.Types.Task}, allow_nil?: false)
  end
end