//
//  UserProfileManager.swift
//  PurpleM
//
//  用户Profile管理器 - 确保用户数据完整性
//

import Foundation
import SwiftUI

// MARK: - 用户Profile模型
struct UserProfile: Codable {
    let id: String  // 对应auth.uid()
    let email: String
    let username: String?
    let avatarUrl: String?
    let subscriptionTier: String
    let quotaLimit: Int
    let quotaUsed: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case avatarUrl = "avatar_url"
        case subscriptionTier = "subscription_tier"
        case quotaLimit = "quota_limit"
        case quotaUsed = "quota_used"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Profile管理器
@MainActor
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var currentProfile: UserProfile?
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {}
    
    // MARK: - 确保用户Profile存在
    /// 在用户登录成功后调用，确保profiles表中有对应记录
    func ensureUserProfile(for user: User) async throws {
        print("🔄 确保用户Profile存在: \(user.email)")
        
        // 先尝试获取现有profile
        if let existingProfile = try await fetchProfile(userId: user.id) {
            self.currentProfile = existingProfile
            print("✅ 找到现有Profile")
            return
        }
        
        // 如果不存在，创建新的profile
        print("📝 创建新的Profile...")
        let newProfile = try await createProfile(for: user)
        self.currentProfile = newProfile
        print("✅ Profile创建成功")
    }
    
    // MARK: - 获取Profile
    private func fetchProfile(userId: String) async throws -> UserProfile? {
        let endpoint = "/rest/v1/profiles?id=eq.\(userId)"
        
        let userToken = KeychainManager.shared.getAccessToken()
        guard let data = try await SupabaseAPIHelper.get(
            endpoint: endpoint,
            baseURL: SupabaseManager.shared.baseURL,
            authType: .authenticated,
            apiKey: SupabaseManager.shared.apiKey,
            userToken: userToken
        ) else {
            return nil
        }
        
        let profiles = try JSONDecoder().decode([UserProfile].self, from: data)
        return profiles.first
    }
    
    // MARK: - 创建Profile
    private func createProfile(for user: User) async throws -> UserProfile {
        let profileData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "username": user.username ?? user.email.components(separatedBy: "@").first ?? "用户",
            "avatar_url": user.avatarUrl as Any,
            "subscription_tier": user.subscriptionTier ?? "free",
            "quota_limit": getQuotaLimit(for: user.subscriptionTier ?? "free"),
            "quota_used": 0,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let userToken = KeychainManager.shared.getAccessToken()
        // Note: Prefer header for return=representation would be needed here
        // but SupabaseAPIHelper doesn't support it yet
        guard let data = try await SupabaseAPIHelper.post(
            endpoint: "/rest/v1/profiles",
            baseURL: SupabaseManager.shared.baseURL,
            authType: .authenticated,
            apiKey: SupabaseManager.shared.apiKey,
            userToken: userToken,
            body: profileData,
            useFieldMapping: false
        ) else {
            throw ProfileError.creationFailed
        }
        
        let profiles = try JSONDecoder().decode([UserProfile].self, from: data)
        guard let newProfile = profiles.first else {
            throw ProfileError.creationFailed
        }
        
        // 同时创建默认的用户配额记录
        try await createDefaultQuota(userId: user.id)
        
        return newProfile
    }
    
    // MARK: - 创建默认配额
    private func createDefaultQuota(userId: String) async throws {
        let quotaData: [String: Any] = [
            "user_id": userId,
            "daily_limit": 100,
            "daily_used": 0,
            "monthly_limit": 3000,
            "monthly_used": 0,
            "reset_date": ISO8601DateFormatter().string(from: Date()),
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let userToken = KeychainManager.shared.getAccessToken()
        _ = try await SupabaseAPIHelper.post(
            endpoint: "/rest/v1/user_ai_quotas",
            baseURL: SupabaseManager.shared.baseURL,
            authType: .authenticated,
            apiKey: SupabaseManager.shared.apiKey,
            userToken: userToken,
            body: quotaData,
            useFieldMapping: false
        )
    }
    
    // MARK: - 获取配额限制
    private func getQuotaLimit(for tier: String) -> Int {
        switch tier {
        case "premium":
            return 10000
        case "pro":
            return 5000
        case "basic":
            return 1000
        default:  // free
            return 100
        }
    }
    
    // MARK: - 更新Profile
    func updateProfile(userId: String, updates: [String: Any]) async throws {
        var data = updates
        data["updated_at"] = ISO8601DateFormatter().string(from: Date())
        
        let userToken = KeychainManager.shared.getAccessToken()
        guard let responseData = try await SupabaseAPIHelper.patch(
            endpoint: "/rest/v1/profiles?id=eq.\(userId)",
            baseURL: SupabaseManager.shared.baseURL,
            authType: .authenticated,
            apiKey: SupabaseManager.shared.apiKey,
            userToken: userToken,
            body: data,
            useFieldMapping: false
        ) else {
            throw ProfileError.updateFailed
        }
        
        let profiles = try JSONDecoder().decode([UserProfile].self, from: responseData)
        if let updatedProfile = profiles.first {
            self.currentProfile = updatedProfile
        }
    }
    
    // MARK: - 清除Profile
    func clearProfile() {
        currentProfile = nil
        error = nil
    }
}

// MARK: - Profile错误
enum ProfileError: LocalizedError {
    case creationFailed
    case updateFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "无法创建用户资料"
        case .updateFailed:
            return "无法更新用户资料"
        case .notFound:
            return "找不到用户资料"
        }
    }
}