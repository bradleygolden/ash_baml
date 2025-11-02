defmodule Helpdesk.BamlClient.Types.ResponseSuggestion do
  use Ash.TypedStruct

  @moduledoc """
  Generated from BAML class: ResponseSuggestion
  Source: baml_src/...

  This struct is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """

  typed_struct do
    field(:next_steps, {:array, :string}, allow_nil?: false)
    field(:requires_manager_review, :boolean, allow_nil?: false)
    field(:resolution_time, Helpdesk.BamlClient.Types.ResolutionTime, allow_nil?: false)
    field(:response_draft, :string, allow_nil?: false)
  end
end