import SwiftUI

#if os(iOS)
import MessageUI
import SafariServices
import UIKit

public struct InAppSafariView: UIViewControllerRepresentable {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    public func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

public struct FeedbackMailComposerView: UIViewControllerRepresentable {
    public struct Draft {
        public let recipients: [String]
        public let subject: String
        public let body: String

        public init(recipients: [String], subject: String, body: String) {
            self.recipients = recipients
            self.subject = subject
            self.body = body
        }
    }

    public let draft: Draft
    public let onFinish: () -> Void

    public init(draft: Draft, onFinish: @escaping () -> Void) {
        self.draft = draft
        self.onFinish = onFinish
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    public func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(draft.recipients)
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        return controller
    }

    public func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    public final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        public func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish()
        }
    }
}

public struct FileShareSheetView: UIViewControllerRepresentable {
    private let items: [Any]

    public init(items: [Any]) {
        self.items = items
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
