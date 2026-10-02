import SwiftUI
import GoogleCast

@main
struct BackTrackCastApp: App {
    @StateObject private var cast = CastController.shared

    init() {
        // Initialize the Cast context once, before any view asks for it.
        let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        options.physicalVolumeButtonsWillControlDeviceVolume = true
        GCKCastContext.setSharedInstanceWith(options)
        #if DEBUG
        GCKLogger.sharedInstance().delegate = CastLogDelegate.shared
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cast)
        }
    }
}

/// Prints SDK log lines while debugging discovery. Not used in release builds.
final class CastLogDelegate: NSObject, GCKLoggerDelegate {
    static let shared = CastLogDelegate()
    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        if level.rawValue >= GCKLoggerLevel.warning.rawValue {
            print("[Cast] \(function) \(message)")
        }
    }
}
