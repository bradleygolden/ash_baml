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
// client<llm> GPT5 {
//   provider openai
//   options {
//     model gpt-5
//     api_key env.OPENAI_API_KEY
//   }
// }

// client<llm> GPT5Mini {
//   provider openai
//   options {
//     model gpt-5-mini
//     api_key env.OPENAI_API_KEY
//   }
// }

// client<llm> Claude {
//   provider anthropic
//   options {
//     model claude-4-5-sonnet
//     api_key env.ANTHROPIC_API_KEY
//   }
// }
