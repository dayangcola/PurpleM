//
//  AuthSyncManager.swift
//  PurpleM
//
//  Supabase Auth与数据库profiles表同步管理器
//

import Foundation

@MainActor
class AuthSyncManager {
    static let shared = AuthSyncManager()
    
    private init() {}
    
    // MARK: - 确保Auth用户与Profile同步
    private var syncLocks: [String: Bool] = [:]
    private let lockQueue = DispatchQueue(label: "com.purplem.authsync.lock")
    
    func ensureAuthUserProfileSync(authUserId: String, email: String, username: String? = nil) async throws {
        // 使用锁避免竞态条件
        let isAlreadySyncing = lockQueue.sync { () -> Bool in
            if syncLocks[authUserId] == true {
                return true
            }
            syncLocks[authUserId] = true
            return false
        }
        
        if isAlreadySyncing {
            print("⚠️ 用户 \(authUserId) 正在同步中，跳过重复同步")
            return
        }
        
        defer {
            lockQueue.sync {
                syncLocks[authUserId] = false
            }
        }
        
        print("🔄 同步Auth用户到Profile表...")
        
        // 1. 使用UPSERT直接创建或更新Profile，避免先查询再操作
        try await createProfileForAuthUser(
            userId: authUserId,
            email: email,
            username: username
        )
        
        // 2. 确保相关表的默认数据存在
        try await ensureRelatedTablesInitialized(userId: authUserId)
    }
    
    // MARK: - 检查Profile是否存在
    private func checkProfileExists(userId: String) async -> Bool {
        do {
            // 使用SupabaseAPIHelper来确保正确的认证
            let endpoint = "/rest/v1/profiles?id=eq.\(userId)&select=id"
            let userToken = KeychainManager.shared.getAccessToken()
            
            // 使用authenticated类型确保包含Bearer token
            guard let data = try await SupabaseAPIHelper.get(
                endpoint: endpoint,
                baseURL: SupabaseManager.shared.baseURL,
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken
            ) else {
                print("❌ 未获取到Profile数据")
                return false
            }
            let profiles = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
            return !profiles.isEmpty
        } catch {
            print("❌ 检查Profile失败: \(error)")
            return false
        }
    }
    
    // MARK: - 为Auth用户创建Profile（使用UPSERT）
    private func createProfileForAuthUser(userId: String, email: String, username: String?) async throws {
        let profileData: [String: Any] = [
            "id": userId,  // 使用Auth用户的ID
            "email": email,
            "username": username ?? email.components(separatedBy: "@").first ?? "用户",
            "subscription_tier": "free",
            // quota_limit和quota_used移到user_ai_quotas表
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: profileData)
        
        do {
            let userToken = KeychainManager.shared.getAccessToken()
            
            // 使用authenticated类型确保使用正确的认证
            if let responseData = try await SupabaseAPIHelper.post(
                endpoint: "/rest/v1/profiles?on_conflict=id",
                baseURL: SupabaseManager.shared.baseURL,
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken,
                body: profileData,
                useFieldMapping: false  // 我们已经手动设置了字段名
            ) {
                let profiles = (try? JSONSerialization.jsonObject(with: responseData) as? [[String: Any]]) ?? []
                
                if profiles.isEmpty {
                    print("⚠️ Profile创建响应为空，但可能已成功")
                } else {
                    print("✅ Profile创建成功: \(profiles.first?["id"] ?? "未知")")
                }
            } else {
                print("⚠️ Profile创建未返回数据")
            }
        } catch {
            // 409错误表示已存在，可以忽略
            if let apiError = error as? APIError,
               case .serverError(let code) = apiError,
               code == 409 {
                print("ℹ️ Profile已存在（409），跳过创建")
            } else {
                throw error
            }
        }
    }
    
    // MARK: - 更新Profile信息
    private func updateProfileInfo(userId: String, email: String, username: String?) async throws {
        var updateData: [String: Any] = [
            "email": email,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let username = username {
            updateData["username"] = username
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: updateData)
        
        let userToken = KeychainManager.shared.getAccessToken()
        _ = try await SupabaseAPIHelper.patch(
            endpoint: "/rest/v1/profiles?id=eq.\(userId)",
            baseURL: SupabaseManager.shared.baseURL,
            authType: .authenticated,
            apiKey: SupabaseManager.shared.apiKey,
            userToken: userToken,
            body: updateData,
            useFieldMapping: false
        )
        
        print("✅ Profile信息已更新")
    }
    
    // MARK: - 确保相关表初始化
    private func ensureRelatedTablesInitialized(userId: String) async throws {
        // 1. 初始化AI配额
        try await initializeUserQuota(userId: userId)
        
        // 2. 初始化AI偏好设置
        try await initializeUserPreferences(userId: userId)
        
        // 3. 创建默认会话
        try await createDefaultSession(userId: userId)
    }
    
    // MARK: - 初始化用户配额
    private func initializeUserQuota(userId: String) async throws {
        // 使用正确的日期格式化器
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let quotaData: [String: Any] = [
            "user_id": userId,
            "subscription_tier": "free",
            "daily_limit": 100,
            "daily_used": 0,
            "monthly_limit": 3000,
            "monthly_used": 0,
            "total_tokens_used": 0,
            "total_cost_credits": 0.0,
            "daily_reset_at": dateFormatter.string(from: Date()),
            "monthly_reset_at": dateFormatter.string(from: Date()),
            "bonus_credits": 0.0,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: quotaData)
        
        // 使用UPSERT
        let headers = [
            "Prefer": "resolution=merge-duplicates"
        ]
        
        do {
            let userToken = KeychainManager.shared.getAccessToken()
            _ = try await SupabaseAPIHelper.post(
                endpoint: "/rest/v1/user_ai_quotas?on_conflict=user_id",
                baseURL: SupabaseManager.shared.baseURL,
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken,
                body: quotaData,
                useFieldMapping: false
            )
            print("✅ 用户配额初始化成功")
        } catch {
            // 409表示已存在，可以忽略
            if let apiError = error as? APIError,
               case .serverError(let code) = apiError,
               code == 409 {
                print("ℹ️ 配额记录已存在")
            } else {
                print("⚠️ 配额初始化失败: \(error)")
            }
        }
    }
    
    // MARK: - 初始化用户偏好设置
    private func initializeUserPreferences(userId: String) async throws {
        var preferencesData: [String: Any] = [
            "user_id": userId,
            "conversation_style": "balanced",
            "response_length": "medium",
            "language_complexity": "normal",
            "use_terminology": true,
            "auto_include_chart": true,
            "preferred_topics": [],
            "avoided_topics": [],
            "enable_suggestions": true,
            "enable_voice_input": false,
            "enable_markdown": true,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        // custom_personality is optional, only include if needed
        // Database will use NULL as default
        
        let jsonData = try JSONSerialization.data(withJSONObject: preferencesData)
        
        // 使用UPSERT
        let headers = [
            "Prefer": "resolution=merge-duplicates"
        ]
        
        do {
            let userToken = KeychainManager.shared.getAccessToken()
            _ = try await SupabaseAPIHelper.post(
                endpoint: "/rest/v1/user_ai_preferences?on_conflict=user_id",
                baseURL: SupabaseManager.shared.baseURL,
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken,
                body: preferencesData,
                useFieldMapping: false
            )
            print("✅ 用户偏好设置初始化成功")
        } catch {
            // 409表示已存在，可以忽略
            if let apiError = error as? APIError,
               case .serverError(let code) = apiError,
               code == 409 {
                print("ℹ️ 偏好设置已存在")
            } else {
                print("⚠️ 偏好设置初始化失败: \(error)")
            }
        }
    }
    
    // MARK: - 创建默认会话
    private func createDefaultSession(userId: String) async throws {
        // 检查是否已有会话
        let checkEndpoint = "/rest/v1/chat_sessions?user_id=eq.\(userId)&select=id&limit=1"
        
        do {
            let userToken = KeychainManager.shared.getAccessToken()
            guard let data = try await SupabaseAPIHelper.get(
                endpoint: checkEndpoint,
                baseURL: SupabaseManager.shared.baseURL,
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken
            ) else {
                print("⚠️ 未获取到会话数据")
                return
            }
            let sessions = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
            
            if !sessions.isEmpty {
                print("ℹ️ 用户已有会话，跳过创建默认会话")
                return
            }
        } catch {
            print("⚠️ 检查会话失败: \(error)")
        }
        
        // 创建默认会话
        let sessionData: [String: Any] = [
            "id": UUID().uuidString,
            "user_id": userId,
            "title": "欢迎使用紫微斗数",
            "session_type": "general",
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: sessionData)
        
        do {
            let userToken = KeychainManager.shared.getAccessToken()
            _ = try await SupabaseAPIHelper.post(
                endpoint: "/rest/v1/chat_sessions",
                baseURL: SupabaseManager.shared.baseURL,
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken,
                body: sessionData,
                useFieldMapping: false
            )
            print("✅ 默认会话创建成功")
        } catch {
            print("⚠️ 默认会话创建失败: \(error)")
        }
    }
    
    // MARK: - 处理注册后的初始化
    func handlePostRegistration(user: User) async {
        print("🎉 处理新用户注册后初始化...")
        
        do {
            // 确保所有必要的数据都已创建
            try await ensureAuthUserProfileSync(
                authUserId: user.id,
                email: user.email,
                username: user.username
            )
            
            // 发送欢迎消息（可选）
            await sendWelcomeMessage(userId: user.id)
            
            print("✅ 新用户初始化完成")
        } catch {
            print("❌ 新用户初始化失败: \(error)")
        }
    }
    
    // MARK: - 发送欢迎消息
    private func sendWelcomeMessage(userId: String) async {
        // 获取用户的默认会话
        let endpoint = "/rest/v1/chat_sessions?user_id=eq.\(userId)&select=id&limit=1"
        
        do {
            let userToken = KeychainManager.shared.getAccessToken()
            guard let data = try await SupabaseAPIHelper.get(
                endpoint: endpoint,
                baseURL: SupabaseManager.shared.baseURL,
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken
            ) else {
                print("⚠️ 未找到默认会话，跳过欢迎消息")
                return
            }
            let sessions = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
            
            guard let sessionId = sessions.first?["id"] as? String else {
                print("⚠️ 未找到默认会话，跳过欢迎消息")
                return
            }
            
            // 创建欢迎消息
            let messageData: [String: Any] = [
                "id": UUID().uuidString,
                "session_id": sessionId,
                "user_id": userId,
                "role": "assistant",
                "content": """
                欢迎来到紫微斗数智能助手！🌟
                
                我是您的专属命理顾问，可以帮助您：
                • 解析命盘，了解您的性格特质和人生轨迹
                • 提供每日运势分析和建议
                • 解答关于事业、感情、健康等方面的疑问
                • 学习紫微斗数的基础知识
                
                请问有什么可以帮助您的吗？
                """,
                "content_type": "text",
                "created_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: messageData)
            
            _ = try await SupabaseAPIHelper.post(
                endpoint: "/rest/v1/chat_messages",
                baseURL: SupabaseManager.shared.baseURL,
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken,
                body: messageData,
                useFieldMapping: false
            )
            
            print("✅ 欢迎消息已发送")
        } catch {
            print("⚠️ 发送欢迎消息失败: \(error)")
        }
    }
}

// MARK: - AuthManager扩展
extension AuthManager {
    // 修改signIn方法，使用新的同步管理器
    func syncUserAfterAuth(user: User) async {
        do {
            try await AuthSyncManager.shared.ensureAuthUserProfileSync(
                authUserId: user.id,
                email: user.email,
                username: user.username
            )
            print("✅ 用户数据同步成功")
        } catch {
            print("❌ 用户数据同步失败: \(error)")
        }
    }
}