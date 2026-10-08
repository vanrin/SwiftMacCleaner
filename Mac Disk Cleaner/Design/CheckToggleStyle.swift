//
//  CheckToggleStyle.swift
//  Mac Disk Cleaner
//

import SwiftUI

/// A round tick box in the app's own style. It shows a dash when only some of what it covers is ticked,
/// and still reads to VoiceOver as the toggle it is.
struct CheckToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    /// Whether the label is drawn next to the box. A row that already shows the title turns this off.
    var showsLabel = true

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Design.Spacing.medium) {
                CheckMark(isOn: configuration.isOn, isMixed: configuration.isMixed)
                if showsLabel {
                    configuration.label
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
        }
    }
}

extension ToggleStyle where Self == CheckToggleStyle {
    static var check: CheckToggleStyle { CheckToggleStyle() }
    /// The box alone, for a row that shows the title itself.
    static var checkOnly: CheckToggleStyle { CheckToggleStyle(showsLabel: false) }
}
