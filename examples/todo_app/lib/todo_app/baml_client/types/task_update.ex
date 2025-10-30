defmodule TodoApp.BamlClient.Types.TaskUpdate do
  use Ash.TypedStruct

  @moduledoc """
  Generated from BAML class: TaskUpdate
  Source: baml_src/...

  This struct is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """

  typed_struct do
    field(:notes, :string, allow_nil?: true)
    field(:priority, TodoApp.BamlClient.Types.Priority, allow_nil?: true)
    field(:status, TodoApp.BamlClient.Types.Status, allow_nil?: true)
    field(:task_id, :string, allow_nil?: false)
  end
end