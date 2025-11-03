defmodule Helpdesk.Support do
  use Ash.Domain

  resources do
    resource Helpdesk.Support.Ticket
    resource Helpdesk.Support.TicketAnalyzer
  end
end
