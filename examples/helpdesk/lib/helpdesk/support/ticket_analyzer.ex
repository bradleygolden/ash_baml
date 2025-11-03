defmodule Helpdesk.Support.TicketAnalyzer do
  use Ash.Resource,
    domain: Helpdesk.Support,
    extensions: [AshBaml.Resource]

  baml do
    client(:support)
    import_functions([:CategorizeTicket, :AnalyzeSentiment, :SuggestResponse])
  end
end
