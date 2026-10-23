//
//  WorkspaceViewController.swift
//  adhd
//
//  Created by Aarav Gupta on 24/10/26.
//

#if os(macOS)
import AppKit

@MainActor
final class WorkspaceViewController: NSViewController {
    override func loadView() {
        let rootView = NSView()
        let titleLabel = NSTextField(labelWithString: "Workspace")
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: rootView.centerYAnchor)
        ])

        view = rootView
    }
}
#endif
