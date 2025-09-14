//
//  PurpleMApp.swift
//  PurpleM
//
//  Created by link on 2025/9/9.
//

import SwiftUI

@main
struct PurpleMApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var networkPermissionManager = NetworkPermissionManager.shared
    
    init() {
        // 初始化网络权限管理器
        _ = NetworkPermissionManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(networkPermissionManager)
        }
    }
}
