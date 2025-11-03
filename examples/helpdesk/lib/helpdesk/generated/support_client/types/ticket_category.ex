defmodule Helpdesk.Generated.SupportClient.Types.TicketCategory do
  use Ash.TypedStruct

  @moduledoc """
  Generated from BAML class: TicketCategory
  Source: baml_src/...

  This struct is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """

  typed_struct do
    field(:category, Helpdesk.Generated.SupportClient.Types.TicketCategoryType, allow_nil?: false)
    field(:priority, Helpdesk.Generated.SupportClient.Types.PriorityLevel, allow_nil?: false)
    field(:reasoning, :string, allow_nil?: false)
    field(:suggested_assignee, :string, allow_nil?: true)
  end
end
