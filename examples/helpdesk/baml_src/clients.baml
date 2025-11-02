// Configure your LLM clients here
// See: https://docs.boundaryml.com/docs/snippets/clients

client<llm> LocalQwen3 {
  provider "openai-generic"
  options {
    base_url "http://localhost:11434/v1"
    model "qwen3:1.7b"
  }
}

// Cloud provider clients (commented out - using local model)
// client<llm> GPT4 {
//   provider openai
//   options {
//     model gpt-4
//     api_key env.OPENAI_API_KEY
//   }
// }

// client<llm> GPT4Turbo {
//   provider openai
//   options {
//     model gpt-4-turbo-preview
//     api_key env.OPENAI_API_KEY
//   }
// }

// client<llm> Claude {
//   provider anthropic
//   options {
//     model claude-3-5-sonnet-20241022
//     api_key env.ANTHROPIC_API_KEY
//   }
// }
