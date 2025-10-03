//
//  KeychainManager.swift
//  PurpleM
//
//  安全的Keychain存储管理器
//

import Foundation
import Security

// MARK: - Keychain错误类型
enum KeychainError: Error {
    case noPassword
    case unexpectedPasswordData
    case unhandledError(status: OSStatus)
    case duplicateEntry
    case itemNotFound
}

// MARK: - Keychain键定义
enum KeychainKey: String {
    case accessToken = "com.purplem.accessToken"
    case refreshToken = "com.purplem.refreshToken"
    case userPassword = "com.purplem.userPassword"
    case userId = "com.purplem.userId"
}

// MARK: - Keychain管理器
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    // MARK: - 保存到Keychain
    func save(_ value: String, for key: KeychainKey) throws {
        let data = value.data(using: .utf8)!
        
        // 查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        
        // 先尝试删除旧的
        SecItemDelete(query as CFDictionary)
        
        // 添加新的
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // 如果已存在，更新它
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key.rawValue
            ]
            
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    // MARK: - 从Keychain读取
    func get(for key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        
        return nil
    }
    
    // MARK: - 从Keychain删除
    func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    // MARK: - 清空所有Keychain数据
    func clearAll() {
        let keys: [KeychainKey] = [.accessToken, .refreshToken, .userPassword, .userId]
        
        for key in keys {
            try? delete(for: key)
        }
    }
    
    // MARK: - 便捷方法
    
    /// 保存认证Token
    func saveAuthTokens(accessToken: String?, refreshToken: String?) {
        if let accessToken = accessToken {
            try? save(accessToken, for: .accessToken)
            // 发送Token更新通知，触发自动刷新调度
            NotificationCenter.default.post(
                name: NSNotification.Name("TokenUpdated"),
                object: nil,
                userInfo: ["token": accessToken]
            )
        }
        
        if let refreshToken = refreshToken {
            try? save(refreshToken, for: .refreshToken)
        }
    }
    
    /// 获取访问Token
    func getAccessToken() -> String? {
        return get(for: .accessToken)
    }
    
    /// 获取刷新Token
    func getRefreshToken() -> String? {
        return get(for: .refreshToken)
    }
    
    /// 清除所有认证信息
    func clearAuthData() {
        try? delete(for: .accessToken)
        try? delete(for: .refreshToken)
        try? delete(for: .userId)
    }
    
    /// 检查是否有有效的Token
    func hasValidToken() -> Bool {
        return getAccessToken() != nil
    }
}

// MARK: - 迁移助手
extension KeychainManager {
    /// 从UserDefaults迁移到Keychain
    func migrateFromUserDefaults() {
        // 迁移AccessToken
        if let token = UserDefaults.standard.string(forKey: "accessToken") {
            try? save(token, for: .accessToken)
            // 迁移后删除UserDefaults中的数据
            UserDefaults.standard.removeObject(forKey: "accessToken")
            print("✅ AccessToken已迁移到Keychain")
        }
        
        // 迁移RefreshToken（如果有）
        if let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") {
            try? save(refreshToken, for: .refreshToken)
            UserDefaults.standard.removeObject(forKey: "refreshToken")
            print("✅ RefreshToken已迁移到Keychain")
        }
    }
}