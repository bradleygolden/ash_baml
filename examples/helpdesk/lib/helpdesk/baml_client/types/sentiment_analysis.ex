defmodule Helpdesk.BamlClient.Types.SentimentAnalysis do
  use Ash.TypedStruct

  @moduledoc """
  Generated from BAML class: SentimentAnalysis
  Source: baml_src/...

  This struct is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """

  typed_struct do
    field(:confidence, :float, allow_nil?: false)
    field(:emotional_indicators, {:array, :string}, allow_nil?: false)
    field(:requires_escalation, :boolean, allow_nil?: false)
    field(:sentiment, Helpdesk.BamlClient.Types.SentimentType, allow_nil?: false)
  end
end