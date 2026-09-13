import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let window = (scene as? UIWindowScene)?.windows.first,
          let controller = window.rootViewController as? FlutterViewController
    else {
      return
    }
    FileOpenPlugin.shared.setup(messenger: controller.binaryMessenger)
    IosFoldersPlugin.shared.setup(messenger: controller.binaryMessenger)
  }
}
