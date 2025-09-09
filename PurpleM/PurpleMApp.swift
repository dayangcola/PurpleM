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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
}
