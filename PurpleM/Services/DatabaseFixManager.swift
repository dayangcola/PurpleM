//
//  DatabaseFixManager.swift
//  PurpleM
//
//  数据库修复管理器 - 解决外键约束和重复键问题
//

import Foundation

@MainActor
class DatabaseFixManager {
    static let shared = DatabaseFixManager()
    
    private init() {}
    
    // MARK: - 确保用户Profile存在
    func ensureUserProfileExists(userId: String, email: String) async throws {
        print("🔍 检查用户Profile是否存在...")
        
        // 先检查profile是否已存在
        let checkEndpoint = "/rest/v1/profiles?id=eq.\(userId)&select=id"
        
        do {
            let data = try await SupabaseManager.shared.makeRequest(
                endpoint: checkEndpoint,
                method: "GET",
                expecting: Data.self
            )
            let profiles = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
            
            if profiles.isEmpty {
                print("📝 Profile不存在，创建新Profile...")
                try await createProfile(userId: userId, email: email)
            } else {
                print("✅ Profile已存在")
            }
        } catch {
            print("❌ 检查Profile失败: \(error)")
            // 尝试创建profile
            try await createProfile(userId: userId, email: email)
        }
    }
    
    // MARK: - 创建Profile
    private func createProfile(userId: String, email: String) async throws {
        let profileData: [String: Any] = [
            "id": userId,
            "email": email,
            "username": email.components(separatedBy: "@").first ?? "用户",
            "subscription_tier": "free",
            "quota_limit": 100,
            "quota_used": 0,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: profileData)
        
        // 使用upsert避免重复插入
        let headers = [
            "Prefer": "resolution=merge-duplicates,return=representation"
        ]
        
        do {
            _ = try await SupabaseManager.shared.makeRequest(
                endpoint: "/rest/v1/profiles?on_conflict=id",
                method: "POST",
                body: jsonData,
                headers: headers,
                expecting: Data.self
            )
            print("✅ Profile创建成功")
        } catch {
            print("⚠️ Profile创建失败，可能已存在: \(error)")
        }
    }
    
    // MARK: - 安全创建会话
    func safeCreateSession(sessionId: String, userId: String, email: String, title: String? = nil) async throws {
        // 1. 先确保profile存在
        try await ensureUserProfileExists(userId: userId, email: email)
        
        // 2. 创建会话
        let sessionData: [String: Any] = [
            "id": sessionId,
            "user_id": userId,
            "title": title ?? "新对话",
            "session_type": "general",
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: sessionData)
        
        // 使用upsert避免重复
        let headers = [
            "Prefer": "resolution=merge-duplicates"
        ]
        
        _ = try await SupabaseManager.shared.makeRequest(
            endpoint: "/rest/v1/chat_sessions?on_conflict=id",
            method: "POST",
            body: jsonData,
            headers: headers,
            expecting: Data.self
        )
        
        print("✅ 会话创建成功")
    }
    
    // MARK: - 安全保存消息
    func safeSaveMessage(
        messageId: String,
        sessionId: String,
        userId: String,
        email: String,
        role: String,
        content: String,
        metadata: [String: Any]? = nil
    ) async throws {
        // 1. 确保profile和session都存在
        try await ensureUserProfileExists(userId: userId, email: email)
        try await ensureSessionExists(sessionId: sessionId, userId: userId, email: email)
        
        // 2. 保存消息
        let messageData: [String: Any] = [
            "id": messageId,
            "session_id": sessionId,
            "user_id": userId,
            "role": role,
            "content": content,
            "content_type": "text",
            "metadata": metadata ?? [:],
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: messageData)
        
        _ = try await SupabaseManager.shared.makeRequest(
            endpoint: "/rest/v1/chat_messages",
            method: "POST",
            body: jsonData,
            expecting: Data.self
        )
        
        print("✅ 消息保存成功")
    }
    
    // MARK: - 确保会话存在
    private func ensureSessionExists(sessionId: String, userId: String, email: String) async throws {
        let checkEndpoint = "/rest/v1/chat_sessions?id=eq.\(sessionId)&select=id"
        
        let data = try await SupabaseManager.shared.makeRequest(
            endpoint: checkEndpoint,
            method: "GET",
            expecting: Data.self
        )
        let sessions = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        
        if sessions.isEmpty {
            try await safeCreateSession(sessionId: sessionId, userId: userId, email: email)
        }
    }
    
    // MARK: - 修复UPDATE语句（使用正确的PATCH）
    func safeSyncMemoryData(userId: String, memoryData: [String: Any]) async throws {
        print("🔄 安全同步记忆数据...")
        
        // 准备数据
        let jsonData = try JSONSerialization.data(withJSONObject: memoryData)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        let updateData: [String: Any] = [
            "user_id": userId,  // 确保包含user_id
            "custom_personality": jsonString,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let updateJsonData = try JSONSerialization.data(withJSONObject: updateData)
        
        // 使用UPSERT而不是UPDATE
        let headers = [
            "Prefer": "resolution=merge-duplicates"
        ]
        
        _ = try await SupabaseManager.shared.makeRequest(
            endpoint: "/rest/v1/user_ai_preferences?on_conflict=user_id",
            method: "POST",
            body: updateJsonData,
            headers: headers,
            expecting: Data.self
        )
        
        print("✅ 记忆数据同步成功")
    }
    
    // MARK: - 修复用户偏好设置（处理重复键）
    func safeSaveUserPreferences(userId: String, preferences: [String: Any]) async throws {
        var prefsData = preferences
        prefsData["user_id"] = userId
        prefsData["updated_at"] = ISO8601DateFormatter().string(from: Date())
        
        if prefsData["created_at"] == nil {
            prefsData["created_at"] = ISO8601DateFormatter().string(from: Date())
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: prefsData)
        
        // 使用UPSERT处理重复键
        let headers = [
            "Prefer": "resolution=merge-duplicates"
        ]
        
        _ = try await SupabaseManager.shared.makeRequest(
            endpoint: "/rest/v1/user_ai_preferences?on_conflict=user_id",
            method: "POST",
            body: jsonData,
            headers: headers,
            expecting: Data.self
        )
        
        print("✅ 用户偏好保存成功")
    }
    
    // MARK: - 批量修复所有问题
    func performCompleteFix(userId: String, email: String) async {
        print("🔧 开始执行完整修复...")
        
        do {
            // 1. 确保profile存在
            try await ensureUserProfileExists(userId: userId, email: email)
            
            // 2. 创建默认会话
            let sessionId = UUID().uuidString
            try await safeCreateSession(
                sessionId: sessionId,
                userId: userId,
                email: email,
                title: "默认会话"
            )
            
            // 3. 创建默认偏好设置
            let defaultPreferences: [String: Any] = [
                "conversation_style": "balanced",
                "response_length": "medium",
                "enable_suggestions": true,
                "preferred_topics": []
            ]
            try await safeSaveUserPreferences(userId: userId, preferences: defaultPreferences)
            
            // 4. 创建默认配额
            try await createDefaultQuota(userId: userId)
            
            print("✅ 完整修复成功！")
        } catch {
            print("❌ 修复过程中出错: \(error)")
        }
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
        
        // 使用UPSERT
        let headers = [
            "Prefer": "resolution=merge-duplicates"
        ]
        
        _ = try await SupabaseManager.shared.makeRequest(
            endpoint: "/rest/v1/user_ai_quotas?on_conflict=user_id",
            method: "POST",
            body: jsonData,
            headers: headers,
            expecting: Data.self
        )
        
        print("✅ 配额创建成功")
    }
}

// MARK: - 扩展：修复现有的错误调用
extension SupabaseManager {
    // 重写有问题的方法，使用安全版本
    func safeCreateChatSession(sessionId: String, userId: String, title: String?) async throws {
        // 获取用户email（假设从某处获取）
        let email = "test@example.com" // 这里需要实际的email
        try await DatabaseFixManager.shared.safeCreateSession(
            sessionId: sessionId,
            userId: userId,
            email: email,
            title: title
        )
    }
    
    func safeSaveChatMessage(
        messageId: String,
        sessionId: String,
        userId: String,
        role: String,
        content: String
    ) async throws {
        let email = "test@example.com" // 这里需要实际的email
        try await DatabaseFixManager.shared.safeSaveMessage(
            messageId: messageId,
            sessionId: sessionId,
            userId: userId,
            email: email,
            role: role,
            content: content
        )
    }
}