// Todo App BAML Types
// This file defines the types for our todo application

enum Priority {
  Low
  Medium
  High
  Urgent
}

enum Status {
  Todo
  InProgress
  Blocked
  Done
  Archived
}

enum TaskCategory {
  Personal
  Work
  Shopping
  Health
  Other
}

class Task {
  title string
  description string?
  priority Priority
  status Status
  category TaskCategory
  due_date string?
  tags string[]
  estimated_hours float?
}

class TaskList {
  name string
  description string?
  tasks Task[]
}

class TaskUpdate {
  task_id string
  status Status?
  priority Priority?
  notes string?
}

class TaskSummary {
  total_tasks int
  completed_tasks int
  in_progress_tasks int
  high_priority_count int
  average_completion_time float?
}
