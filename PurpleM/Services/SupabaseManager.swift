//
//  SupabaseManager.swift
//  PurpleM
//
//  Supabase云端数据管理器
//

import Foundation
import Combine

// MARK: - 数据模型
struct ChatSessionDB: Codable {
    let id: String
    let userId: String
    let title: String?
    let contextSummary: String?
    let sessionType: String
    let modelPreferences: [String: Any]?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case contextSummary = "context_summary"
        case sessionType = "session_type"
        case modelPreferences = "model_preferences"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 自定义编解码以处理 [String: Any]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        contextSummary = try container.decodeIfPresent(String.self, forKey: .contextSummary)
        sessionType = try container.decode(String.self, forKey: .sessionType)
        
        // 处理JSON对象
        if let prefsData = try? container.decodeIfPresent(Data.self, forKey: .modelPreferences),
           let prefs = try? JSONSerialization.jsonObject(with: prefsData) as? [String: Any] {
            modelPreferences = prefs
        } else {
            modelPreferences = nil
        }
        
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(contextSummary, forKey: .contextSummary)
        try container.encode(sessionType, forKey: .sessionType)
        
        if let prefs = modelPreferences,
           let prefsData = try? JSONSerialization.data(withJSONObject: prefs) {
            try container.encode(prefsData, forKey: .modelPreferences)
        }
        
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct ChatMessageDB: Codable {
    let id: String
    let sessionId: String
    let userId: String
    let role: String
    let content: String
    let contentType: String
    let metadata: [String: Any]?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case role
        case content
        case contentType = "content_type"
        case metadata
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        userId = try container.decode(String.self, forKey: .userId)
        role = try container.decode(String.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType) ?? "text"
        
        if let metaData = try? container.decodeIfPresent(Data.self, forKey: .metadata),
           let meta = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any] {
            metadata = meta
        } else {
            metadata = nil
        }
        
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(userId, forKey: .userId)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(contentType, forKey: .contentType)
        
        if let meta = metadata,
           let metaData = try? JSONSerialization.data(withJSONObject: meta) {
            try container.encode(metaData, forKey: .metadata)
        }
        
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct UserAIPreferencesDB: Codable {
    let id: String?
    let userId: String
    let conversationStyle: String?
    let responseLength: String?
    let customPersonality: Data? // 存储为JSON Data
    let preferredTopics: [String]?
    let enableSuggestions: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case conversationStyle = "conversation_style"
        case responseLength = "response_length"
        case customPersonality = "custom_personality"
        case preferredTopics = "preferred_topics"
        case enableSuggestions = "enable_suggestions"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: String? = nil,
         userId: String,
         conversationStyle: String? = "balanced",
         responseLength: String? = "medium",
         customPersonality: [String: Any]? = nil,
         preferredTopics: [String]? = nil,
         enableSuggestions: Bool? = true,
         createdAt: String? = nil,
         updatedAt: String? = nil) {
        self.id = id
        self.userId = userId
        self.conversationStyle = conversationStyle
        self.responseLength = responseLength
        
        // 将字典转换为JSON Data
        if let personality = customPersonality {
            self.customPersonality = try? JSONSerialization.data(withJSONObject: personality)
        } else {
            self.customPersonality = nil
        }
        
        self.preferredTopics = preferredTopics
        self.enableSuggestions = enableSuggestions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func getCustomPersonalityDict() -> [String: Any]? {
        guard let data = customPersonality else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

struct UserQuotaDB: Codable {
    let userId: String
    let subscriptionTier: String
    let dailyLimit: Int
    let dailyUsed: Int
    let monthlyLimit: Int
    let monthlyUsed: Int
    let totalTokensUsed: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case subscriptionTier = "subscription_tier"
        case dailyLimit = "daily_limit"
        case dailyUsed = "daily_used"
        case monthlyLimit = "monthly_limit"
        case monthlyUsed = "monthly_used"
        case totalTokensUsed = "total_tokens_used"
    }
}

// MARK: - API响应模型
struct SupabaseResponse<T: Codable>: Codable {
    let data: T?
    let error: SupabaseError?
}

struct SupabaseError: Codable, LocalizedError {
    let message: String
    let code: String?
    
    var errorDescription: String? {
        return message
    }
}

// MARK: - SupabaseManager
@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    @Published var isConnected = false
    @Published var currentSession: ChatSessionDB?
    @Published var userQuota: UserQuotaDB?
    
    private var cancellables = Set<AnyCancellable>()
    private let baseURL: String
    private let apiKey: String
    private var authToken: String?
    
    private init() {
        // 从配置文件读取
        self.baseURL = SupabaseConfig.url.absoluteString
        self.apiKey = SupabaseConfig.anonKey
        
        // 监听认证状态变化
        setupAuthListener()
    }
    
    private func setupAuthListener() {
        // 简化：直接使用AuthManager的状态
        // 实际项目中应该通过AuthManager获取token
        if AuthManager.shared.isAuthenticated {
            self.isConnected = true
            // 这里应该从AuthManager获取实际的token
            // self.authToken = AuthManager.shared.authToken
        }
    }
    
    // MARK: - 网络请求基础方法
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        expecting: T.Type
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)/rest/v1/\(endpoint)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        // 添加认证token
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 检查HTTP状态码
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            let error = try? JSONDecoder().decode(SupabaseError.self, from: data)
            throw error ?? URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - RPC调用
    private func callRPC<T: Codable>(
        function: String,
        params: [String: Any],
        expecting: T.Type
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)/rest/v1/rpc/\(function)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: params)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - 会话管理
    func createChatSession(
        userId: String,
        sessionType: String,
        title: String? = nil
    ) async throws -> ChatSessionDB {
        let session = [
            "id": UUID().uuidString,
            "user_id": userId,
            "session_type": sessionType,
            "title": title ?? "对话 - \(Date().formatted())",
            "model_preferences": [
                "mode": SettingsManager.shared.aiMode.rawValue,
                "emotion_detection": true,
                "memory_enabled": true
            ],
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ] as [String : Any]
        
        let jsonData = try JSONSerialization.data(withJSONObject: session)
        
        let response = try await makeRequest(
            endpoint: "chat_sessions",
            method: "POST",
            body: jsonData,
            expecting: [ChatSessionDB].self
        )
        
        guard let newSession = response.first else {
            throw SupabaseError(message: "创建会话失败", code: "SESSION_CREATE_FAILED")
        }
        
        self.currentSession = newSession
        return newSession
    }
    
    func getCurrentOrCreateSession(userId: String) async throws -> ChatSessionDB {
        // 如果已有当前会话，直接返回
        if let session = currentSession {
            return session
        }
        
        // 查找今天的会话
        let today = Calendar.current.startOfDay(for: Date())
        let todayString = ISO8601DateFormatter().string(from: today)
        
        let endpoint = "chat_sessions?user_id=eq.\(userId)&created_at=gte.\(todayString)&order=created_at.desc&limit=1"
        
        do {
            let sessions = try await makeRequest(
                endpoint: endpoint,
                expecting: [ChatSessionDB].self
            )
            
            if let existingSession = sessions.first {
                self.currentSession = existingSession
                return existingSession
            }
        } catch {
            print("获取会话失败: \(error)")
        }
        
        // 创建新会话
        let scene = EnhancedAIService.shared.currentScene.rawValue
        return try await createChatSession(userId: userId, sessionType: scene)
    }
    
    // MARK: - 消息管理
    func saveMessage(
        sessionId: String,
        userId: String,
        role: String,
        content: String,
        metadata: [String: Any]? = nil
    ) async throws {
        let message = [
            "id": UUID().uuidString,
            "session_id": sessionId,
            "user_id": userId,
            "role": role,
            "content": content,
            "content_type": "text",
            "metadata": metadata ?? [:],
            "created_at": ISO8601DateFormatter().string(from: Date())
        ] as [String : Any]
        
        let jsonData = try JSONSerialization.data(withJSONObject: message)
        
        _ = try await makeRequest(
            endpoint: "chat_messages",
            method: "POST",
            body: jsonData,
            expecting: [ChatMessageDB].self
        )
    }
    
    func getRecentMessages(userId: String, limit: Int = 20) async throws -> [ChatMessageDB] {
        let endpoint = "chat_messages?user_id=eq.\(userId)&order=created_at.desc&limit=\(limit)"
        
        return try await makeRequest(
            endpoint: endpoint,
            expecting: [ChatMessageDB].self
        )
    }
    
    // MARK: - 用户偏好管理
    func saveUserPreferences(
        userId: String,
        preferences: UserAIPreferencesDB
    ) async throws {
        let jsonData = try JSONEncoder().encode(preferences)
        
        _ = try await makeRequest(
            endpoint: "user_ai_preferences",
            method: "POST",
            body: jsonData,
            expecting: [UserAIPreferencesDB].self
        )
    }
    
    func getUserPreferences(userId: String) async throws -> UserAIPreferencesDB? {
        let endpoint = "user_ai_preferences?user_id=eq.\(userId)"
        
        let preferences = try await makeRequest(
            endpoint: endpoint,
            expecting: [UserAIPreferencesDB].self
        )
        
        return preferences.first
    }
    
    // MARK: - 配额管理
    func getUserQuota(userId: String) async throws -> UserQuotaDB? {
        let endpoint = "user_ai_quotas?user_id=eq.\(userId)"
        
        let quotas = try await makeRequest(
            endpoint: endpoint,
            expecting: [UserQuotaDB].self
        )
        
        let quota = quotas.first
        self.userQuota = quota
        return quota
    }
    
    func checkQuotaAvailable() async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id else { return false }
        
        do {
            let quota = try await getUserQuota(userId: userId)
            
            if let q = quota {
                // 无限制套餐
                if q.subscriptionTier == "unlimited" {
                    return true
                }
                // 检查每日限额
                return q.dailyUsed < q.dailyLimit
            }
        } catch {
            print("检查配额失败: \(error)")
        }
        
        return false
    }
    
    func incrementQuotaUsage(userId: String, tokens: Int) async throws -> Bool {
        let result = try await callRPC(
            function: "increment_quota_usage",
            params: [
                "p_user_id": userId,
                "p_tokens": tokens
            ],
            expecting: Bool.self
        )
        
        // 刷新配额信息
        _ = try? await getUserQuota(userId: userId)
        
        return result
    }
    
    // MARK: - 知识库搜索
    struct KnowledgeSearchResult: Codable {
        let term: String?
        let definition: String?
    }
    
    func searchKnowledge(query: String) async throws -> [[String: Any]] {
        // 由于RPC函数返回类型问题，暂时返回空数组
        // 实际使用时需要修复数据库函数的返回类型
        return []
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let quotaExceeded = Notification.Name("quotaExceeded")
    static let sessionCreated = Notification.Name("sessionCreated")
}