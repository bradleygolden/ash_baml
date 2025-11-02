defmodule Helpdesk.BamlClient.Types.TicketCategoryType do
  use Ash.Type.Enum, values: [:bug, :feature_request, :question, :account, :billing]

  @moduledoc """
  Generated from BAML enum: TicketCategoryType
  Source: baml_src/...

  ## Values
  - `:bug` - Bug
  - `:feature_request` - FeatureRequest
  - `:question` - Question
  - `:account` - Account
  - `:billing` - Billing

  This enum is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """
end