// 修复数据库约束和外键问题
// 这个文件包含所有需要的修复

import Foundation

// MARK: - 1. 修复session_type映射问题
// ConversationScene使用中文rawValue，但数据库需要英文
extension ConversationScene {
    var databaseValue: String {
        switch self {
        case .greeting:
            return "general"
        case .chartReading:
            return "chart_reading"
        case .fortuneTelling:
            return "fortune"
        case .learning:
            return "consultation"
        case .support:
            return "consultation"
        case .dailyChat:
            return "general"
        }
    }
}

// MARK: - 2. 修复TestSupabaseConnection.swift中的sessionType
// 文件：PurpleM/TestSupabaseConnection.swift
// 第213行
// 修改前：sessionType: "test",
// 修改后：sessionType: "general",

// MARK: - 3. 修复SupabaseManager中的createSessionForScene
// 文件：PurpleM/Services/SupabaseManager.swift
// 第471行
// 修改前：return try await createChatSession(userId: userId, sessionType: scene)
// 修改后：return try await createChatSession(userId: userId, sessionType: ConversationScene(rawValue: scene)?.databaseValue ?? "general")

// MARK: - 4. 修复外键依赖 - 确保先创建用户profile
extension SupabaseManager {
    func ensureUserProfile(userId: String) async throws {
        let endpoint = "/rest/v1/profiles"
        
        // 先尝试获取用户profile
        let getEndpoint = "\(endpoint)?id=eq.\(userId)"
        let response = try await makeRequest(
            endpoint: getEndpoint,
            method: "GET"
        )
        
        // 如果不存在，创建新的profile
        if let data = response.data,
           let profiles = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           profiles.isEmpty {
            
            let profileData: [String: Any] = [
                "id": userId,
                "email": "\(userId)@temp.com", // 临时邮箱
                "created_at": ISO8601DateFormatter().string(from: Date()),
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            _ = try await makeRequest(
                endpoint: endpoint,
                method: "POST",
                body: profileData
            )
        }
    }
    
    // 创建会话前先确保用户存在
    func createChatSessionSafe(
        userId: String,
        sessionType: String,
        title: String?
    ) async throws -> ChatSession {
        // 先确保用户profile存在
        try await ensureUserProfile(userId: userId)
        
        // 然后创建会话
        return try await createChatSession(
            userId: userId,
            sessionType: sessionType,
            title: title
        )
    }
}

// MARK: - 5. 修复UPSERT操作 - 处理重复键冲突
extension SupabaseManager {
    func upsertUserPreferences(
        userId: String,
        preferences: [String: Any]
    ) async throws {
        let endpoint = "/rest/v1/user_ai_preferences"
        
        // 使用PostgreSQL的ON CONFLICT语法
        var request = URLRequest(url: URL(string: "\(baseURL)\(endpoint)?on_conflict=user_id")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        var data = preferences
        data["user_id"] = userId
        data["updated_at"] = ISO8601DateFormatter().string(from: Date())
        
        request.httpBody = try JSONSerialization.data(withJSONObject: data)
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 409 {
            // 如果还是冲突，尝试更新
            try await updateUserPreferences(userId: userId, preferences: preferences)
        }
    }
    
    private func updateUserPreferences(
        userId: String,
        preferences: [String: Any]
    ) async throws {
        let endpoint = "/rest/v1/user_ai_preferences?user_id=eq.\(userId)"
        
        var data = preferences
        data["updated_at"] = ISO8601DateFormatter().string(from: Date())
        
        _ = try await makeRequest(
            endpoint: endpoint,
            method: "PATCH",
            body: data
        )
    }
}

// MARK: - 6. 修复JSON解析问题
extension SupabaseManager {
    func parseResponse<T: Decodable>(_ data: Data?, as type: T.Type) throws -> T? {
        guard let data = data else { return nil }
        
        // 检查是否为空响应
        if data.isEmpty {
            print("📝 Empty response received")
            return nil
        }
        
        // 尝试解析
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            // 如果解析失败，尝试打印原始数据
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📝 Raw JSON: \(jsonString)")
            }
            
            // 特殊处理：201响应但无内容
            if let httpResponse = URLSession.shared.configuration.httpAdditionalHeaders as? HTTPURLResponse,
               httpResponse.statusCode == 201 {
                return nil // 成功创建但无返回内容
            }
            
            throw error
        }
    }
}

// MARK: - 7. 修复星盘同步数据格式
extension SupabaseManager {
    func syncStarChart(userId: String, chartData: [String: Any]) async throws {
        let endpoint = "/rest/v1/star_charts"
        
        // 确保数据格式正确
        let chartRecord: [String: Any] = [
            "id": UUID().uuidString,
            "user_id": userId,
            "chart_data": chartData, // 作为JSON对象存储
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        _ = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: chartRecord
        )
    }
    
    // 获取星盘时正确解析
    func getStarCharts(userId: String) async throws -> [[String: Any]] {
        let endpoint = "/rest/v1/star_charts?user_id=eq.\(userId)"
        let response = try await makeRequest(endpoint: endpoint, method: "GET")
        
        if let data = response.data {
            // 期望返回数组
            if let charts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return charts
            }
        }
        
        return []
    }
}