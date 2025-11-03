// Example BAML function
// Delete this file and create your own functions

function ExtractUser(text: string) -> User {
  client LocalQwen3
  prompt #"
    Extract user information from the following text:

    {{ text }}

    {{ ctx.output_format }}
  "#
}

class User {
  name string
  email string | null
  age int | null
}
