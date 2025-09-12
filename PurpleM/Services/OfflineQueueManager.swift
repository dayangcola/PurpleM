//
//  OfflineQueueManager.swift
//  PurpleM
//
//  离线队列管理器 - 处理网络不稳定时的数据同步
//

import Foundation
import Network
import Combine

// MARK: - 离线操作类型
enum OfflineOperation: Codable {
    case saveMessage(sessionId: String, userId: String, role: String, content: String, metadata: [String: String])
    case syncMemory(userId: String, data: [String: Any])
    case updatePreferences(userId: String, preferences: [String: Any])
    case incrementQuota(userId: String, tokens: Int)
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let data = try container.decode(Data.self, forKey: .data)
        
        switch type {
        case "saveMessage":
            let params = try JSONDecoder().decode(SaveMessageParams.self, from: data)
            self = .saveMessage(
                sessionId: params.sessionId,
                userId: params.userId,
                role: params.role,
                content: params.content,
                metadata: params.metadata
            )
        case "syncMemory":
            let params = try JSONDecoder().decode(SyncMemoryParams.self, from: data)
            self = .syncMemory(userId: params.userId, data: params.data)
        case "updatePreferences":
            let params = try JSONDecoder().decode(UpdatePreferencesParams.self, from: data)
            self = .updatePreferences(userId: params.userId, preferences: params.preferences)
        case "incrementQuota":
            let params = try JSONDecoder().decode(IncrementQuotaParams.self, from: data)
            self = .incrementQuota(userId: params.userId, tokens: params.tokens)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown operation type"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .saveMessage(let sessionId, let userId, let role, let content, let metadata):
            try container.encode("saveMessage", forKey: .type)
            let params = SaveMessageParams(
                sessionId: sessionId,
                userId: userId,
                role: role,
                content: content,
                metadata: metadata
            )
            try container.encode(try JSONEncoder().encode(params), forKey: .data)
            
        case .syncMemory(let userId, let data):
            try container.encode("syncMemory", forKey: .type)
            let params = SyncMemoryParams(userId: userId, data: data)
            try container.encode(try JSONEncoder().encode(params), forKey: .data)
            
        case .updatePreferences(let userId, let preferences):
            try container.encode("updatePreferences", forKey: .type)
            let params = UpdatePreferencesParams(userId: userId, preferences: preferences)
            try container.encode(try JSONEncoder().encode(params), forKey: .data)
            
        case .incrementQuota(let userId, let tokens):
            try container.encode("incrementQuota", forKey: .type)
            let params = IncrementQuotaParams(userId: userId, tokens: tokens)
            try container.encode(try JSONEncoder().encode(params), forKey: .data)
        }
    }
}

// MARK: - 操作参数模型
struct SaveMessageParams: Codable {
    let sessionId: String
    let userId: String
    let role: String
    let content: String
    let metadata: [String: String]
}

struct SyncMemoryParams: Codable {
    let userId: String
    let data: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case userId
        case data
    }
    
    init(userId: String, data: [String: Any]) {
        self.userId = userId
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        
        let dataData = try container.decode(Data.self, forKey: .data)
        data = (try? JSONSerialization.jsonObject(with: dataData) as? [String: Any]) ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        
        let dataData = try JSONSerialization.data(withJSONObject: data)
        try container.encode(dataData, forKey: .data)
    }
}

struct UpdatePreferencesParams: Codable {
    let userId: String
    let preferences: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case userId
        case preferences
    }
    
    init(userId: String, preferences: [String: Any]) {
        self.userId = userId
        self.preferences = preferences
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        
        let prefsData = try container.decode(Data.self, forKey: .preferences)
        preferences = (try? JSONSerialization.jsonObject(with: prefsData) as? [String: Any]) ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        
        let prefsData = try JSONSerialization.data(withJSONObject: preferences)
        try container.encode(prefsData, forKey: .preferences)
    }
}

struct IncrementQuotaParams: Codable {
    let userId: String
    let tokens: Int
}

// MARK: - 队列项
struct QueueItem: Codable {
    let id: UUID
    let operation: OfflineOperation
    let timestamp: Date
    var retryCount: Int
    let maxRetries: Int
    
    init(operation: OfflineOperation, maxRetries: Int = 3) {
        self.id = UUID()
        self.operation = operation
        self.timestamp = Date()
        self.retryCount = 0
        self.maxRetries = maxRetries
    }
    
    var canRetry: Bool {
        return retryCount < maxRetries
    }
}

// MARK: - 网络监控
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                
                if self?.isConnected == true {
                    // 网络恢复，触发队列处理
                    Task {
                        await OfflineQueueManager.shared.processQueue()
                    }
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

// MARK: - 离线队列管理器
@MainActor
class OfflineQueueManager: ObservableObject {
    static let shared = OfflineQueueManager()
    
    @Published var queueSize: Int = 0
    @Published var isProcessing = false
    
    private var queue: [QueueItem] = []
    private let queueKey = "offline_queue"
    private let maxQueueSize = 100
    private var processTimer: Timer?
    
    private init() {
        loadQueue()
        startAutoProcess()
    }
    
    // MARK: - 队列操作
    func enqueue(_ operation: OfflineOperation) {
        if queue.count >= maxQueueSize {
            print("离线队列已满，删除最旧的项")
            queue.removeFirst()
        }
        
        let item = QueueItem(operation: operation)
        queue.append(item)
        queueSize = queue.count
        saveQueue()
        
        print("添加到离线队列: \(operation)")
        
        // 如果网络可用，立即尝试处理
        if NetworkMonitor.shared.isConnected {
            Task {
                await processQueue()
            }
        }
    }
    
    func dequeue() -> QueueItem? {
        guard !queue.isEmpty else { return nil }
        let item = queue.removeFirst()
        queueSize = queue.count
        saveQueue()
        return item
    }
    
    func peek() -> QueueItem? {
        return queue.first
    }
    
    func clear() {
        queue.removeAll()
        queueSize = 0
        saveQueue()
    }
    
    // MARK: - 处理队列
    func processQueue() async {
        guard !isProcessing else { return }
        guard NetworkMonitor.shared.isConnected else {
            print("网络不可用，跳过队列处理")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        print("开始处理离线队列，共 \(queue.count) 项")
        
        var failedItems: [QueueItem] = []
        
        while let item = peek() {
            do {
                try await processOperation(item.operation)
                _ = dequeue() // 成功，移除项
                print("处理成功: \(item.id)")
            } catch {
                print("处理失败: \(error)")
                
                // 增加重试计数
                var updatedItem = dequeue()!
                updatedItem.retryCount += 1
                
                // 使用智能重试策略
                let shouldRetry = SafeDataManager.shared.shouldRetryOperation(
                    error: error,
                    retryCount: updatedItem.retryCount
                )
                
                if shouldRetry && updatedItem.canRetry {
                    failedItems.append(updatedItem)
                    print("📝 操作将重试: \(updatedItem.id)")
                } else {
                    print("🗑 永久性错误或超过重试，丢弃: \(updatedItem.id)")
                }
            }
            
            // 避免过快请求
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        // 将失败的项重新加入队列
        for item in failedItems {
            queue.append(item)
        }
        queueSize = queue.count
        saveQueue()
        
        print("队列处理完成，剩余 \(queue.count) 项")
    }
    
    // MARK: - 处理单个操作
    private func processOperation(_ operation: OfflineOperation) async throws {
        switch operation {
        case .saveMessage(let sessionId, let userId, let role, let content, let metadata):
            try await SupabaseManager.shared.saveMessage(
                sessionId: sessionId,
                userId: userId,
                role: role,
                content: content,
                metadata: metadata
            )
            
        case .syncMemory(let userId, let data):
            // 使用DataSyncManager处理记忆同步
            try await DataSyncManager.shared.syncMemoryData(
                userId: userId,
                memoryData: data
            )
            
        case .updatePreferences(let userId, let preferences):
            // 使用DataSyncManager处理偏好更新
            try await DataSyncManager.shared.syncUserPreferences(
                userId: userId,
                preferences: preferences
            )
            
        case .incrementQuota(let userId, let tokens):
            _ = try await SupabaseManager.shared.incrementQuotaUsage(
                userId: userId,
                tokens: tokens
            )
        }
    }
    
    // MARK: - 持久化
    private func saveQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }
    
    private func loadQueue() {
        if let data = UserDefaults.standard.data(forKey: queueKey),
           let items = try? JSONDecoder().decode([QueueItem].self, from: data) {
            queue = items
            queueSize = queue.count
            print("加载离线队列: \(queue.count) 项")
        }
    }
    
    // MARK: - 自动处理
    private func startAutoProcess() {
        // 每30秒尝试处理一次队列
        processTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await self.processQueue()
            }
        }
    }
    
    deinit {
        processTimer?.invalidate()
    }
}