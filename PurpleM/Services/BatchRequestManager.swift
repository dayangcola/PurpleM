//
//  BatchRequestManager.swift
//  PurpleM
//
//  API请求批处理管理器 - 优化网络请求性能
//

import Foundation

// MARK: - 批处理请求项
struct BatchRequestItem {
    let id: String
    let endpoint: String
    let method: String
    let body: Data?
    let headers: [String: String]
    let completion: (Result<Data, Error>) -> Void
    
    init(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:],
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        self.id = UUID().uuidString
        self.endpoint = endpoint
        self.method = method
        self.body = body
        self.headers = headers
        self.completion = completion
    }
}

// MARK: - 批处理响应
struct BatchResponse: Codable {
    let id: String
    let status: Int
    let data: Data?
    let error: String?
}

// MARK: - 批处理配置
struct BatchConfig {
    let maxBatchSize: Int
    let maxWaitTime: TimeInterval
    let maxRetries: Int
    
    static let `default` = BatchConfig(
        maxBatchSize: 10,
        maxWaitTime: 0.1, // 100ms
        maxRetries: 3
    )
}

// MARK: - 批处理管理器
@MainActor
class BatchRequestManager {
    static let shared = BatchRequestManager()
    
    // 配置
    private let config: BatchConfig
    
    // 请求队列
    private var pendingRequests: [BatchRequestItem] = []
    private var batchTimer: Timer?
    
    // 统计信息
    private(set) var totalBatchedRequests: Int = 0
    private(set) var totalSavedRequests: Int = 0
    
    // 并发控制
    private let requestQueue = DispatchQueue(label: "com.purplem.batch", attributes: .concurrent)
    private let requestSemaphore = DispatchSemaphore(value: 5) // 最多5个并发批次
    
    private init(config: BatchConfig = .default) {
        self.config = config
    }
    
    // MARK: - 公共接口
    
    /// 添加请求到批处理队列
    func enqueue(_ request: BatchRequestItem) {
        pendingRequests.append(request)
        
        // 如果达到批次大小，立即执行
        if pendingRequests.count >= config.maxBatchSize {
            executeBatch()
        } else {
            // 否则启动定时器等待更多请求
            startBatchTimer()
        }
    }
    
    /// 创建批处理请求
    func batchRequest(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let request = BatchRequestItem(
                endpoint: endpoint,
                method: method,
                body: body,
                headers: headers
            ) { result in
                continuation.resume(with: result)
            }
            
            enqueue(request)
        }
    }
    
    /// 立即执行所有待处理请求
    func flush() {
        guard !pendingRequests.isEmpty else { return }
        executeBatch()
    }
    
    // MARK: - 私有方法
    
    private func startBatchTimer() {
        // 如果已有定时器，不重复创建
        guard batchTimer == nil else { return }
        
        batchTimer = Timer.scheduledTimer(
            withTimeInterval: config.maxWaitTime,
            repeats: false
        ) { _ in
            Task { @MainActor in
                self.executeBatch()
            }
        }
    }
    
    private func executeBatch() {
        // 取消定时器
        batchTimer?.invalidate()
        batchTimer = nil
        
        // 获取当前批次
        guard !pendingRequests.isEmpty else { return }
        
        let batch = Array(pendingRequests.prefix(config.maxBatchSize))
        pendingRequests.removeFirst(min(config.maxBatchSize, pendingRequests.count))
        
        // 异步执行批处理
        Task {
            await performBatchRequest(batch)
        }
        
        // 如果还有待处理请求，继续处理
        if !pendingRequests.isEmpty {
            startBatchTimer()
        }
    }
    
    private func performBatchRequest(_ batch: [BatchRequestItem]) async {
        // 更新统计
        totalBatchedRequests += batch.count
        
        // 根据请求类型分组
        let groupedRequests = Dictionary(grouping: batch) { $0.method }
        
        // 并行执行不同类型的请求
        await withTaskGroup(of: Void.self) { group in
            for (method, requests) in groupedRequests {
                group.addTask {
                    await self.executeGroupedRequests(method: method, requests: requests)
                }
            }
        }
        
        // 计算节省的请求数
        totalSavedRequests += batch.count - groupedRequests.count
        
        print("📦 批处理完成: \(batch.count) 个请求合并为 \(groupedRequests.count) 个")
        print("💰 累计节省请求: \(totalSavedRequests)")
    }
    
    private func executeGroupedRequests(method: String, requests: [BatchRequestItem]) async {
        // 构建批量请求
        let batchEndpoint = "/batch"
        let batchBody = createBatchBody(requests: requests)
        
        do {
            // 执行批量请求
            let response = try await performHTTPRequest(
                endpoint: batchEndpoint,
                method: "POST",
                body: batchBody
            )
            
            // 解析批量响应
            let batchResponses = try JSONDecoder().decode([BatchResponse].self, from: response)
            
            // 分发响应到各个请求
            for (index, request) in requests.enumerated() {
                if index < batchResponses.count {
                    let response = batchResponses[index]
                    if let data = response.data {
                        request.completion(.success(data))
                    } else if let error = response.error {
                        request.completion(.failure(APIError.serverError(response.status)))
                    }
                }
            }
        } catch {
            // 批量请求失败，回退到单个请求
            print("⚠️ 批量请求失败，回退到单个请求: \(error)")
            await executeFallbackRequests(requests)
        }
    }
    
    private func executeFallbackRequests(_ requests: [BatchRequestItem]) async {
        // 并行执行单个请求
        await withTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask {
                    do {
                        let response = try await self.performHTTPRequest(
                            endpoint: request.endpoint,
                            method: request.method,
                            body: request.body
                        )
                        request.completion(.success(response))
                    } catch {
                        request.completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func createBatchBody(requests: [BatchRequestItem]) -> Data {
        let batchItems = requests.map { request in
            [
                "id": request.id,
                "endpoint": request.endpoint,
                "method": request.method,
                "body": request.body?.base64EncodedString() ?? "",
                "headers": request.headers
            ]
        }
        
        return (try? JSONSerialization.data(withJSONObject: batchItems)) ?? Data()
    }
    
    private func performHTTPRequest(
        endpoint: String,
        method: String,
        body: Data?
    ) async throws -> Data {
        // 使用现有的网络请求逻辑
        guard let url = URL(string: "\(SupabaseManager.shared.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        
        // 添加认证头
        if let token = KeychainManager.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(SupabaseManager.shared.apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return data
    }
    
    // MARK: - 统计方法
    
    func getStatistics() -> (batched: Int, saved: Int, efficiency: Double) {
        let efficiency = totalBatchedRequests > 0 
            ? Double(totalSavedRequests) / Double(totalBatchedRequests) 
            : 0
        return (totalBatchedRequests, totalSavedRequests, efficiency)
    }
    
    func resetStatistics() {
        totalBatchedRequests = 0
        totalSavedRequests = 0
    }
}

// MARK: - 请求合并优化
extension BatchRequestManager {
    
    /// 智能请求合并 - 相同端点的GET请求
    func coalesceGETRequests(_ requests: [BatchRequestItem]) -> [BatchRequestItem] {
        var coalescedRequests: [String: BatchRequestItem] = [:]
        var coalescedCallbacks: [String: [(Result<Data, Error>) -> Void]] = [:]
        
        for request in requests where request.method == "GET" {
            let key = request.endpoint
            
            if coalescedRequests[key] == nil {
                coalescedRequests[key] = request
                coalescedCallbacks[key] = [request.completion]
            } else {
                // 合并回调
                coalescedCallbacks[key]?.append(request.completion)
            }
        }
        
        // 创建合并后的请求
        return coalescedRequests.map { (endpoint, request) in
            BatchRequestItem(
                endpoint: endpoint,
                method: "GET",
                body: nil,
                headers: request.headers
            ) { result in
                // 分发结果到所有回调
                if let callbacks = coalescedCallbacks[endpoint] {
                    for callback in callbacks {
                        callback(result)
                    }
                }
            }
        }
    }
}

// MARK: - 优先级队列支持
extension BatchRequestManager {
    
    enum RequestPriority: Int {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3
    }
    
    struct PrioritizedRequest {
        let request: BatchRequestItem
        let priority: RequestPriority
        let timestamp: Date
    }
    
    /// 根据优先级排序请求
    func prioritizeRequests(_ requests: [PrioritizedRequest]) -> [BatchRequestItem] {
        return requests.sorted { (a, b) in
            if a.priority.rawValue != b.priority.rawValue {
                return a.priority.rawValue > b.priority.rawValue
            }
            return a.timestamp < b.timestamp
        }.map { $0.request }
    }
}