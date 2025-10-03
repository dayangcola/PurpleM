//
//  DataSyncManager.swift
//  PurpleM
//
//  数据同步管理器 - 处理本地与云端数据同步
//

import Foundation
import SwiftUI

// MARK: - 数据同步管理器
@MainActor
class DataSyncManager: ObservableObject {
    static let shared = DataSyncManager()
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    private init() {}
    
    // MARK: - 同步用户偏好（使用UPSERT）
    func syncUserPreferences(userId: String, preferences: [String: Any]) async throws {
        print("🔄 同步用户偏好...")
        
        // 构建正确的数据格式
        var preferencesData: [String: Any] = [
            "user_id": userId,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        // 映射字段到数据库列
        if let style = preferences["conversationStyle"] as? String {
            preferencesData["conversation_style"] = style
        }
        if let length = preferences["responseLength"] as? String {
            preferencesData["response_length"] = length
        }
        if let complexity = preferences["languageComplexity"] as? String {
            preferencesData["language_complexity"] = complexity
        }
        if let topics = preferences["preferredTopics"] as? [String] {
            preferencesData["preferred_topics"] = topics
        }
        if let avoided = preferences["avoidedTopics"] as? [String] {
            preferencesData["avoided_topics"] = avoided
        }
        if let suggestions = preferences["enableSuggestions"] as? Bool {
            preferencesData["enable_suggestions"] = suggestions
        }
        
        // 使用原生UPSERT，避免先PATCH后POST的低效模式
        let endpoint = "/rest/v1/user_ai_preferences"
        
        do {
            // 直接使用POST带on_conflict参数来实现UPSERT
            guard let url = URL(string: "\(SupabaseManager.shared.baseURL)\(endpoint)?on_conflict=user_id") else {
                throw APIError.invalidURL
            }
            
            let bodyData = try JSONSerialization.data(withJSONObject: preferencesData)
            let userToken = KeychainManager.shared.getAccessToken()
            
            let request = SupabaseAPIHelper.createRequest(
                url: url,
                method: "POST",
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken,
                body: bodyData,
                headers: ["Prefer": "resolution=merge-duplicates"]
            )
            
            _ = try await SupabaseAPIHelper.executeRequest(request)
            print("✅ 偏好同步成功（UPSERT）")
        } catch {
            // 如果UPSERT失败，记录详细错误
            print("❌ 偏好同步失败: \(error)")
            throw error
        }
    }
    
    // MARK: - 同步记忆数据
    func syncMemoryData(userId: String, memoryData: [String: Any]) async throws {
        print("🔄 同步记忆数据...")
        
        // 使用DatabaseFixManager的安全方法
        try await DatabaseFixManager.shared.safeSyncMemoryData(
            userId: userId,
            memoryData: memoryData
        )
        
        print("✅ 记忆数据同步成功")
    }
    
    // MARK: - 同步星盘数据
    func syncStarChart(userId: String, chartData: [String: Any]) async throws {
        print("🔄 同步星盘数据...")
        
        // 构建星盘记录
        let chartRecord: [String: Any] = [
            "id": UUID().uuidString,
            "user_id": userId,
            "name": chartData["name"] ?? "未命名",
            "birth_date": chartData["birthDate"] ?? "",
            "birth_time": chartData["birthTime"] ?? "",
            "birth_place": chartData["birthPlace"] ?? "",
            "gender": chartData["gender"] ?? "未知",
            "chart_type": chartData["type"] ?? "natal",
            "chart_data": chartData,  // 存储完整的命盘数据
            "is_primary": chartData["isPrimary"] ?? false,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let userToken = KeychainManager.shared.getAccessToken()
        _ = try await SupabaseAPIHelper.post(
            endpoint: "/rest/v1/star_charts",
            baseURL: SupabaseManager.shared.baseURL,
            authType: .authenticated,
            apiKey: SupabaseManager.shared.apiKey,
            userToken: userToken,
            body: chartRecord,
            useFieldMapping: false
        )
        
        print("✅ 星盘数据同步成功")
    }
    
    // MARK: - 批量同步
    func performFullSync(userId: String) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        print("🚀 开始完整同步...")
        
        do {
            // 1. 同步用户偏好
            if let preferences = UserDefaults.standard.dictionary(forKey: "userPreferences_\(userId)") {
                try await syncUserPreferences(userId: userId, preferences: preferences)
            }
            
            // 2. 同步记忆数据
            if let memoryData = UserDefaults.standard.dictionary(forKey: "userMemory_\(userId)") {
                try await syncMemoryData(userId: userId, memoryData: memoryData)
            }
            
            // 3. 同步星盘数据
            if let chartsData = UserDefaults.standard.array(forKey: "starCharts_\(userId)") as? [[String: Any]] {
                for chart in chartsData {
                    if let needsSync = chart["needsSync"] as? Bool, needsSync {
                        try await syncStarChart(userId: userId, chartData: chart)
                    }
                }
            }
            
            lastSyncTime = Date()
            syncError = nil
            print("✅ 完整同步成功")
            
        } catch {
            syncError = error.localizedDescription
            print("❌ 同步失败: \(error)")
        }
    }
    
    // MARK: - 处理离线队列中的同步操作
    func processOfflineSyncOperation(operation: OfflineOperation) async throws {
        switch operation {
        case .syncMemory(let userId, let data):
            // 处理记忆同步
            try await syncMemoryData(userId: userId, memoryData: data)
            
        case .updatePreferences(let userId, let preferences):
            // 处理偏好更新
            try await syncUserPreferences(userId: userId, preferences: preferences)
            
        default:
            // 其他操作交给原始处理器
            throw SyncError.unsupportedOperation
        }
    }
}

// MARK: - 同步错误
enum SyncError: LocalizedError {
    case unsupportedOperation
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedOperation:
            return "不支持的同步操作"
        case .syncFailed(let reason):
            return "同步失败: \(reason)"
        }
    }
}