/*
Purpose: Assemble the primary macOS NSWindow in one focused place.
Stage: Shell, only if construction grows beyond the AppDelegate's needs.
Plan:
- Choose the window frame, style, title, and initial content controller.
- Keep construction separate from application lifecycle and view layout.
- Do not create multiple factory layers for a single simple window.
Learning goal: Understand how an AppKit window is configured before it is shown.
*/
