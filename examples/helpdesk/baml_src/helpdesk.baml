function CategorizeTicket(subject: string, description: string) -> TicketCategory {
  client GPT4Turbo
  prompt #"
    Analyze the following support ticket and categorize it:

    Subject: {{ subject }}
    Description: {{ description }}

    Categorize this ticket into one of the following categories:
    - bug: Technical issues or defects
    - feature_request: Requests for new functionality
    - question: General inquiries or how-to questions
    - account: Account-related issues
    - billing: Payment or subscription issues

    Also assess the priority (low, medium, high, urgent) based on the content.

    {{ ctx.output_format }}
  "#
}

function AnalyzeSentiment(text: string) -> SentimentAnalysis {
  client GPT4Turbo
  prompt #"
    Analyze the sentiment of the following customer message:

    {{ text }}

    Provide:
    - Overall sentiment (positive, neutral, negative, frustrated, urgent)
    - Confidence score (0.0 to 1.0)
    - Key emotional indicators found in the text

    {{ ctx.output_format }}
  "#
}

function SuggestResponse(ticket_subject: string, ticket_description: string, customer_name: string) -> ResponseSuggestion {
  client Claude
  prompt #"
    Generate a professional support response for the following ticket:

    Customer: {{ customer_name }}
    Subject: {{ ticket_subject }}
    Description: {{ ticket_description }}

    Provide:
    - A professional, empathetic response draft
    - Suggested next steps or actions
    - Estimated resolution time category (immediate, hours, days, needs_investigation)

    {{ ctx.output_format }}
  "#
}

class TicketCategory {
  category TicketCategoryType
  priority PriorityLevel
  reasoning string
  suggested_assignee string | null
}

enum TicketCategoryType {
  Bug
  FeatureRequest
  Question
  Account
  Billing
}

enum PriorityLevel {
  Low
  Medium
  High
  Urgent
}

class SentimentAnalysis {
  sentiment SentimentType
  confidence float
  emotional_indicators string[]
  requires_escalation bool
}

enum SentimentType {
  Positive
  Neutral
  Negative
  Frustrated
  Urgent
}

class ResponseSuggestion {
  response_draft string
  next_steps string[]
  resolution_time ResolutionTime
  requires_manager_review bool
}

enum ResolutionTime {
  Immediate
  Hours
  Days
  NeedsInvestigation
}
