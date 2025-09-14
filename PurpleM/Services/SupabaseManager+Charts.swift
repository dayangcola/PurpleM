//
//  SupabaseManager+Charts.swift
//  PurpleM
//
//  星盘云端存储管理扩展
//

import Foundation
import SwiftUI

// MARK: - 星盘云端模型
struct CloudChartData: Codable {
    let id: String?
    let userId: String
    let chartData: ChartDataPayload
    let chartImageUrl: String?
    let interpretationSummary: String?
    let version: String
    let isPrimary: Bool
    let generatedAt: Date
    let updatedAt: Date
    
    // CodingKeys确保与数据库字段映射正确
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case chartData = "chart_data"
        case chartImageUrl = "chart_image_url"
        case interpretationSummary = "interpretation_summary"
        case version
        case isPrimary = "is_primary"
        case generatedAt = "generated_at"  // star_charts表使用generated_at
        case updatedAt = "updated_at"
    }
    
    // 自定义解码器来处理日期字符串
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        chartData = try container.decode(ChartDataPayload.self, forKey: .chartData)
        chartImageUrl = try container.decodeIfPresent(String.self, forKey: .chartImageUrl)
        interpretationSummary = try container.decodeIfPresent(String.self, forKey: .interpretationSummary)
        version = try container.decode(String.self, forKey: .version)
        isPrimary = try container.decode(Bool.self, forKey: .isPrimary)
        
        // 解析generatedAt - 支持ISO8601字符串格式
        if let dateString = try? container.decode(String.self, forKey: .generatedAt) {
            let formatter = ISO8601DateFormatter()
            // 尝试带时区的格式
            formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
            if let date = formatter.date(from: dateString) {
                generatedAt = date
            } else {
                // 尝试不带时区的格式
                formatter.formatOptions = [.withInternetDateTime]
                generatedAt = formatter.date(from: dateString) ?? Date()
            }
        } else if let timestamp = try? container.decode(Double.self, forKey: .generatedAt) {
            // 支持时间戳格式
            generatedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        }
        
        // 解析updatedAt - 支持ISO8601字符串格式
        if let dateString = try? container.decode(String.self, forKey: .updatedAt) {
            let formatter = ISO8601DateFormatter()
            // 尝试带时区的格式
            formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
            if let date = formatter.date(from: dateString) {
                updatedAt = date
            } else {
                // 尝试不带时区的格式
                formatter.formatOptions = [.withInternetDateTime]
                updatedAt = formatter.date(from: dateString) ?? Date()
            }
        } else if let timestamp = try? container.decode(Double.self, forKey: .updatedAt) {
            // 支持时间戳格式
            updatedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }
    
    // 自定义编码器
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(chartData, forKey: .chartData)
        try container.encodeIfPresent(chartImageUrl, forKey: .chartImageUrl)
        try container.encodeIfPresent(interpretationSummary, forKey: .interpretationSummary)
        try container.encode(version, forKey: .version)
        try container.encode(isPrimary, forKey: .isPrimary)
        
        // 编码为ISO8601字符串
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        try container.encode(formatter.string(from: generatedAt), forKey: .generatedAt)
        try container.encode(formatter.string(from: updatedAt), forKey: .updatedAt)
    }
    
    // 转换为本地ChartData
    func toLocalChartData() -> ChartData? {
        // 如果没有userInfo，返回nil
        guard let userInfo = chartData.userInfo else {
            return nil
        }
        
        return ChartData(
            jsonData: chartData.jsonData,
            generatedDate: generatedAt,
            userInfo: userInfo
        )
    }
}

struct ChartDataPayload: Codable {
    let jsonData: String
    let userInfo: UserInfo?  // 可选，因为返回的数据可能没有这个字段
    
    enum CodingKeys: String, CodingKey {
        case jsonData = "jsonData"
        case userInfo = "user_info"  // 映射到正确的字段名
    }
}

// MARK: - SupabaseManager 星盘扩展
extension SupabaseManager {
    
    // MARK: - 获取用户星盘
    func getUserChart(userId: String) async throws -> CloudChartData? {
        let endpoint = "/rest/v1/star_charts"
        let queryParams = [
            "user_id": "eq.\(userId)",
            "is_primary": "eq.true"
        ]
        
        print("🔍 查询星盘数据: userId=\(userId)")
        
        // 获取用户token（从UserDefaults中获取）
        let userToken = KeychainManager.shared.getAccessToken()
        
        guard let data = try await SupabaseAPIHelper.get(
            endpoint: endpoint,
            baseURL: baseURL,
            authType: .authenticated,
            apiKey: apiKey,
            userToken: userToken,
            queryParams: queryParams
        ) else {
            print("❌ 获取星盘数据失败：无响应")
            return nil
        }
        
        print("📦 原始响应数据: \(String(data: data, encoding: .utf8) ?? "无法解码")")
        
        let charts = try JSONDecoder().decode([CloudChartData].self, from: data)
        print("📊 解析到 \(charts.count) 个星盘")
        return charts.first
    }
    
    // MARK: - 保存星盘到云端
    func saveChartToCloud(userId: String, chartData: ChartData) async throws -> CloudChartData {
        let endpoint = "/rest/v1/star_charts"
        
        // 获取用户token（从UserDefaults中获取）
        let userToken = KeychainManager.shared.getAccessToken()
        
        // 构建云端数据（使用camelCase，让helper自动转换）
        let cloudChart = [
            "userId": userId,
            "chartData": [
                "jsonData": chartData.jsonData,
                "userInfo": [
                    "name": chartData.userInfo.name,
                    "gender": chartData.userInfo.gender,
                    "birthDate": ISO8601DateFormatter().string(from: chartData.userInfo.birthDate),
                    "birthTime": ISO8601DateFormatter().string(from: chartData.userInfo.birthTime),
                    "birthLocation": chartData.userInfo.birthLocation ?? "",
                    "isLunarDate": chartData.userInfo.isLunarDate
                ]
            ],
            "version": "1.0",
            "isPrimary": true,
            "generatedAt": ISO8601DateFormatter().string(from: chartData.generatedDate),
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ] as [String : Any]
        
        guard let data = try await SupabaseAPIHelper.post(
            endpoint: endpoint,
            baseURL: baseURL,
            authType: .authenticated,
            apiKey: apiKey,
            userToken: userToken,
            body: cloudChart,
            useFieldMapping: true
        ) else {
            print("❌ 保存星盘失败：无响应数据")
            throw APIError.invalidResponse
        }
        
        print("✅ 星盘已成功保存到云端")
        let savedChart = try JSONDecoder().decode(CloudChartData.self, from: data)
        return savedChart
    }
    
    // MARK: - 更新星盘
    func updateChartInCloud(chartId: String, chartData: ChartData) async throws {
        let endpoint = "/rest/v1/star_charts?id=eq.\(chartId)"
        
        // 获取用户token（从UserDefaults中获取）
        let userToken = KeychainManager.shared.getAccessToken()
        
        // 使用camelCase，让helper自动转换
        let updateData = [
            "chartData": [
                "jsonData": chartData.jsonData,
                "userInfo": [
                    "name": chartData.userInfo.name,
                    "gender": chartData.userInfo.gender,
                    "birthDate": ISO8601DateFormatter().string(from: chartData.userInfo.birthDate),
                    "birthTime": ISO8601DateFormatter().string(from: chartData.userInfo.birthTime),
                    "birthLocation": chartData.userInfo.birthLocation ?? "",
                    "isLunarDate": chartData.userInfo.isLunarDate
                ]
            ],
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ] as [String : Any]
        
        _ = try await SupabaseAPIHelper.patch(
            endpoint: endpoint,
            baseURL: baseURL,
            authType: .authenticated,
            apiKey: apiKey,
            userToken: userToken,
            body: updateData,
            useFieldMapping: true
        )
        
        print("✅ 星盘已成功更新")
    }
    
    // MARK: - 删除星盘
    func deleteChartFromCloud(chartId: String) async throws {
        let endpoint = "/rest/v1/star_charts?id=eq.\(chartId)"
        
        // 获取用户token（从UserDefaults中获取）
        let userToken = KeychainManager.shared.getAccessToken()
        
        try await SupabaseAPIHelper.delete(
            endpoint: endpoint,
            baseURL: baseURL,
            authType: .authenticated,
            apiKey: apiKey,
            userToken: userToken
        )
        
        print("✅ 星盘已成功删除")
    }
    
    // MARK: - 同步本地星盘到云端
    func syncLocalChartToCloud(userId: String) async throws {
        // 获取本地星盘
        guard let localChart = UserDataManager.shared.currentChart else {
            print("📊 没有本地星盘需要同步")
            return
        }
        
        // 检查云端是否已有星盘
        if let cloudChart = try await getUserChart(userId: userId) {
            // 更新现有星盘
            if let chartId = cloudChart.id {
                try await updateChartInCloud(chartId: chartId, chartData: localChart)
                print("📊 已更新云端星盘")
            }
        } else {
            // 创建新星盘
            _ = try await saveChartToCloud(userId: userId, chartData: localChart)
            print("📊 已创建云端星盘")
        }
    }
    
    // MARK: - 从云端加载星盘到本地
    func loadChartFromCloud(userId: String) async throws {
        guard let cloudChart = try await getUserChart(userId: userId) else {
            print("📊 云端没有星盘数据")
            return
        }
        
        // 转换并保存到本地
        guard let localChart = cloudChart.toLocalChartData() else {
            print("📊 云端星盘数据格式不正确")
            return
        }
        
        await MainActor.run {
            // 使用专门的方法设置云端数据，避免触发循环同步
            UserDataManager.shared.setDataFromCloud(
                user: localChart.userInfo,
                chart: localChart
            )
            print("📊 已从云端加载星盘和用户信息")
        }
    }
}

// MARK: - 自定义错误类型
enum ChartSyncError: LocalizedError {
    case noLocalChart
    case noCloudChart
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noLocalChart:
            return "没有本地星盘数据"
        case .noCloudChart:
            return "云端没有星盘数据"
        case .syncFailed(let message):
            return "同步失败: \(message)"
        }
    }
}