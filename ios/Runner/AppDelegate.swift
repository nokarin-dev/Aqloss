import Flutter
import UIKit
import MediaPlayer
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var mediaControls: MediaControlsPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      mediaControls = MediaControlsPlugin(messenger: controller.binaryMessenger)
      FileOpenPlugin.shared.setup(messenger: controller.binaryMessenger)
      IosFoldersPlugin.shared.setup(messenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return FileOpenPlugin.shared.send(url.path)
  }
}

// FileOpenPlugin
class FileOpenPlugin {
  static let shared = FileOpenPlugin()
  private var channel: FlutterMethodChannel?

  func setup(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "xyz.nokarin.aqloss/file_open",
      binaryMessenger: messenger
    )
  }

  @discardableResult
  func send(_ path: String) -> Bool {
    guard let ch = channel else { return false }
    ch.invokeMethod("openFile", arguments: path)
    return true
  }
}

// Folder pick + security-scoped bookmarks + share
final class IosFoldersPlugin: NSObject, UIDocumentPickerDelegate {
  static let shared = IosFoldersPlugin()
  private var channel: FlutterMethodChannel?
  private var pickResult: FlutterResult?
  private var accessed: [String: URL] = [:]
  private let bookmarkKey = "aqloss.folderBookmarks"

  func setup(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "xyz.nokarin.aqloss/ios_folders",
      binaryMessenger: messenger
    )
    channel?.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickFolder":
      pickFolder(result)
    case "startAccess":
      guard let path = call.arguments as? String else { result(false); return }
      result(startAccess(path))
    case "stopAccess":
      guard let path = call.arguments as? String else { result(nil); return }
      stopAccess(path)
      result(nil)
    case "shareFiles":
      guard let paths = call.arguments as? [String] else { result(nil); return }
      shareFiles(paths, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickFolder(_ result: @escaping FlutterResult) {
    if pickResult != nil {
      result(nil)
      return
    }
    pickResult = result
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: [.folder],
      asCopy: false
    )
    picker.delegate = self
    picker.allowsMultipleSelection = false
    guard let vc = topController() else {
      finishPick(nil)
      return
    }
    vc.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishPick(nil)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let url = urls.first else {
      finishPick(nil)
      return
    }
    _ = url.startAccessingSecurityScopedResource()
    accessed[url.path] = url
    if let data = try? url.bookmarkData(
      options: [],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    ) {
      var stored = bookmarks()
      stored[url.path] = data
      saveBookmarks(stored)
    }
    finishPick(url.path)
  }

  @discardableResult
  private func startAccess(_ path: String) -> Bool {
    if let url = accessed[path] {
      return url.startAccessingSecurityScopedResource()
    }
    if let data = bookmarks()[path] {
      var stale = false
      guard let url = try? URL(
        resolvingBookmarkData: data,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      ) else {
        return false
      }
      let ok = url.startAccessingSecurityScopedResource()
      if ok { accessed[path] = url }
      return ok
    }
    return true
  }

  private func stopAccess(_ path: String) {
    if let url = accessed.removeValue(forKey: path) {
      url.stopAccessingSecurityScopedResource()
    }
    var stored = bookmarks()
    stored.removeValue(forKey: path)
    saveBookmarks(stored)
  }

  private func shareFiles(_ paths: [String], result: @escaping FlutterResult) {
    let urls = paths.map { URL(fileURLWithPath: $0) }.filter {
      FileManager.default.fileExists(atPath: $0.path)
    }
    guard let vc = topController(), !urls.isEmpty else {
      result(nil)
      return
    }
    let sheet = UIActivityViewController(activityItems: urls, applicationActivities: nil)
    if let pop = sheet.popoverPresentationController {
      pop.sourceView = vc.view
      pop.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
    }
    vc.present(sheet, animated: true) { result(nil) }
  }

  private func finishPick(_ path: String?) {
    pickResult?(path)
    pickResult = nil
  }

  private func bookmarks() -> [String: Data] {
    guard let raw = UserDefaults.standard.dictionary(forKey: bookmarkKey) else {
      return [:]
    }
    var out: [String: Data] = [:]
    for (key, value) in raw {
      if let data = value as? Data { out[key] = data }
    }
    return out
  }

  private func saveBookmarks(_ value: [String: Data]) {
    UserDefaults.standard.set(value, forKey: bookmarkKey)
  }

  private func topController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    let window = windows.first(where: \.isKeyWindow) ?? windows.first
    var vc = window?.rootViewController
    while let presented = vc?.presentedViewController {
      vc = presented
    }
    return vc
  }
}

// MediaControlsPlugin
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

        cc.playCommand.isEnabled = true
        cc.pauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.isEnabled = true
        cc.nextTrackCommand.isEnabled = true
        cc.previousTrackCommand.isEnabled = true
        cc.changePlaybackPositionCommand.isEnabled = true
        cc.stopCommand.isEnabled = false
        cc.seekForwardCommand.isEnabled = false
        cc.seekBackwardCommand.isEnabled = false
    }

    private func updateNowPlaying(_ args: [String: Any]) {
        let title = args["title"] as? String ?? ""
        let artist = args["artist"] as? String ?? ""
        let album = args["album"] as? String ?? ""
        let isPlaying = args["isPlaying"] as? Bool   ?? false
        let posMs = args["positionMs"] as? Double ?? 0
        let durMs = args["durationMs"] as? Double ?? 0
        let artBytes = args["artBytes"] as? FlutterStandardTypedData

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyPlaybackDuration: durMs / 1000.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: posMs / 1000.0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        if let bytes = artBytes?.data, let image = UIImage(data: bytes) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}