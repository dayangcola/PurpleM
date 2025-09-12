//
//  UserDataManager.swift
//  PurpleM
//
//  用户数据管理器 - 使用UserDefaults持久化存储
//

import SwiftUI
import Combine

// MARK: - 用户信息模型
struct UserInfo: Codable {
    var name: String
    var gender: String
    var birthDate: Date
    var birthTime: Date
    var birthLocation: String?
    var isLunarDate: Bool
    
    // 计算属性：获取生辰信息
    var birthYear: Int {
        Calendar.current.component(.year, from: birthDate)
    }
    
    var birthMonth: Int {
        Calendar.current.component(.month, from: birthDate)
    }
    
    var birthDay: Int {
        Calendar.current.component(.day, from: birthDate)
    }
    
    var birthHour: Int {
        Calendar.current.component(.hour, from: birthTime)
    }
    
    var birthMinute: Int {
        Calendar.current.component(.minute, from: birthTime)
    }
}

// MARK: - 星盘数据模型
struct ChartData: Codable {
    let jsonData: String
    let generatedDate: Date
    let userInfo: UserInfo
}

// MARK: - 用户数据管理器
class UserDataManager: ObservableObject {
    static let shared = UserDataManager()
    
    @Published var currentUser: UserInfo? {
        didSet {
            saveUserInfo()
            // 自动同步到云端
            if let _ = currentUser {
                syncToCloudIfNeeded()
            }
        }
    }
    
    @Published var currentChart: ChartData? {
        didSet {
            saveChartData()
            // 自动同步到云端
            if let _ = currentChart {
                syncToCloudIfNeeded()
            }
        }
    }
    
    @Published var hasUserInfo: Bool = false
    @Published var hasGeneratedChart: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    
    private let userInfoKey = "PurpleM_UserInfo"
    private let chartDataKey = "PurpleM_ChartData"
    private var currentUserId: String?
    
    private init() {
        // 初始化时不自动加载本地数据
        // 等待用户登录后再加载对应的数据
        setupAuthListener()
    }
    
    // MARK: - 用户信息管理
    
    func saveUserInfo() {
        guard let user = currentUser else {
            UserDefaults.standard.removeObject(forKey: userInfoKey)
            hasUserInfo = false
            return
        }
        
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userInfoKey)
            hasUserInfo = true
        }
    }
    
    func loadUserInfo() {
        guard let data = UserDefaults.standard.data(forKey: userInfoKey),
              let decoded = try? JSONDecoder().decode(UserInfo.self, from: data) else {
            hasUserInfo = false
            return
        }
        
        currentUser = decoded
        hasUserInfo = true
    }
    
    func updateUserInfo(_ info: UserInfo) {
        currentUser = info
        // 用户信息改变后，需要重新生成星盘
        currentChart = nil
        hasGeneratedChart = false
    }
    
    func clearUserInfo() {
        currentUser = nil
        currentChart = nil
        hasUserInfo = false
        hasGeneratedChart = false
    }
    
    // MARK: - 星盘数据管理
    
    func saveChartData() {
        guard let chart = currentChart else {
            UserDefaults.standard.removeObject(forKey: chartDataKey)
            hasGeneratedChart = false
            return
        }
        
        if let encoded = try? JSONEncoder().encode(chart) {
            UserDefaults.standard.set(encoded, forKey: chartDataKey)
            hasGeneratedChart = true
        }
    }
    
    func loadChartData() {
        guard let data = UserDefaults.standard.data(forKey: chartDataKey),
              let decoded = try? JSONDecoder().decode(ChartData.self, from: data) else {
            hasGeneratedChart = false
            return
        }
        
        currentChart = decoded
        hasGeneratedChart = true
    }
    
    func saveGeneratedChart(jsonData: String, userInfo: UserInfo) {
        let chartData = ChartData(
            jsonData: jsonData,
            generatedDate: Date(),
            userInfo: userInfo
        )
        currentChart = chartData
    }
    
    // MARK: - 便捷方法
    
    func needsInitialSetup() -> Bool {
        return !hasUserInfo || currentUser == nil
    }
    
    func needsChartGeneration() -> Bool {
        return hasUserInfo && !hasGeneratedChart
    }
    
    func canShowChart() -> Bool {
        return hasUserInfo && hasGeneratedChart && currentChart != nil
    }
    
    // MARK: - 云端同步功能
    
    private func setupAuthListener() {
        // 监听认证状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthStateChange),
            name: NSNotification.Name("AuthStateChanged"),
            object: nil
        )
    }
    
    @objc private func handleAuthStateChange() {
        Task { @MainActor in
            if let user = AuthManager.shared.currentUser {
                // 用户登录，加载云端数据
                currentUserId = user.id
                loadFromCloud()
            } else {
                // 用户登出，清空本地数据
                currentUserId = nil
                clearAllData()
            }
        }
    }
    
    // 从云端加载数据
    func loadFromCloud() {
        guard let userId = currentUserId else { return }
        
        Task {
            isSyncing = true
            defer { 
                Task { @MainActor in
                    isSyncing = false
                }
            }
            
            do {
                // 从云端加载星盘
                try await SupabaseManager.shared.loadChartFromCloud(userId: userId)
                
                await MainActor.run {
                    lastSyncTime = Date()
                    print("✅ 成功从云端加载星盘数据")
                }
            } catch {
                print("❌ 从云端加载失败: \(error)")
                // 如果云端没有数据，尝试上传本地数据
                if hasGeneratedChart {
                    try? await SupabaseManager.shared.syncLocalChartToCloud(userId: userId)
                }
            }
        }
    }
    
    // 同步到云端
    private func syncToCloudIfNeeded() {
        guard let userId = currentUserId,
              let _ = currentChart else { return }
        
        Task {
            do {
                try await SupabaseManager.shared.syncLocalChartToCloud(userId: userId)
                await MainActor.run {
                    lastSyncTime = Date()
                    print("✅ 星盘已同步到云端")
                }
            } catch {
                print("❌ 同步到云端失败: \(error)")
            }
        }
    }
    
    // 清空所有数据（登出时调用）
    func clearAllData() {
        currentUser = nil
        currentChart = nil
        hasUserInfo = false
        hasGeneratedChart = false
        UserDefaults.standard.removeObject(forKey: userInfoKey)
        UserDefaults.standard.removeObject(forKey: chartDataKey)
        print("🗑️ 已清空本地星盘数据")
    }
    
    // 手动触发同步
    func manualSync() {
        guard let userId = currentUserId else {
            print("⚠️ 未登录，无法同步")
            return
        }
        
        Task {
            isSyncing = true
            defer {
                Task { @MainActor in
                    isSyncing = false
                }
            }
            
            do {
                if hasGeneratedChart {
                    // 上传本地数据到云端
                    try await SupabaseManager.shared.syncLocalChartToCloud(userId: userId)
                } else {
                    // 从云端下载数据
                    try await SupabaseManager.shared.loadChartFromCloud(userId: userId)
                }
                
                await MainActor.run {
                    lastSyncTime = Date()
                    print("✅ 手动同步完成")
                }
            } catch {
                print("❌ 手动同步失败: \(error)")
            }
        }
    }
}