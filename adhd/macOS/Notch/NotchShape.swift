//
//  NotchShape.swift
//  adhd
//
//  Created by Aarav Gupta on 24/10/26.
//

import SwiftUI

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = topRadius
        let bottom = bottomRadius

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY + top),
            control: CGPoint(x: rect.minX + top, y: rect.minY)
        )

        path.addLine(to: CGPoint(
            x: rect.minX + top,
            y: rect.maxY - bottom
        ))

        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + top + bottom,
                y: rect.maxY
            ),
            control: CGPoint(x: rect.minX + top, y: rect.maxY)
        )

        path.addLine(to: CGPoint(
            x: rect.maxX - top - bottom,
            y: rect.maxY
        ))

        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX - top,
                y: rect.maxY - bottom
            ),
            control: CGPoint(x: rect.maxX - top, y: rect.maxY)
        )

        path.addLine(to: CGPoint(
            x: rect.maxX - top,
            y: rect.minY + top
        ))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - top, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}
