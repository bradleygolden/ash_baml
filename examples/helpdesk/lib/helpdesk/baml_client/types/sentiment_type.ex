defmodule Helpdesk.BamlClient.Types.SentimentType do
  use Ash.Type.Enum, values: [:positive, :neutral, :negative, :frustrated, :urgent]

  @moduledoc """
  Generated from BAML enum: SentimentType
  Source: baml_src/...

  ## Values
  - `:positive` - Positive
  - `:neutral` - Neutral
  - `:negative` - Negative
  - `:frustrated` - Frustrated
  - `:urgent` - Urgent

  This enum is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """
end