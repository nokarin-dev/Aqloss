import Flutter
import UIKit
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var mediaControls: MediaControlsPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.binaryMessenger
    mediaControls = MediaControlsPlugin(messenger: messenger)
  }
}

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
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            result(nil)

        case "update":
            guard let args = call.arguments as? [String: Any] else { result(nil); return }
            updateNowPlaying(args)
            result(nil)

        case "clear":
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Remote command
    private func setupRemoteCommands() {
        guard !isRegistered else { return }
        isRegistered = true

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

        // Enable/disable controls
        cc.playCommand.isEnabled           = true
        cc.pauseCommand.isEnabled          = true
        cc.togglePlayPauseCommand.isEnabled = true
        cc.nextTrackCommand.isEnabled      = true
        cc.previousTrackCommand.isEnabled  = true
        cc.changePlaybackPositionCommand.isEnabled = true
        cc.stopCommand.isEnabled           = false
        cc.seekForwardCommand.isEnabled    = false
        cc.seekBackwardCommand.isEnabled   = false
    }

    // Playing info
    private func updateNowPlaying(_ args: [String: Any]) {
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
            let image = UIImage(data: bytes) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}