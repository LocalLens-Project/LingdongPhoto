// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

@MainActor
final class InterfaceOrientationController {
    static let shared = InterfaceOrientationController()

    private(set) var mask: UIInterfaceOrientationMask = .portrait

    private init() {}

    func request(_ newMask: UIInterfaceOrientationMask) {
        mask = newMask

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.keyWindow?
                .rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
            windowScene.requestGeometryUpdate(
                .iOS(interfaceOrientations: newMask)
            ) { error in
                #if DEBUG
                print("ORIENTATION_REQUEST_ERROR: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

final class LingdongAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated {
            InterfaceOrientationController.shared.mask
        }
    }
}

@main
struct lingdongzhaopianApp: App {
    @UIApplicationDelegateAdaptor(LingdongAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.black)
        }
    }
}
