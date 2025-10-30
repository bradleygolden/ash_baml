client<llm> TestToolClient {
  provider openai
  options {
    model gpt-4o-mini
    api_key env.OPENAI_API_KEY
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

function SelectTool(message: string) -> WeatherTool | CalculatorTool {
  client TestToolClient
  prompt #"
    Based on the user's message, determine which tool to call.
    Extract the necessary parameters for the selected tool.

    {{ ctx.output_format }}

    User message: {{ message }}
  "#
}
