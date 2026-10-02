import Foundation

/// One hosted BackTrack render. Files live on GitHub Pages; see docs/manifest.json.
struct Track: Identifiable, Hashable {
    let key: String
    let tempo: Int

    var id: String { "\(key)-\(tempo)" }
    var title: String { "Wash in \(key) at \(tempo) BPM" }
    var url: URL { Library.baseURL.appendingPathComponent("wash-\(key.lowercased())-\(tempo).m4a") }
    var contentType: String { "audio/mp4" }
}

enum Library {
    static let baseURL = URL(string: "https://harmonicsystems.github.io/google-cast/audio/")!
    static let setup = "Wash with Drums"
    static let tempos = [60, 72, 88, 96, 108, 120, 128]
    static let keys = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

    static func track(key: String, tempo: Int) -> Track { Track(key: key, tempo: tempo) }
}
