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
    
    // 转换为本地ChartData
    func toLocalChartData() -> ChartData {
        return ChartData(
            jsonData: chartData.jsonData,
            generatedDate: generatedAt,
            userInfo: chartData.userInfo
        )
    }
}

struct ChartDataPayload: Codable {
    let jsonData: String
    let userInfo: UserInfo
}

// MARK: - SupabaseManager 星盘扩展
extension SupabaseManager {
    
    // MARK: - 获取用户星盘
    func getUserChart(userId: String) async throws -> CloudChartData? {
        let endpoint = "\(baseURL)/rest/v1/star_charts"
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("eq.\(userId)", forHTTPHeaderField: "user_id")
        request.setValue("eq.true", forHTTPHeaderField: "is_primary")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let charts = try JSONDecoder().decode([CloudChartData].self, from: data)
        return charts.first
    }
    
    // MARK: - 保存星盘到云端
    func saveChartToCloud(userId: String, chartData: ChartData) async throws -> CloudChartData {
        let endpoint = "\(baseURL)/rest/v1/star_charts"
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidResponse
        }
        
        // 构建云端数据
        let cloudChart = [
            "user_id": userId,
            "chart_data": [
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
            "is_primary": true
        ] as [String : Any]
        
        let jsonData = try JSONSerialization.data(withJSONObject: cloudChart)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw APIError.invalidResponse
        }
        
        let savedChart = try JSONDecoder().decode(CloudChartData.self, from: data)
        return savedChart
    }
    
    // MARK: - 更新星盘
    func updateChartInCloud(chartId: String, chartData: ChartData) async throws {
        let endpoint = "\(baseURL)/rest/v1/star_charts?id=eq.\(chartId)"
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidResponse
        }
        
        let updateData = [
            "chart_data": [
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
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ] as [String : Any]
        
        let jsonData = try JSONSerialization.data(withJSONObject: updateData)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - 删除星盘
    func deleteChartFromCloud(chartId: String) async throws {
        let endpoint = "\(baseURL)/rest/v1/star_charts?id=eq.\(chartId)"
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw APIError.invalidResponse
        }
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
        let localChart = cloudChart.toLocalChartData()
        await MainActor.run {
            UserDataManager.shared.currentChart = localChart
            print("📊 已从云端加载星盘")
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