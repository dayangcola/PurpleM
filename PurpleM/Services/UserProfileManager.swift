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
        
        let response = try await SupabaseManager.shared.makeRequest(
            endpoint: endpoint,
            method: "GET",
            expecting: [UserProfile].self
        )
        
        return response.first
    }
    
    // MARK: - 创建Profile
    private func createProfile(for user: User) async throws -> UserProfile {
        let profileData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "username": user.username ?? user.email.components(separatedBy: "@").first ?? "用户",
            "avatar_url": user.avatarUrl,
            "subscription_tier": user.subscriptionTier ?? "free",
            "quota_limit": getQuotaLimit(for: user.subscriptionTier ?? "free"),
            "quota_used": 0,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: profileData)
        
        let profiles = try await SupabaseManager.shared.makeRequest(
            endpoint: "/rest/v1/profiles",
            method: "POST",
            body: jsonData,
            headers: ["Prefer": "return=representation"],
            expecting: [UserProfile].self
        )
        
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
        
        let jsonData = try JSONSerialization.data(withJSONObject: quotaData)
        
        // 使用Data作为返回类型，因为我们不需要解析响应
        _ = try await SupabaseManager.shared.makeRequest(
            endpoint: "/rest/v1/user_ai_quotas",
            method: "POST",
            body: jsonData,
            expecting: Data.self
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
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        
        let profiles = try await SupabaseManager.shared.makeRequest(
            endpoint: "/rest/v1/profiles?id=eq.\(userId)",
            method: "PATCH",
            body: jsonData,
            headers: ["Prefer": "return=representation"],
            expecting: [UserProfile].self
        )
        
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