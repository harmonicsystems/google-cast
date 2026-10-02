import Foundation
import GoogleCast

/// Thin observable wrapper over the Cast session and remote media client.
/// The SDK's own Cast button handles device picking; this only tracks state and loads media.
@MainActor
final class CastController: NSObject, ObservableObject {
    static let shared = CastController()

    @Published private(set) var deviceName: String?
    @Published private(set) var playerState: GCKMediaPlayerState = .unknown
    @Published private(set) var nowPlayingTitle: String?
    @Published private(set) var lastError: String?

    var isConnected: Bool { deviceName != nil }

    private var sessionManager: GCKSessionManager { GCKCastContext.sharedInstance().sessionManager }

    private override init() {
        super.init()
        sessionManager.add(self)
        if let session = sessionManager.currentCastSession {
            attach(session)
        }
    }

    // MARK: - Loading

    /// Loads one track on the speaker. With `repeatForever`, loads it as a one-item
    /// queue with repeat-all so the Default Media Receiver loops it.
    func play(_ track: Track, repeatForever: Bool) {
        guard let client = sessionManager.currentCastSession?.remoteMediaClient else {
            lastError = "No speaker connected."
            return
        }
        lastError = nil

        let meta = GCKMediaMetadata(metadataType: .musicTrack)
        meta.setString(track.title, forKey: kGCKMetadataKeyTitle)
        meta.setString("BackTrack", forKey: kGCKMetadataKeyArtist)
        meta.setString(Library.setup, forKey: kGCKMetadataKeyAlbumTitle)

        let builder = GCKMediaInformationBuilder(contentURL: track.url)
        builder.streamType = .buffered
        builder.contentType = track.contentType
        builder.metadata = meta
        let info = builder.build()

        let request = GCKMediaLoadRequestDataBuilder()
        request.autoplay = true
        if repeatForever {
            let item = GCKMediaQueueItemBuilder()
            item.mediaInformation = info
            item.autoplay = true
            let queue = GCKMediaQueueDataBuilder(queueType: .generic)
            queue.items = [item.build()]
            queue.repeatMode = .all
            request.queueData = queue.build()
        } else {
            request.mediaInformation = info
        }
        client.loadMedia(with: request.build())
        nowPlayingTitle = track.title
    }

    func pause() { sessionManager.currentCastSession?.remoteMediaClient?.pause() }
    func resume() { sessionManager.currentCastSession?.remoteMediaClient?.play() }
    func stop() { sessionManager.currentCastSession?.remoteMediaClient?.stop() }

    // MARK: - Session plumbing

    private func attach(_ session: GCKCastSession) {
        deviceName = session.device.friendlyName ?? "Speaker"
        session.remoteMediaClient?.add(self)
        if let status = session.remoteMediaClient?.mediaStatus { apply(status) }
    }

    private func detach() {
        deviceName = nil
        playerState = .unknown
        nowPlayingTitle = nil
    }

    private func apply(_ status: GCKMediaStatus) {
        playerState = status.playerState
        if let title = status.mediaInformation?.metadata?.string(forKey: kGCKMetadataKeyTitle) {
            nowPlayingTitle = title
        } else if status.playerState == .idle {
            nowPlayingTitle = nil
        }
    }
}

extension CastController: GCKSessionManagerListener {
    nonisolated func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKCastSession) {
        Task { @MainActor in self.attach(session) }
    }
    nonisolated func sessionManager(_ sessionManager: GCKSessionManager, didResumeCastSession session: GCKCastSession) {
        Task { @MainActor in self.attach(session) }
    }
    nonisolated func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKCastSession, withError error: Error?) {
        Task { @MainActor in
            self.detach()
            if let error { self.lastError = error.localizedDescription }
        }
    }
    nonisolated func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKCastSession, withError error: Error) {
        Task { @MainActor in self.lastError = error.localizedDescription }
    }
}

extension CastController: GCKRemoteMediaClientListener {
    nonisolated func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
        guard let mediaStatus else { return }
        Task { @MainActor in self.apply(mediaStatus) }
    }
}

extension GCKMediaPlayerState {
    var label: String {
        switch self {
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .buffering: return "Buffering"
        case .loading: return "Loading"
        case .idle: return "Idle"
        default: return "—"
        }
    }
}
