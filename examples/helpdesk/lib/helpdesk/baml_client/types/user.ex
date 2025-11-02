defmodule Helpdesk.BamlClient.Types.User do
  use Ash.TypedStruct

  @moduledoc """
  Generated from BAML class: User
  Source: baml_src/...

  This struct is automatically generated from BAML schema definitions.
  Do not edit directly - modify the BAML file and regenerate.
  """

  typed_struct do
    field(:age, :integer, allow_nil?: true)
    field(:email, :string, allow_nil?: true)
    field(:name, :string, allow_nil?: false)
  end
end