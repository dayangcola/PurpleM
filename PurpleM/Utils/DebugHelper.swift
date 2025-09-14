//
//  DebugHelper.swift
//  PurpleM
//
//  调试助手 - 用于诊断用户ID问题
//

import Foundation

class DebugHelper {
    @MainActor
    static func logUserInfo() {
        print("========== 用户信息调试 ==========")
        
        // 检查AuthManager中的用户
        if let authUser = AuthManager.shared.currentUser {
            print("✅ AuthManager用户:")
            print("  - ID: \(authUser.id)")
            print("  - Email: \(authUser.email)")
            print("  - Username: \(authUser.username ?? "无")")
        } else {
            print("❌ AuthManager中没有用户")
        }
        
        // 检查UserDefaults中的数据
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            print("✅ UserDefaults缓存用户:")
            print("  - ID: \(user.id)")
            print("  - Email: \(user.email)")
        } else {
            print("❌ UserDefaults中没有用户缓存")
        }
        
        // 检查SupabaseManager的authToken
        if let token = KeychainManager.shared.getAccessToken() {
            print("✅ 有访问令牌（长度: \(token.count)）")
        } else {
            print("❌ 没有访问令牌")
        }
        
        print("=====================================")
    }
    
    static func clearAllCaches() {
        print("🗑️ 清理所有缓存...")
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "accessToken")
        UserDefaults.standard.synchronize()
        print("✅ 缓存已清理，请重新登录")
    }
}