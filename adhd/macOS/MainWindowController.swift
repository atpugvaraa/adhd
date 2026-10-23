/*
Purpose: Own the primary macOS window after AppKit launches the application.
Stage: Shell.
Plan:
- Retain/configure the NSWindow and coordinate its content controller.
- Keep window lifetime and window behavior out of the application entry point.
- Keep the contents AppKit-based while learning NSWindowController and Auto Layout.
Learning goal: Understand AppKit window ownership and controller lifecycles.
*/
