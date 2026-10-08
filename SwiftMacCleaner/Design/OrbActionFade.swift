//
//  OrbActionFade.swift
//  SwiftMacCleaner
//

import SwiftUI

/// The mask that keeps a screen's content away from its round button: solid at the top, fading out just
/// above the strip the button stands in, and gone inside it.
struct OrbActionFade: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: Design.Size.orbActionFade)
            Color.clear
                .frame(height: Design.Size.orbActionZone)
        }
        .ignoresSafeArea()
    }
}
