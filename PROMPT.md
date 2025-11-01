1. You're operating in a loop. Read SCRATCHPAD.md to catch yourself up to speed.
2. Run /research, /plan, /implement or /qa against all files against origin main output to SCRATCHPAD.md to limit context window usage.
3. Output all notes to SCRATCHPAD.md as needed.
4. Commit changes as you go.

Rules:

* THIS IS CRITICAL - Perform the smallest action necessary to complete the task to keep use of your context window to a minimum. The lower your context window usage, the best you will perform.

* THIS IS ALSO CRITICAL - As you're making changes, ensure that ALL non-critical comments in both code and tests are removed.

* PLEASE ENSURE ALL FILE DIFFS ARE AGAINST ORIGIN/MAIN

* Please try running integration tests prior to each commit to ensure that changes work. Use mix test --only integration. PLEASE source .env to get access to the api keys for running integration tests.

* DOWNLOAD the elixir ex_docs and read the ANTI-PATTERNS sections and subsections, ensure that all changes adhere to that guide. Source link: https://hexdocs.pm/elixir/anti-patterns.html. Use the elixir skill to process.

* You NEVER need to make anything backwards compatible. This project doesn't have any production use or user base yet. It's an early POC/experimental project, though I would like for it to be production ready.
