//
//  ThemeBackdrop.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The ground behind a whole window: pale silver, lightest at the top left and falling off towards the
/// bottom right. It is the same in every part of the app.
struct ThemeBackdrop: View {
    var body: some View {
        let top = Design.Ground.top
        let mid = Design.Ground.mid
        let deep = Design.Ground.deep
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.46, 0.46], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                top, top, mid,
                top, top.mix(with: mid, by: 0.6), mid.mix(with: deep, by: 0.5),
                mid, mid.mix(with: deep, by: 0.6), deep,
            ]
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
