// ChristosApp — Universal Remote Hub
// Made by Christos Papavas

import SwiftUI

@main
struct ChristosApp: App {
    @StateObject private var discoveryVM   = DeviceDiscoveryViewModel()
    @StateObject private var favoritesVM   = FavoritesViewModel()
    @StateObject private var bluetoothMgr  = BluetoothManager()
    @StateObject private var historyMgr    = ConnectionHistoryManager()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(discoveryVM)
                .environmentObject(favoritesVM)
                .environmentObject(bluetoothMgr)
                .environmentObject(historyMgr)
                .preferredColorScheme(.dark)
        }
    }
}
