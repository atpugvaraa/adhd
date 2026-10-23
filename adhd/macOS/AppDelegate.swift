/*
Purpose: Planned home for NSApplicationDelegate lifecycle callbacks.
Current state: AppDelegate is currently declared in adhd/adhdApp.swift.
Plan:
- Move the declaration here only when the entry-point cleanup is intentional.
- Retain the main window controller and coordinate launch/termination behavior.
- Keep view layout and feature rules out of the delegate.
Learning goal: Learn the AppKit delegate lifecycle and object ownership.
*/

#if os(macOS)
import AppKit
import SwiftUI

/// A nonactivating notch panel may become key for text input, without becoming a main window.
private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var workspaceWindowController: NSWindowController?
    
    private var notchPanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenuBarItem()
        
        guard let screen = NSScreen.screens.first(where: { screen in
            screen.safeAreaInsets.top > 0
        }) ?? NSScreen.main else { return }
        
        let size = NSSize(
            width: NotchLayoutMetrics.compactSize.width,
            height: screen.safeAreaInsets.top
        )
        let panelSize = NSSize(
            width: NotchLayoutMetrics.expandedPanelWidth,
            height: size.height + 180
        )

        let panelRect = NSRect(
            x: screen.frame.midX - panelSize.width / 2,
            y: screen.frame.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
        
        let panel = NotchPanel(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.becomesKeyOnlyIfNeeded = true
        
        let notchSurface = NSHostingView(rootView: NotchSurfaceView())
        notchSurface.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = notchSurface
        
        notchPanel = panel
        panel.orderFrontRegardless()
    }

    private func configureMenuBarItem() {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        item.button?.image = NSImage(
            systemSymbolName: "sparkle",
            accessibilityDescription: "adhd"
        )

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Open Workspace",
            action: #selector(openWorkspace(_:)),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit adhd",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        ))

        item.menu = menu
        statusItem = item
    }
    
    @objc private func openWorkspace(_ sender: Any?) {
        if let workspaceWindowController {
            workspaceWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSApp.setActivationPolicy(.regular)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "adhd Workspace"
        window.center()
        window.contentViewController = WorkspaceViewController()
        window.delegate = self

        let controller = NSWindowController(window: window)
        workspaceWindowController = controller
        controller.showWindow(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard
            let window = notification.object as? NSWindow,
            window === workspaceWindowController?.window
        else {
            return
        }

        workspaceWindowController = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
#endif

#if canImport(HotSwiftUI)
@_exported import HotSwiftUI
#elseif canImport(Inject)
@_exported import Inject
#else
// This code can be found in the Swift package:
// https://github.com/johnno1962/HotSwiftUI or
// https://github.com/krzysztofzablocki/Inject

#if DEBUG
import Combine

public class InjectionObserver: ObservableObject {
    public static let shared = InjectionObserver()
    @Published var injectionNumber = 0
    var cancellable: AnyCancellable? = nil
    let publisher = PassthroughSubject<Void, Never>()
    init() {
        cancellable = NotificationCenter.default.publisher(for:
            Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))
            .sink { [weak self] change in
            self?.injectionNumber += 1
            self?.publisher.send()
        }
    }
}

extension SwiftUI.View {
    public func eraseToAnyView() -> some SwiftUI.View {
        return AnyView(self)
    }
    public func enableInjection() -> some SwiftUI.View {
        return eraseToAnyView()
    }
    public func onInjection(bumpState: @escaping () -> ()) -> some SwiftUI.View {
        return self
            .onReceive(InjectionObserver.shared.publisher, perform: bumpState)
            .eraseToAnyView()
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct ObserveInjection: DynamicProperty {
    @ObservedObject private var iO = InjectionObserver.shared
    public init() {}
    public private(set) var wrappedValue: Int {
        get {0} set {}
    }
}
#else
extension SwiftUI.View {
    @inline(__always)
    public func eraseToAnyView() -> some SwiftUI.View { return self }
    @inline(__always)
    public func enableInjection() -> some SwiftUI.View { return self }
    @inline(__always)
    public func onInjection(bumpState: @escaping () -> ()) -> some SwiftUI.View {
        return self
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct ObserveInjection {
    public init() {}
    public private(set) var wrappedValue: Int {
        get {0} set {}
    }
}
#endif
#endif
