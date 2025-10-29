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
