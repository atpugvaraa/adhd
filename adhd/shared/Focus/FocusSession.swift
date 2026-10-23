/*
Purpose: Represent a user-started focus session and its chosen duration/settings.
Stage: Focus support.
Plan:
- Start with a visible timer and a clear pause/stop path.
- Treat blocking and device restrictions as separate, optional integrations.
- Never create a session automatically from an inferred availability signal.
Learning goal: Model a timed workflow separately from platform enforcement.
*/
