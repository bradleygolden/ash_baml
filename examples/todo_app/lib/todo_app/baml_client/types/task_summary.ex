defmodule TodoApp.BamlClient.Types.TaskSummary do
  use Ash.TypedStruct

  @moduledoc """
  Generated from BAML class: TaskSummary
  Source: baml_src/...

  This struct is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """

  typed_struct do
    field(:average_completion_time, :float, allow_nil?: true)
    field(:completed_tasks, :integer, allow_nil?: false)
    field(:high_priority_count, :integer, allow_nil?: false)
    field(:in_progress_tasks, :integer, allow_nil?: false)
    field(:total_tasks, :integer, allow_nil?: false)
  end
end