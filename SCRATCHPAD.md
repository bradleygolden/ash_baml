# AshBaml Igniter Installer - Implementation Notes

## Current Status
Starting implementation of Igniter installer with modification:
- Make --module optional
- Default to using application's root namespace (e.g., Helpdesk.BamlClient)
- User can run `mix ash_baml.install` without arguments

## Task Overview
1. Create Igniter installer task at `lib/mix/tasks/ash_baml.install.ex`
2. Generate BAML client module
3. Create baml_src directory with example files
4. Update documentation
5. Test end-to-end in helpdesk example

## Progress
- [x] Read existing installer implementation - FOUND at lib/mix/tasks/ash_baml.install.ex
- [x] Make --module optional with app namespace default - DONE
  - Removed --module from required list
  - Added logic to detect app name and default to AppName.BamlClient
  - Fixed compilation warning about unused @example
- [x] Test in helpdesk example end-to-end - SUCCESS
  - Ran installer with default module
  - Generated Helpdesk.BamlClient correctly
  - Generated types successfully
  - Verified compilation works
- [x] Update documentation - DONE
  - Updated examples/helpdesk/README.md
  - Updated main README.md
- [ ] Commit changes
- [ ] Create .TASK_COMPLETE file

## Current Findings
- Installer already exists and is well-structured
- Uses Igniter properly
- Currently requires --module (line 29)
- Need to:
  1. Make module optional in schema (remove from required)
  2. Detect application name from mix.exs when module not provided
  3. Default to AppName.BamlClient pattern

## Notes
- Following CLAUDE.md: imperative commit messages, no unnecessary code comments
- Need to detect application name from mix.exs for default module name
- Igniter has utilities for getting app name: Igniter.Project.Application.app_name/1
