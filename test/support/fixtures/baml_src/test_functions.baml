client<llm> TestClient {
  provider openai
  options {
    model gpt-4o-mini
    api_key env.OPENAI_API_KEY
  }
}

class Reply {
  content string
  confidence float
}

function TestFunction(message: string) -> Reply {
  client TestClient
  prompt #"
    You are a test assistant.
    User: {{ message }}
    {{ ctx.output_format }}
  "#
}

class MultiArgResponse {
  greeting string
  description string
  age_category string
}

function MultiArgFunction(name: string, age: int, topic: string) -> MultiArgResponse {
  client TestClient
  prompt #"
    Create a personalized greeting for {{ name }} who is {{ age }} years old.
    Then provide a brief description about {{ topic }}.
    Finally, categorize the age as: child (0-12), teen (13-19), adult (20-64), or senior (65+).
    {{ ctx.output_format }}
  "#
}

class ProfileResponse {
  bio string
  interests string[]
  location string?
}

function OptionalArgsFunction(name: string, age: int, location: string?) -> ProfileResponse {
  client TestClient
  prompt #"
    Create a profile for {{ name }} who is {{ age }} years old.
    {% if location %}
    They are located in {{ location }}.
    {% else %}
    Location is not specified.
    {% endif %}
    Provide a brief bio, a list of potential interests, and include the location if provided.
    {{ ctx.output_format }}
  "#
}
