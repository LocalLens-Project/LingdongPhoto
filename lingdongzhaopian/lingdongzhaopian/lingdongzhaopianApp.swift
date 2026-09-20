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
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard !windowScenes.contains(where: { $0.traitCollection.userInterfaceIdiom == .pad }) else { return }
        mask = newMask

        for windowScene in windowScenes {
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
            window?.traitCollection.userInterfaceIdiom == .pad
                ? .all
                : InterfaceOrientationController.shared.mask
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
                .task {

                    await SupporterStore.shared.bootstrap()
                }
        }
    }

}
