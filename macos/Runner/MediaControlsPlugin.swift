import Cocoa
import FlutterMacOS
import MediaPlayer

class MediaControlsPlugin: NSObject {
    private let channel: FlutterMethodChannel
    private var isRegistered = false

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "xyz.nokarin.aqloss/media_controls",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            setupRemoteCommands()
            result(nil)

        case "update":
            guard let args = call.arguments as? [String: Any] else { result(nil); return }
            updateNowPlaying(args)
            result(nil)

        case "clear":
            if #available(macOS 10.15, *) {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                MPNowPlayingInfoCenter.default().playbackState = .stopped
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Remote commands
    private func setupRemoteCommands() {
        guard !isRegistered else { return }
        isRegistered = true

        guard #available(macOS 10.15, *) else { return }

        let cc = MPRemoteCommandCenter.shared()

        cc.playCommand.addTarget { [weak self] _ in
            self?.channel.invokeMethod("onPlay", arguments: nil)
            return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            self?.channel.invokeMethod("onPause", arguments: nil)
            return .success
        }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.channel.invokeMethod("onPlay", arguments: nil)
            return .success
        }
        cc.nextTrackCommand.addTarget { [weak self] _ in
            self?.channel.invokeMethod("onNext", arguments: nil)
            return .success
        }
        cc.previousTrackCommand.addTarget { [weak self] _ in
            self?.channel.invokeMethod("onPrevious", arguments: nil)
            return .success
        }
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                let ms = Int(e.positionTime * 1000)
                self?.channel.invokeMethod("onSeek", arguments: ms)
            }
            return .success
        }

        cc.playCommand.isEnabled                      = true
        cc.pauseCommand.isEnabled                     = true
        cc.togglePlayPauseCommand.isEnabled            = true
        cc.nextTrackCommand.isEnabled                 = true
        cc.previousTrackCommand.isEnabled             = true
        cc.changePlaybackPositionCommand.isEnabled    = true
        cc.stopCommand.isEnabled                      = false
    }

    // Now Playing info
    private func updateNowPlaying(_ args: [String: Any]) {
        guard #available(macOS 10.15, *) else { return }

        let title     = args["title"]     as? String ?? ""
        let artist    = args["artist"]    as? String ?? ""
        let album     = args["album"]     as? String ?? ""
        let isPlaying = args["isPlaying"] as? Bool   ?? false
        let posMs     = args["positionMs"] as? Double ?? 0
        let durMs     = args["durationMs"] as? Double ?? 0
        let artBytes  = args["artBytes"]  as? FlutterStandardTypedData

        var info: [String: Any] = [
            MPMediaItemPropertyTitle:              title,
            MPMediaItemPropertyArtist:             artist,
            MPMediaItemPropertyAlbumTitle:         album,
            MPMediaItemPropertyPlaybackDuration:   durMs / 1000.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: posMs / 1000.0,
            MPNowPlayingInfoPropertyPlaybackRate:  isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType:     MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        if let bytes = artBytes?.data,
           let image = NSImage(data: bytes) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
}
