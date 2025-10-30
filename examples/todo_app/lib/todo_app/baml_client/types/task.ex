defmodule TodoApp.BamlClient.Types.Task do
  use Ash.TypedStruct

  @moduledoc """
  Generated from BAML class: Task
  Source: baml_src/...

  This struct is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """

  typed_struct do
    field(:category, TodoApp.BamlClient.Types.TaskCategory, allow_nil?: false)
    field(:description, :string, allow_nil?: true)
    field(:due_date, :string, allow_nil?: true)
    field(:estimated_hours, :float, allow_nil?: true)
    field(:priority, TodoApp.BamlClient.Types.Priority, allow_nil?: false)
    field(:status, TodoApp.BamlClient.Types.Status, allow_nil?: false)
    field(:tags, {:array, :string}, allow_nil?: false)
    field(:title, :string, allow_nil?: false)
  end
end