//
//  CacheCleaner.swift
//  PurpleM
//
//  清理缓存工具 - 解决用户ID不匹配问题
//

import Foundation

class CacheCleaner {
    
    /// 清理所有用户相关缓存
    @MainActor
    static func cleanAllUserCache() {
        print("🧹 ========== 开始清理缓存 ==========")
        
        // 1. 清理AuthManager缓存
        AuthManager.shared.currentUser = nil
        AuthManager.shared.authState = .unauthenticated
        
        // 2. 清理UserDefaults（注意：敏感token现在存储在Keychain中）
        let keysToRemove = [
            "currentUser",
            "PurpleM_UserInfo",
            "PurpleM_ChartData",
            "sessionId"
        ]
        
        // 清理Keychain中的敏感数据
        KeychainManager.shared.clearAuthData()
        print("  ✅ 已清理Keychain中的认证令牌")
        
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
            print("  ✅ 已清理: \(key)")
        }
        
        // 3. 清理UserDataManager
        UserDataManager.shared.clearAllData()
        
        // 4. 清理离线队列
        OfflineQueueManager.shared.clear()
        
        // 5. 同步UserDefaults
        UserDefaults.standard.synchronize()
        
        print("🧹 ========== 缓存清理完成 ==========")
        print("⚠️ 请重新登录以获取正确的用户ID")
    }
    
    /// 显示当前缓存状态
    @MainActor
    static func showCacheStatus() {
        print("📊 ========== 缓存状态 ==========")
        
        // AuthManager状态
        if let user = AuthManager.shared.currentUser {
            print("✅ AuthManager用户:")
            print("   ID: \(user.id)")
            print("   Email: \(user.email)")
        } else {
            print("❌ AuthManager: 无用户")
        }
        
        // UserDefaults状态
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let _ = try? JSONDecoder().decode(User.self, from: userData) {
            print("✅ UserDefaults: 有缓存用户")
        } else {
            print("❌ UserDefaults: 无缓存")
        }
        
        // Token状态
        if let _ = KeychainManager.shared.getAccessToken() {
            print("✅ AccessToken: 存在")
        } else {
            print("❌ AccessToken: 不存在")
        }
        
        // 离线队列状态
        let queueSize = OfflineQueueManager.shared.queueSize
        print("📦 离线队列: \(queueSize)项")
        
        print("====================================")
    }
}