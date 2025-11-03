defmodule Helpdesk.Support.Ticket do
  use Ash.Resource, domain: Helpdesk.Support

  actions do
    defaults [:read]

    create :create
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string
  end
end
