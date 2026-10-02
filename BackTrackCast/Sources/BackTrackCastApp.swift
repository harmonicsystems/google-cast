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
        let filter = GCKLoggerFilter()
        filter.minimumLevel = .verbose
        GCKLogger.sharedInstance().filter = filter
        GCKLogger.sharedInstance().loggingEnabled = true
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

/// Mirrors SDK log lines to Documents/cast.log (and NSLog) while debugging discovery.
final class CastLogDelegate: NSObject, GCKLoggerDelegate {
    static let shared = CastLogDelegate()
    private let handle: FileHandle? = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("cast.log")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return try? FileHandle(forWritingTo: url)
    }()
    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        let line = "\(Date()) [\(level.rawValue)] \(function) \(message)\n"
        handle?.write(line.data(using: .utf8)!)
        if level.rawValue >= GCKLoggerLevel.warning.rawValue { NSLog("[Cast] %@", line) }
    }
}
