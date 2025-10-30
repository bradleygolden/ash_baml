// Todo App BAML Functions
// These functions use the types defined in types.baml

function ExtractTasks(input: string) -> TaskList {
  client GPT4
  prompt #"
    Extract a task list from the following text:

    {{ input }}

    Return a structured task list with all the tasks you can identify.
    {{ ctx.output_format }}
  "#
}

function CategorizeTasks(tasks: string) -> Task[] {
  client GPT4
  prompt #"
    Given these tasks, categorize and structure them:

    {{ tasks }}

    For each task, assign an appropriate priority, status, and category.
    {{ ctx.output_format }}
  "#
}

function GenerateTaskSummary(tasks: Task[]) -> TaskSummary {
  client GPT4
  prompt #"
    Analyze these tasks and generate a summary:

    {% for task in tasks %}
    - {{ task.title }} ({{ task.status }}, {{ task.priority }})
    {% endfor %}

    {{ ctx.output_format }}
  "#
}

client<llm> GPT4 {
  provider openai
  options {
    model gpt-4
    temperature 0.7
  }
}
