# Ralph Pattern Reference

Source: https://ghuntley.com/ralph/

## What It Is

Ralph is a technique for automated software development using AI coding agents. In its simplest form, it's a Bash loop that continuously feeds prompts to an AI tool:

```bash
while :; do cat PROMPT.md | npx --yes @sourcegraph/amp ; done
```

## Core Philosophy

Ralph is described as "deterministically bad in an undeterministic world." Rather than blaming tools when problems arise, the approach emphasizes iterative refinement—tuning the system like a musical instrument based on observed failures.

## How It Works

Ralph operates on principles of eventual consistency and requires "a great deal of faith." When the AI takes a wrong direction, practitioners don't fault the tools; instead, they analyze what went wrong and refine the prompts and instructions accordingly.

The playground metaphor: after Ralph fails, you add clarifying signs (better instructions) so it makes fewer mistakes next time.

## Practical Results

Ralph has demonstrated remarkable efficiency:
- A $50,000 contract was completed for $297 using this approach
- Six repositories were shipped overnight during a Y Combinator hackathon
- Ralph successfully created an entirely new programming language it could subsequently program in

## Key Requirements

Ralph works with any tool that doesn't cap tool calls or API usage, making it adaptable across different AI platforms.
