import SwiftUI
import GoogleCast

/// The SDK's Cast button. Tapping it opens Google's device picker and session dialog.
struct CastButton: UIViewRepresentable {
    var tint: UIColor = .label

    func makeUIView(context: Context) -> GCKUICastButton {
        let button = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
        button.tintColor = tint
        return button
    }

    func updateUIView(_ uiView: GCKUICastButton, context: Context) {
        uiView.tintColor = tint
    }
}
