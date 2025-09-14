//
//  DataPreloader.swift
//  PurpleM
//
//  智能数据预加载服务
//

import Foundation
import SwiftUI

// MARK: - 预加载优先级
enum PreloadPriority: Int, Comparable {
    case critical = 4   // 关键数据，立即加载
    case high = 3      // 高优先级，尽快加载
    case normal = 2    // 普通优先级
    case low = 1       // 低优先级，空闲时加载
    
    static func < (lhs: PreloadPriority, rhs: PreloadPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 预加载任务
struct PreloadTask {
    let id: String
    let priority: PreloadPriority
    let loader: () async throws -> Void
    let estimatedSize: Int // 预估数据大小（字节）
    let expiryTime: TimeInterval // 缓存过期时间
    
    init(
        id: String,
        priority: PreloadPriority = .normal,
        estimatedSize: Int = 0,
        expiryTime: TimeInterval = 3600,
        loader: @escaping () async throws -> Void
    ) {
        self.id = id
        self.priority = priority
        self.estimatedSize = estimatedSize
        self.expiryTime = expiryTime
        self.loader = loader
    }
}

// MARK: - 预加载状态
enum PreloadStatus {
    case pending
    case loading
    case completed
    case failed(Error)
}

// MARK: - 数据预加载管理器
@MainActor
class DataPreloader: ObservableObject {
    static let shared = DataPreloader()
    
    // 任务队列
    private var taskQueue: [PreloadTask] = []
    private var taskStatus: [String: PreloadStatus] = [:]
    private var loadedData: [String: Date] = [:] // 记录加载时间
    
    // 并发控制
    private let maxConcurrentLoads = 3
    private var activeLoads = 0
    
    // 网络状态监听
    @Published var isPreloading = false
    @Published var preloadProgress: Double = 0
    
    // 统计信息
    private(set) var totalPreloaded = 0
    private(set) var totalPreloadSize = 0
    
    private init() {
        setupNetworkObserver()
        setupAppLifecycleObserver()
    }
    
    // MARK: - 公共接口
    
    /// 注册预加载任务
    func register(_ task: PreloadTask) {
        // 检查是否已存在
        if taskStatus[task.id] == nil {
            taskQueue.append(task)
            taskStatus[task.id] = .pending
            
            // 根据优先级排序
            taskQueue.sort { $0.priority > $1.priority }
        }
    }
    
    /// 批量注册任务
    func registerBatch(_ tasks: [PreloadTask]) {
        for task in tasks {
            register(task)
        }
    }
    
    /// 开始预加载
    func startPreloading() {
        guard !isPreloading else { return }
        
        isPreloading = true
        Task {
            await processQueue()
        }
    }
    
    /// 停止预加载
    func stopPreloading() {
        isPreloading = false
    }
    
    /// 检查数据是否已预加载
    func isPreloaded(_ taskId: String) -> Bool {
        if let status = taskStatus[taskId] {
            if case .completed = status {
                // 检查是否过期
                if let loadTime = loadedData[taskId] {
                    if let task = taskQueue.first(where: { $0.id == taskId }) {
                        return Date().timeIntervalSince(loadTime) < task.expiryTime
                    }
                }
            }
        }
        return false
    }
    
    /// 强制预加载特定任务
    func forcePreload(_ taskId: String) async {
        guard let task = taskQueue.first(where: { $0.id == taskId }) else { return }
        
        taskStatus[task.id] = .loading
        do {
            try await task.loader()
            taskStatus[task.id] = .completed
            loadedData[task.id] = Date()
            totalPreloaded += 1
            totalPreloadSize += task.estimatedSize
            print("✅ 预加载完成: \(task.id)")
        } catch {
            taskStatus[task.id] = .failed(error)
            print("❌ 预加载失败: \(task.id) - \(error)")
        }
    }
    
    // MARK: - 私有方法
    
    private func processQueue() async {
        while isPreloading && !taskQueue.isEmpty {
            // 获取下一个待处理任务
            guard let nextTask = getNextPendingTask() else {
                break
            }
            
            // 等待可用槽位
            while activeLoads >= maxConcurrentLoads && isPreloading {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            
            if !isPreloading { break }
            
            // 异步执行预加载
            Task {
                await executePreload(nextTask)
            }
        }
        
        isPreloading = false
    }
    
    private func getNextPendingTask() -> PreloadTask? {
        return taskQueue.first { task in
            if let status = taskStatus[task.id] {
                if case .pending = status {
                    return true
                }
            }
            return false
        }
    }
    
    private func executePreload(_ task: PreloadTask) async {
        activeLoads += 1
        defer { activeLoads -= 1 }
        
        // 检查网络状态
        guard shouldPreload(task) else { return }
        
        taskStatus[task.id] = .loading
        updateProgress()
        
        do {
            try await task.loader()
            taskStatus[task.id] = .completed
            loadedData[task.id] = Date()
            totalPreloaded += 1
            totalPreloadSize += task.estimatedSize
            
            print("✅ 预加载完成: \(task.id) [\(formatBytes(task.estimatedSize))]")
        } catch {
            taskStatus[task.id] = .failed(error)
            print("❌ 预加载失败: \(task.id) - \(error)")
        }
        
        updateProgress()
    }
    
    private func shouldPreload(_ task: PreloadTask) -> Bool {
        // WiFi环境下加载所有
        if NetworkMonitor.shared.connectionType == .wifi {
            return true
        }
        
        // 蜂窝网络只加载高优先级
        if NetworkMonitor.shared.connectionType == .cellular {
            return task.priority >= .high
        }
        
        // 无网络不预加载
        return false
    }
    
    private func updateProgress() {
        let total = taskQueue.count
        let completed = taskStatus.values.filter { status in
            if case .completed = status { return true }
            return false
        }.count
        
        preloadProgress = total > 0 ? Double(completed) / Double(total) : 0
    }
    
    // MARK: - 网络监听
    
    private func setupNetworkObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: NSNotification.Name("NetworkStatusChanged"),
            object: nil
        )
    }
    
    @objc private func networkStatusChanged() {
        if NetworkMonitor.shared.connectionType == .wifi {
            // WiFi连接，自动开始预加载
            if !isPreloading {
                print("📶 检测到WiFi，开始预加载")
                startPreloading()
            }
        } else if NetworkMonitor.shared.connectionType == .none {
            // 无网络，停止预加载
            if isPreloading {
                print("📵 网络断开，停止预加载")
                stopPreloading()
            }
        }
    }
    
    // MARK: - 应用生命周期
    
    private func setupAppLifecycleObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        // 应用激活，检查是否需要预加载
        if NetworkMonitor.shared.connectionType == .wifi && !isPreloading {
            startPreloading()
        }
    }
    
    @objc private func appWillResignActive() {
        // 应用进入后台，暂停预加载
        if isPreloading {
            stopPreloading()
        }
    }
    
    // MARK: - 工具方法
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// 清理过期数据
    func cleanExpiredData() {
        let now = Date()
        var expiredTasks: [String] = []
        
        for (taskId, loadTime) in loadedData {
            if let task = taskQueue.first(where: { $0.id == taskId }) {
                if now.timeIntervalSince(loadTime) > task.expiryTime {
                    expiredTasks.append(taskId)
                }
            }
        }
        
        for taskId in expiredTasks {
            loadedData.removeValue(forKey: taskId)
            taskStatus[taskId] = .pending
        }
        
        if !expiredTasks.isEmpty {
            print("🧹 清理了 \(expiredTasks.count) 个过期预加载数据")
        }
    }
    
    /// 获取预加载统计
    func getStatistics() -> (loaded: Int, size: String, progress: Double) {
        return (totalPreloaded, formatBytes(totalPreloadSize), preloadProgress)
    }
}

// MARK: - 默认预加载任务
extension DataPreloader {
    
    /// 设置默认预加载任务
    func setupDefaultTasks() {
        // 用户资料
        register(PreloadTask(
            id: "user_profile",
            priority: .critical,
            estimatedSize: 5 * 1024, // 5KB
            expiryTime: 300 // 5分钟
        ) {
            guard let userId = AuthManager.shared.currentUser?.id else { return }
            // 预加载用户资料到缓存
            let cacheKey = "user_profile_\(userId)"
            if await OfflineCacheManager.shared.load(UserInfo.self, forKey: cacheKey) == nil {
                print("预加载用户资料")
                // 实际加载逻辑会在UserDataManager中处理
            }
        })
        
        // 星盘数据
        register(PreloadTask(
            id: "star_chart",
            priority: .high,
            estimatedSize: 50 * 1024, // 50KB
            expiryTime: 3600 // 1小时
        ) {
            guard let userId = AuthManager.shared.currentUser?.id else { return }
            await UserDataManager.shared.loadFromCloud()
        })
        
        // 每日运势
        register(PreloadTask(
            id: "daily_fortune",
            priority: .normal,
            estimatedSize: 10 * 1024, // 10KB
            expiryTime: 3600 * 6 // 6小时
        ) {
            // 预加载今日运势
            let today = Date()
            let cacheKey = "daily_fortune_\(today.formatted(.dateTime.year().month().day()))"
            
            if await OfflineCacheManager.shared.load(String.self, forKey: cacheKey) == nil {
                // 这里调用实际的运势API
                print("预加载今日运势")
            }
        })
        
        // 知识库索引
        register(PreloadTask(
            id: "knowledge_index",
            priority: .low,
            estimatedSize: 100 * 1024, // 100KB
            expiryTime: 3600 * 24 // 24小时
        ) {
            // 预加载知识库索引
            print("预加载知识库索引")
        })
    }
}