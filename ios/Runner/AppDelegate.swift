import AVFoundation
import Flutter
import UIKit
import MediaPlayer
import UniformTypeIdentifiers

enum IosPlaybackSession {
  static func activate() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
    UIApplication.shared.beginReceivingRemoteControlEvents()
  }
}

func registerAqlossIosPlugins(_ messenger: FlutterBinaryMessenger) {
  MediaControlsPlugin.shared.setup(messenger: messenger)
  IosAudioRoutePlugin.shared.setup(messenger: messenger)
  FileOpenPlugin.shared.setup(messenger: messenger)
  IosFoldersPlugin.shared.setup(messenger: messenger)
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    IosPlaybackSession.activate()
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      registerAqlossIosPlugins(controller.binaryMessenger)
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

  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    IosPlaybackSession.activate()
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

// Route changes (Bluetooth / speaker)
final class IosAudioRoutePlugin: NSObject, FlutterStreamHandler {
  static let shared = IosAudioRoutePlugin()
  private var channel: FlutterEventChannel?
  private var sink: FlutterEventSink?
  private var listening = false
  private var pending: DispatchWorkItem?

  func setup(messenger: FlutterBinaryMessenger) {
    IosPlaybackSession.activate()
    let ch = FlutterEventChannel(
      name: "xyz.nokarin.aqloss/audio_route",
      binaryMessenger: messenger
    )
    ch.setStreamHandler(self)
    channel = ch
    startListening()
  }

  private func startListening() {
    if listening { return }
    listening = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(routeChanged),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(interrupted),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
  }

  private func scheduleNotify() {
    pending?.cancel()
    let work = DispatchWorkItem { [weak self] in
      IosPlaybackSession.activate()
      self?.sink?(nil)
    }
    pending = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
  }

  @objc private func routeChanged(_ notification: Notification) {
    scheduleNotify()
  }

  @objc private func interrupted(_ notification: Notification) {
    guard
      let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw),
      type == .ended
    else { return }
    scheduleNotify()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}

// MediaControlsPlugin
final class MediaControlsPlugin: NSObject {
    static let shared = MediaControlsPlugin()
    private var channel: FlutterMethodChannel?
    private var isRegistered = false
    private var isPlaying = false
    private var lastArtwork: MPMediaItemArtwork?

    func setup(messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(
            name: "xyz.nokarin.aqloss/media_controls",
            binaryMessenger: messenger
        )
        ch.setMethodCallHandler(handle)
        channel = ch
        setupRemoteCommands()
        IosPlaybackSession.activate()
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            setupRemoteCommands()
            IosPlaybackSession.activate()
            result(nil)

        case "ensureSession":
            IosPlaybackSession.activate()
            result(nil)

        case "update":
            guard let args = call.arguments as? [String: Any] else { result(nil); return }
            updateNowPlaying(args)
            result(nil)

        case "clear":
            isPlaying = false
            lastArtwork = nil
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
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
            IosPlaybackSession.activate()
            self?.isPlaying = true
            self?.channel?.invokeMethod("onPlay", arguments: nil)
            return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            self?.isPlaying = false
            self?.channel?.invokeMethod("onPause", arguments: nil)
            return .success
        }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .success }
            if self.isPlaying {
                self.isPlaying = false
                self.channel?.invokeMethod("onPause", arguments: nil)
            } else {
                IosPlaybackSession.activate()
                self.isPlaying = true
                self.channel?.invokeMethod("onPlay", arguments: nil)
            }
            return .success
        }
        cc.nextTrackCommand.addTarget { [weak self] _ in
            self?.channel?.invokeMethod("onNext", arguments: nil)
            return .success
        }
        cc.previousTrackCommand.addTarget { [weak self] _ in
            self?.channel?.invokeMethod("onPrevious", arguments: nil)
            return .success
        }
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                let ms = Int(e.positionTime * 1000)
                self?.channel?.invokeMethod("onSeek", arguments: ms)
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

    private func number(_ args: [String: Any], _ key: String) -> Double {
        if let n = args[key] as? NSNumber { return n.doubleValue }
        return 0
    }

    private func flag(_ args: [String: Any], _ key: String) -> Bool {
        if let b = args[key] as? Bool { return b }
        if let n = args[key] as? NSNumber { return n.boolValue }
        return false
    }

    private func updateNowPlaying(_ args: [String: Any]) {
        isPlaying = flag(args, "isPlaying")
        if isPlaying {
            IosPlaybackSession.activate()
        }

        let title = args["title"] as? String ?? ""
        let artist = args["artist"] as? String ?? ""
        let album = args["album"] as? String ?? ""
        let posMs = number(args, "positionMs")
        let durMs = number(args, "durationMs")
        let artBytes = args["artBytes"] as? FlutterStandardTypedData

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyPlaybackDuration: durMs / 1000.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: posMs / 1000.0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        if let bytes = artBytes?.data, let image = UIImage(data: bytes) {
            lastArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        if let artwork = lastArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        let center = MPNowPlayingInfoCenter.default()
        center.playbackState = isPlaying ? .playing : .paused
        center.nowPlayingInfo = info
    }
}