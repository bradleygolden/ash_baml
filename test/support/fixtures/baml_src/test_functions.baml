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

class TagAnalysisResponse {
  summary string
  tag_count int
  most_common_tag string?
}

function ArrayArgsFunction(tags: string[]) -> TagAnalysisResponse {
  client TestClient
  prompt #"
    Analyze the following tags: {{ tags }}.
    Provide a brief summary of what these tags suggest, count how many tags there are,
    and identify the most common theme or category (if applicable).
    {{ ctx.output_format }}
  "#
}

class Address {
  street string
  city string
  country string
  postal_code string?
}

class UserProfile {
  name string
  age int
  address Address
}

class NestedObjectResponse {
  formatted_address string
  distance_category string
  is_international bool
}

function NestedObjectFunction(user: UserProfile) -> NestedObjectResponse {
  client TestClient
  prompt #"
    Format the user's information:
    Name: {{ user.name }}, Age: {{ user.age }}
    Address: {{ user.address.street }}, {{ user.address.city }}, {{ user.address.country }}
    {% if user.address.postal_code %}
    Postal Code: {{ user.address.postal_code }}
    {% endif %}

    Provide a nicely formatted address string, categorize as local/regional/international,
    and indicate if it's outside the user's home country (assume US as home).
    {{ ctx.output_format }}
  "#
}

class LongInputResponse {
  summary string
  word_count int
  key_topics string[]
}

function LongInputFunction(long_text: string) -> LongInputResponse {
  client TestClient
  prompt #"
    Analyze the following text:
    {{ long_text }}

    Provide:
    1. A brief summary (2-3 sentences)
    2. An approximate word count
    3. A list of 3-5 key topics or themes
    {{ ctx.output_format }}
  "#
}

class SpecialCharsResponse {
  received_text string
  char_count int
  has_quotes bool
  has_newlines bool
  has_special_symbols bool
}

function SpecialCharsFunction(text_with_special_chars: string) -> SpecialCharsResponse {
  client TestClient
  prompt #"
    Analyze the following text that may contain special characters:
    {{ text_with_special_chars }}

    Provide:
    1. Echo back the exact text you received
    2. Count the total characters
    3. Indicate if it contains quotes (single or double)
    4. Indicate if it contains newlines
    5. Indicate if it contains special symbols like @#$%&*
    {{ ctx.output_format }}
  "#
}
