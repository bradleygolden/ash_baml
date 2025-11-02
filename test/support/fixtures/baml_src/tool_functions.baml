client<llm> TestToolClient {
  provider "openai-generic"
  options {
    base_url "http://localhost:11434/v1"
    model "qwen3:1.7b"
  }
}

class WeatherTool {
  city string @description("City name for weather lookup")
  units string @description("Temperature units: celsius or fahrenheit")
}

class CalculatorTool {
  operation "add" | "subtract" | "multiply" | "divide"
  numbers float[] @description("Numbers to perform operation on")
}

class TimerTool {
  duration_seconds int @description("Duration in seconds for the timer")
  label string @description("Optional label/name for the timer")
}

function SelectTool(message: string) -> WeatherTool | CalculatorTool | TimerTool {
  client TestToolClient
  prompt #"
    Based on the user's message, determine which tool to call.
    Extract the necessary parameters for the selected tool.

    {{ ctx.output_format }}

    User message: {{ message }}
  "#
}
