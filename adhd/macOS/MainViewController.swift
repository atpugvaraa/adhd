//
//  MainViewController.swift
//  adhd
//
//  Created by Aarav Gupta on 23/10/26.
//

#if os(macOS)
import AppKit

@MainActor
final class MainViewController: NSViewController {
    override func loadView() {
        let rootView = NSView()
        let titleLabel = NSTextField(labelWithString: "adhd")
        let subtitleLabel = NSTextField(labelWithString: "i like lavanya but idk how she feels maybe she likes me as a person but not as someone who could be her partner?? idk man i just like to spend time with this girl and the efforts seem worth it.. i do still want to talk to tarush and rumani regarding this tho..")
        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .centerX
        titleStack.spacing = 8
        subtitleLabel.cell?.wraps = true
        subtitleLabel.preferredMaxLayoutWidth = 400
        
        rootView.addSubview(titleStack)
        
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleStack.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            titleStack.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
            titleStack.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
        ])
        
        view = rootView
    }
}
#endif
