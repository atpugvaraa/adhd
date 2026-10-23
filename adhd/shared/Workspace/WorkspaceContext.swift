/*
Purpose: Describe resources and launch context associated with a thought.
Stage: Workspace handoff.
Plan:
- Keep a compact, serializable description of links and user-authored context.
- Represent a terminal working directory separately from executable commands.
- Require the user to choose before opening or running anything.
Learning goal: Separate workspace intent from platform-specific launch mechanics.
*/
