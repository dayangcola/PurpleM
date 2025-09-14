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
    
    // 自定义解码器来处理不同格式的日期
    enum CodingKeys: String, CodingKey {
        case name, gender
        case birthDate = "birth_date"
        case birthTime = "birth_time"
        case birthLocation = "birth_location"
        case isLunarDate = "is_lunar_date"
    }
    
    init(name: String, gender: String, birthDate: Date, birthTime: Date, birthLocation: String? = nil, isLunarDate: Bool = false) {
        self.name = name
        self.gender = gender
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.birthLocation = birthLocation
        self.isLunarDate = isLunarDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        gender = try container.decode(String.self, forKey: .gender)
        birthLocation = try container.decodeIfPresent(String.self, forKey: .birthLocation)
        isLunarDate = try container.decodeIfPresent(Bool.self, forKey: .isLunarDate) ?? false
        
        // 尝试解码日期 - 支持ISO8601字符串格式
        if let birthDateString = try? container.decode(String.self, forKey: .birthDate) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: birthDateString) {
                birthDate = date
            } else {
                // 尝试不带小数秒的格式
                formatter.formatOptions = [.withInternetDateTime]
                birthDate = formatter.date(from: birthDateString) ?? Date()
            }
        } else if let birthDateDouble = try? container.decode(Double.self, forKey: .birthDate) {
            // 支持时间戳格式
            birthDate = Date(timeIntervalSince1970: birthDateDouble)
        } else {
            birthDate = try container.decode(Date.self, forKey: .birthDate)
        }
        
        // 尝试解码时间 - 支持ISO8601字符串格式
        if let birthTimeString = try? container.decode(String.self, forKey: .birthTime) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: birthTimeString) {
                birthTime = date
            } else {
                // 尝试不带小数秒的格式
                formatter.formatOptions = [.withInternetDateTime]
                birthTime = formatter.date(from: birthTimeString) ?? Date()
            }
        } else if let birthTimeDouble = try? container.decode(Double.self, forKey: .birthTime) {
            // 支持时间戳格式
            birthTime = Date(timeIntervalSince1970: birthTimeDouble)
        } else {
            birthTime = try container.decode(Date.self, forKey: .birthTime)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(gender, forKey: .gender)
        try container.encodeIfPresent(birthLocation, forKey: .birthLocation)
        try container.encode(isLunarDate, forKey: .isLunarDate)
        
        // 编码为ISO8601字符串
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        try container.encode(formatter.string(from: birthDate), forKey: .birthDate)
        try container.encode(formatter.string(from: birthTime), forKey: .birthTime)
    }
    
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
            // 如果正在从云端加载，不触发保存和同步
            guard !isLoadingFromCloud else { return }
            
            // 确保在主线程更新
            DispatchQueue.main.async { [weak self] in
                self?.saveUserInfo()
                // 自动同步到云端
                if let _ = self?.currentUser {
                    self?.syncToCloudIfNeeded()
                }
            }
        }
    }
    
    @Published var currentChart: ChartData? {
        didSet {
            // 如果正在从云端加载，不触发保存和同步
            guard !isLoadingFromCloud else { return }
            
            // 确保在主线程更新
            DispatchQueue.main.async { [weak self] in
                self?.saveChartData()
                // 自动同步到云端
                if let _ = self?.currentChart {
                    self?.syncToCloudIfNeeded()
                }
            }
        }
    }
    
    @Published var hasUserInfo: Bool = false
    @Published var hasGeneratedChart: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var isInitializing: Bool = true  // 新增：表示是否正在初始加载
    
    private let userInfoKey = "PurpleM_UserInfo"
    private let chartDataKey = "PurpleM_ChartData"
    var currentUserId: String?
    private var isLoadingFromCloud: Bool = false  // 防止循环同步的标志
    
    private init() {
        // 初始化时不自动加载本地数据
        // 等待用户登录后再加载对应的数据
        setupAuthListener()
        
        // 立即检查当前用户状态并加载数据（在主线程中）
        Task { @MainActor in
            defer {
                // 无论是否有用户登录，都要标记初始化完成
                isInitializing = false
            }
            
            // 首先检查并刷新过期的Token
            if TokenRefreshManager.shared.shouldRefreshToken() {
                print("🔄 检测到Token即将过期，尝试刷新...")
                let refreshSuccess = await TokenRefreshManager.shared.refreshTokenIfNeeded()
                if !refreshSuccess {
                    print("⚠️ Token刷新失败，可能需要重新登录")
                }
            }
            
            if let user = AuthManager.shared.currentUser {
                currentUserId = user.id
                print("📝 UserDataManager初始化，当前用户ID: \(user.id)")
                
                // 如果用户已登录，立即从云端加载数据
                print("🔄 用户已登录，开始加载云端数据...")
                await loadFromCloud()
            } else {
                print("📝 UserDataManager初始化，用户未登录")
            }
        }
    }
    
    // MARK: - 用户信息管理
    
    @MainActor
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
    
    @MainActor
    func loadUserInfo() {
        guard let data = UserDefaults.standard.data(forKey: userInfoKey),
              let decoded = try? JSONDecoder().decode(UserInfo.self, from: data) else {
            hasUserInfo = false
            return
        }
        
        currentUser = decoded
        hasUserInfo = true
    }
    
    @MainActor
    func updateUserInfo(_ info: UserInfo) {
        currentUser = info
        // 用户信息改变后，需要重新生成星盘
        currentChart = nil
        hasGeneratedChart = false
    }
    
    @MainActor
    func clearUserInfo() {
        currentUser = nil
        currentChart = nil
        hasUserInfo = false
        hasGeneratedChart = false
    }
    
    // MARK: - 星盘数据管理
    
    @MainActor
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
    
    @MainActor
    func loadChartData() {
        guard let data = UserDefaults.standard.data(forKey: chartDataKey),
              let decoded = try? JSONDecoder().decode(ChartData.self, from: data) else {
            hasGeneratedChart = false
            return
        }
        
        currentChart = decoded
        hasGeneratedChart = true
    }
    
    @MainActor
    func saveGeneratedChart(jsonData: String, userInfo: UserInfo) {
        let chartData = ChartData(
            jsonData: jsonData,
            generatedDate: Date(),
            userInfo: userInfo
        )
        currentChart = chartData
    }
    
    // 专门用于从云端设置数据，避免触发同步
    @MainActor
    func setDataFromCloud(user: UserInfo? = nil, chart: ChartData? = nil) {
        isLoadingFromCloud = true
        defer { isLoadingFromCloud = false }
        
        if let user = user {
            currentUser = user
            hasUserInfo = true
        }
        if let chart = chart {
            currentChart = chart
            hasGeneratedChart = true
        }
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
    
    @MainActor
    @objc private func handleAuthStateChange() {
        Task { @MainActor in
            if let user = AuthManager.shared.currentUser {
                // 用户登录，加载云端数据
                let previousUserId = currentUserId
                currentUserId = user.id
                
                // 检查是否需要加载数据
                // 1. 用户ID变化
                // 2. 当前没有星盘数据
                // 3. 强制刷新标志
                let needsLoad = previousUserId != user.id || 
                               !hasGeneratedChart || 
                               currentChart == nil
                
                if needsLoad {
                    print("🔄 用户状态变化，加载用户 \(user.id) 的数据")
                    print("📊 加载原因: ID变化=\(previousUserId != user.id), 无星盘=\(!hasGeneratedChart), 数据为空=\(currentChart == nil)")
                    await loadFromCloud()
                } else {
                    print("ℹ️ 数据已存在，跳过加载")
                }
            } else {
                // 用户登出，清空本地数据
                currentUserId = nil
                clearAllData()
            }
        }
    }
    
    // 从云端加载数据（支持离线缓存）
    @MainActor
    func loadFromCloud() async {
        guard let userId = currentUserId else { return }
        
        isSyncing = true
        isLoadingFromCloud = true  // 设置加载标志
        defer { 
            isSyncing = false
            isLoadingFromCloud = false  // 清除加载标志
        }
        
        // 使用智能加载策略：先从缓存加载，然后异步更新
        let cacheKey = OfflineCacheManager.CacheKey.starChart(userId: userId)
        
        // 尝试从缓存加载
        if let cachedChart = await OfflineCacheManager.shared.load(ChartData.self, forKey: cacheKey) {
            print("💾 从缓存加载星盘数据")
            setDataFromCloud(user: cachedChart.userInfo, chart: cachedChart)
            
            // 如果在线，异步更新缓存
            if NetworkMonitor.shared.isConnected {
                Task {
                    do {
                        try await SupabaseManager.shared.loadChartFromCloud(userId: userId)
                        lastSyncTime = Date()
                        print("✅ 云端数据已更新缓存")
                    } catch {
                        print("⚠️ 云端更新失败，继续使用缓存: \(error)")
                    }
                }
            }
        } else {
            // 缓存没有数据，必须从云端加载
            do {
                // 从云端加载星盘（内部会调用setDataFromCloud）
                try await SupabaseManager.shared.loadChartFromCloud(userId: userId)
                
                // 加载成功后缓存数据
                if let chart = currentChart {
                    try? await OfflineCacheManager.shared.save(
                        chart,
                        forKey: cacheKey,
                        policy: .cacheWithExpiry(86400) // 缓存24小时
                    )
                }
                
                // 加载完成后，记录时间
                lastSyncTime = Date()
                
                print("✅ 成功从云端加载星盘数据并缓存")
                print("📊 当前星盘状态: hasGeneratedChart=\(hasGeneratedChart), hasUserInfo=\(hasUserInfo)")
                print("📊 数据状态: currentChart=\(currentChart != nil), currentUser=\(currentUser != nil)")
            } catch {
                print("❌ 从云端加载失败: \(error)")
                // 如果云端没有数据，尝试上传本地数据
                if hasGeneratedChart {
                    Task {
                        try? await SupabaseManager.shared.syncLocalChartToCloud(userId: userId)
                    }
                }
            }
        }
    }
    
    // 同步到云端（同时更新缓存）
    private func syncToCloudIfNeeded() {
        // 使用已保存的currentUserId
        let userId = currentUserId
        
        guard let validUserId = userId else {
            print("⚠️ 无法同步星盘：用户未登录或ID未设置")
            return
        }
        
        guard let chart = currentChart else {
            print("⚠️ 无法同步星盘：没有星盘数据")
            return
        }
        
        // 更新currentUserId以备后用
        if currentUserId == nil {
            currentUserId = validUserId
            print("📝 设置currentUserId: \(validUserId)")
        }
        
        print("🔄 开始同步星盘到云端，用户ID: \(validUserId)")
        
        Task {
            // 先保存到本地缓存
            let cacheKey = OfflineCacheManager.CacheKey.starChart(userId: validUserId)
            try? await OfflineCacheManager.shared.save(
                chart,
                forKey: cacheKey,
                policy: .cacheWithExpiry(86400) // 缓存24小时
            )
            
            do {
                // 使用重试机制同步星盘
                try await RetryManager.shared.retrySupabaseOperation(
                    operation: {
                        try await SupabaseManager.shared.syncLocalChartToCloud(userId: validUserId)
                    },
                    operationName: "同步星盘到云端"
                )
                
                await MainActor.run {
                    lastSyncTime = Date()
                    print("✅ 星盘已同步到云端和缓存，用户ID: \(validUserId)")
                }
            } catch {
                print("❌ 同步到云端失败（已重试）: \(error)")
                print("❌ 用户ID: \(validUserId)")
                print("❌ 星盘数据存在: \(chart.jsonData.prefix(100))...")
                
                // 如果是网络问题，数据已在缓存中
                if !NetworkMonitor.shared.isConnected {
                    print("📥 网络不可用，数据已缓存，将在网络恢复后自动同步")
                }
            }
        }
    }
    
    // 清空所有数据（登出时调用）
    @MainActor
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
    
    // 强制刷新星盘数据（公开方法）
    @MainActor
    func forceReloadChartData() async {
        guard let userId = currentUserId ?? AuthManager.shared.currentUser?.id else {
            print("⚠️ 无法刷新：用户未登录")
            return
        }
        
        print("🔄 强制刷新星盘数据，用户ID: \(userId)")
        currentUserId = userId
        await loadFromCloud()
    }
}