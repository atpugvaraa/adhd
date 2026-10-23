# adhd

A personal workspace for catching intentions, returning to them at the right time, and making it easier to begin.

I am building this for myself and to learn native Apple development. The app should work alongside my habits, not dictate them. This README is the project plan; the comment-only Swift files are a scaffold describing what each future file is for.

## Why I am making this

I often get a burst of energy to improve my life or start a project. That energy can disappear when I realize I do not yet know how to build the thing I imagined. I also save thoughts, notes, and browser tabs that I may never see again. I want one system that can hold an idea without interrupting current work, bring it back when I have room, and help me find a first manageable action.

## Product direction

- Capture a thought quickly from anywhere on my Mac; save it and immediately return to what I was doing.
- Keep thoughts and useful resources in one place instead of scattering them across files, tabs, and apps.
- Resurface thoughts during planned free-time windows and, if the platforms support it, likely free moments.
- Treat notifications as gentle nudges. If I ignore one, let the thought quietly return in another eligible window.
- Show my original thought as written, with one suggested first step beneath it. Suggestions remain optional and editable.
- When I choose to start, bring the relevant note, browser resource, or terminal context within reach.
- Grow over time to support learning/research, work updates, focus sessions, and digital habits.

## Platform decisions

- The app is named **adhd**.
- Plan for macOS and iOS from the beginning; share product logic and data concepts where useful.
- macOS uses an AppKit-owned application lifecycle and AppKit windows/views.
- iOS uses a SwiftUI-owned application lifecycle. UIKit is introduced deliberately for learning or a real platform need.
- The Mac and iPhone interfaces can differ. Reusing logic matters more than forcing identical UI.
- The current project puts both conditional entry points in `adhd/adhdApp.swift`. The comment-only `MacApplication.swift` and `AppDelegate.swift` files describe a possible future separation. Do not add duplicate `@main` or delegate declarations until intentionally moving the current code.

## Build order

1. **Understand the shell:** keep both platform launches working; learn AppKit lifecycle, NSWindow ownership, NSViewController, and Auto Layout; sketch the iOS SwiftUI root and a small UIKit bridge exercise.
2. **Name the data:** define a thought, attached resource, and lifecycle in plain Swift; decide what must sync before choosing a database or backend.
3. **Capture locally:** implement the smallest Mac and iPhone capture paths; preserve original text and return to prior work.
4. **Return gently:** define planned windows, the review queue, notification behavior, and retry/dismiss states; begin with a manually editable first-step suggestion.
5. **Open useful context:** attach links/notes and offer explicit browser or terminal handoff.
6. **Add optional support:** research Focus/Screen Time limits, work/social integrations, and AI privacy before promising any monitoring or automation.

Build only one understandable slice at a time. The later stages are ideas to explore, not a commitment to implement every integration or recreate apps such as Dia, Ghostty, boring.notch, TinyCast, or Vorssaint.

## Planned source layout

```text
adhd/
├── adhdApp.swift                         # Existing conditional platform entry points
├── iOS/
│   ├── ContentView.swift                 # Existing starter view
│   ├── AppRootView.swift                 # iOS navigation and feature composition
│   ├── UIKitLearningViewController.swift # Small UIKit/Auto Layout learning surface
│   ├── Capture/QuickCaptureView.swift    # Touch-first capture flow
│   ├── Workspace/iOSWorkspaceLauncher.swift # Explicit resource handoff
│   └── Integrations/ScreenTimeActivityResearch.swift # Research before implementation
├── macOS/
│   ├── MainViewController.swift          # Existing AppKit shell content
│   ├── MacApplication.swift              # Future AppKit @main extraction plan
│   ├── AppDelegate.swift                 # Future delegate extraction plan
│   ├── MainWindowController.swift         # Main NSWindow ownership
│   ├── MainWindowFactory.swift            # Window construction if it warrants a separate file
│   ├── Capture/QuickCaptureWindowController.swift
│   └── Workspace/MacWorkspaceLauncher.swift
└── shared/
    ├── Models/Thought.swift, Resource.swift, ResurfacingPolicy.swift
    ├── UseCases/CaptureThought.swift, SelectThoughtsForReview.swift, RecordThoughtResponse.swift
    ├── Persistence/ThoughtRepository.swift, LocalThoughtStore.swift
    ├── Sync/ThoughtSyncCoordinator.swift
    ├── Workspace/WorkspaceContext.swift
    ├── Assistance/FirstStepSuggestionProvider.swift
    ├── Focus/FocusSession.swift
    └── Notifications/ResurfacingScheduler.swift
```

The new Swift scaffold files contain multiline comments only. Each comment records the file's purpose, stage, boundaries, and learning goal. They do not implement behavior yet. Start with the shell-related files; create working code only when that slice is understood.

## Important boundaries

- App idleness is not proof that I am free. Availability inference must be optional, explainable, and correctable.
- Research Apple permissions, background limits, and API availability before designing Screen Time, notifications, global shortcuts, or monitoring behavior.
- Do not send messages, execute inferred terminal commands, alter settings, or let an agent make changes without my explicit action.
- Keep storage, cross-device sync, and AI provider choices open until their privacy and failure behavior are understood.
