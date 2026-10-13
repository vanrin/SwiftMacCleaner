//
//  NoticeToolbar.swift
//  SwiftMacCleaner
//

import SwiftUI

/// What the user should know before starting, as pills at the top right. Each one opens the full story.
struct NoticeToolbar: ToolbarContent {
    let model: AppModel
    /// The offer to put back the last clean belongs to the clean-up flow, not to Largest Folders.
    var showsPutBack = true

    var body: some ToolbarContent {
        if model.isSandboxed {
            ToolbarItem {
                NoticePill(
                    title: "App Sandbox is on", symbol: "exclamationmark.triangle.fill",
                    text: "A sandboxed app can only see its own container, so a scan will find almost nothing. Remove the App Sandbox capability from the target in Xcode to scan your real folders."
                ) {
                    EmptyView()
                }
            }
        }
        if !model.hasFullDiskAccess {
            ToolbarItem {
                NoticePill(
                    title: "Full Disk Access is off", symbol: "lock.fill",
                    text: "Downloads, Documents, Desktop, the Trash, Mail and app containers stay private without it, so those areas are skipped and show as unreadable in Largest Folders. Everything else is scanned either way. The app checks again each time it opens."
                ) {
                    Button("Open Privacy Settings", action: model.openFullDiskAccessSettings)
                }
            }
        }
        if showsPutBack, let pending = model.putBackPending {
            ToolbarItem {
                PutBackPill(model: model, manifest: pending)
            }
        }
        if showsPutBack, let message = model.putBackMessage {
            ToolbarItem {
                NoticePill(title: "Put back", symbol: "checkmark.circle.fill", text: message) {
                    EmptyView()
                }
            }
        }
    }
}
