import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    IosPlaybackSession.activate()
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let window = (scene as? UIWindowScene)?.windows.first,
          let controller = window.rootViewController as? FlutterViewController
    else {
      return
    }
    registerAqlossIosPlugins(controller.binaryMessenger)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    IosPlaybackSession.activate()
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    IosPlaybackSession.activate()
  }
}
