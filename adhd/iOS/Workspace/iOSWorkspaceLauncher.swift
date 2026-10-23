/*
Purpose: Open an attached resource from the iOS app after the user chooses it.
Stage: Workspace handoff.
Plan:
- Use supported system URL handoff first.
- Keep platform-specific launch behavior behind a small adapter.
- Do not claim the app can embed or control another app without a supported API.
Learning goal: Learn iOS URL handoff and scene/application boundaries.
*/
