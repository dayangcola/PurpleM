//
//  OfflineCacheManager.swift
//  PurpleM
//
//  离线数据缓存管理器
//

import Foundation
import UIKit

// MARK: - 缓存策略枚举
enum CachePolicy {
    case alwaysCache           // 总是缓存
    case cacheIfOffline       // 离线时缓存
    case cacheWithExpiry(TimeInterval) // 带过期时间的缓存
    case neverCache           // 从不缓存
}

// MARK: - 缓存项模型
class CacheItem: NSObject, Codable {
    let key: String
    let data: Data
    let timestamp: Date
    let expiryDate: Date?
    let metadata: [String: String]?
    
    var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return Date() > expiry
    }
    
    init(key: String, data: Data, timestamp: Date, expiryDate: Date?, metadata: [String: String]?) {
        self.key = key
        self.data = data
        self.timestamp = timestamp
        self.expiryDate = expiryDate
        self.metadata = metadata
        super.init()
    }
}

// MARK: - 离线缓存管理器
@MainActor
class OfflineCacheManager {
    static let shared = OfflineCacheManager()
    
    // 缓存目录
    private let cacheDirectory: URL
    private let cacheQueue = DispatchQueue(label: "com.purplem.cache", attributes: .concurrent)
    
    // 内存缓存（LRU）
    private var memoryCache = NSCache<NSString, CacheItem>()
    
    // 缓存统计
    private(set) var cacheHits: Int = 0
    private(set) var cacheMisses: Int = 0
    
    private init() {
        // 设置缓存目录
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("OfflineCache")
        
        // 创建缓存目录
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 配置内存缓存
        memoryCache.countLimit = 50 // 最多缓存50个项目
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // 监听内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // 启动时清理过期缓存
        Task {
            await cleanExpiredCache()
        }
    }
    
    // MARK: - 公共接口
    
    /// 保存数据到缓存
    func save<T: Codable>(_ object: T, forKey key: String, policy: CachePolicy = .cacheWithExpiry(3600)) async throws {
        let data = try JSONEncoder().encode(object)
        
        // 计算过期时间
        let expiryDate: Date?
        switch policy {
        case .neverCache:
            return
        case .cacheWithExpiry(let interval):
            expiryDate = Date().addingTimeInterval(interval)
        default:
            expiryDate = nil
        }
        
        // 创建缓存项
        let cacheItem = CacheItem(
            key: key,
            data: data,
            timestamp: Date(),
            expiryDate: expiryDate,
            metadata: ["type": String(describing: T.self)]
        )
        
        // 保存到内存缓存
        memoryCache.setObject(cacheItem, forKey: key as NSString, cost: data.count)
        
        // 异步保存到磁盘
        let cacheURL = cacheDirectory.appendingPathComponent(key.toBase64())
        try await withCheckedThrowingContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                do {
                    let encoded = try JSONEncoder().encode(cacheItem)
                    try encoded.write(to: cacheURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        print("💾 已缓存数据: \(key)")
    }
    
    /// 从缓存读取数据
    func load<T: Codable>(_ type: T.Type, forKey key: String) async -> T? {
        // 先检查内存缓存
        if let cacheItem = memoryCache.object(forKey: key as NSString) {
            if !cacheItem.isExpired {
                cacheHits += 1
                print("🎯 内存缓存命中: \(key)")
                return try? JSONDecoder().decode(type, from: cacheItem.data)
            } else {
                // 过期了，删除
                memoryCache.removeObject(forKey: key as NSString)
            }
        }
        
        // 检查磁盘缓存
        let cacheURL = cacheDirectory.appendingPathComponent(key.toBase64())
        
        return await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                guard FileManager.default.fileExists(atPath: cacheURL.path),
                      let data = try? Data(contentsOf: cacheURL),
                      let cacheItem = try? JSONDecoder().decode(CacheItem.self, from: data) else {
                    DispatchQueue.main.async {
                        self.cacheMisses += 1
                        print("❌ 缓存未命中: \(key)")
                    }
                    continuation.resume(returning: nil)
                    return
                }
                
                // 检查是否过期
                if cacheItem.isExpired {
                    print("⏰ 缓存已过期: \(key)")
                    try? FileManager.default.removeItem(at: cacheURL)
                    DispatchQueue.main.async {
                        self.cacheMisses += 1
                    }
                    continuation.resume(returning: nil)
                    return
                }
                
                // 解码数据
                if let object = try? JSONDecoder().decode(type, from: cacheItem.data) {
                    DispatchQueue.main.async {
                        self.cacheHits += 1
                        print("💿 磁盘缓存命中: \(key)")
                        // 更新内存缓存
                        self.memoryCache.setObject(cacheItem, forKey: key as NSString, cost: cacheItem.data.count)
                    }
                    continuation.resume(returning: object)
                } else {
                    DispatchQueue.main.async {
                        self.cacheMisses += 1
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// 删除缓存
    func remove(forKey key: String) async {
        // 从内存缓存删除
        memoryCache.removeObject(forKey: key as NSString)
        
        // 从磁盘删除
        let cacheURL = cacheDirectory.appendingPathComponent(key.toBase64())
        try? FileManager.default.removeItem(at: cacheURL)
        
        print("🗑️ 已删除缓存: \(key)")
    }
    
    /// 清空所有缓存
    func clearAll() async {
        // 清空内存缓存
        memoryCache.removeAllObjects()
        
        // 清空磁盘缓存
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        // 重置统计
        cacheHits = 0
        cacheMisses = 0
        
        print("🗑️ 已清空所有缓存")
    }
    
    /// 清理过期缓存
    func cleanExpiredCache() async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                var removedCount = 0
                
                if let files = try? FileManager.default.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil) {
                    for file in files {
                        if let data = try? Data(contentsOf: file),
                           let cacheItem = try? JSONDecoder().decode(CacheItem.self, from: data),
                           cacheItem.isExpired {
                            try? FileManager.default.removeItem(at: file)
                            removedCount += 1
                        }
                    }
                }
                
                if removedCount > 0 {
                    print("🧹 清理了 \(removedCount) 个过期缓存项")
                }
                
                continuation.resume()
            }
        }
    }
    
    /// 获取缓存大小
    func getCacheSize() async -> Int64 {
        await withCheckedContinuation { continuation in
            cacheQueue.async {
                var totalSize: Int64 = 0
                
                if let files = try? FileManager.default.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
                    for file in files {
                        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                           let size = attributes[.size] as? Int64 {
                            totalSize += size
                        }
                    }
                }
                
                continuation.resume(returning: totalSize)
            }
        }
    }
    
    /// 获取缓存统计信息
    func getCacheStatistics() -> (hits: Int, misses: Int, hitRate: Double) {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0
        return (cacheHits, cacheMisses, hitRate)
    }
    
    // MARK: - 私有方法
    
    @objc private func handleMemoryWarning() {
        print("⚠️ 收到内存警告，清理内存缓存")
        memoryCache.removeAllObjects()
    }
}

// MARK: - 缓存Key扩展
extension OfflineCacheManager {
    enum CacheKey {
        static let userProfile = "user_profile"
        static let starChart = "star_chart"
        static let chatHistory = "chat_history"
        static let aiQuota = "ai_quota"
        static let preferences = "preferences"
        
        static func starChart(userId: String) -> String {
            return "star_chart_\(userId)"
        }
        
        static func chatHistory(sessionId: String) -> String {
            return "chat_history_\(sessionId)"
        }
    }
}

// MARK: - String扩展
private extension String {
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }
}

// MARK: - 网络状态感知缓存
extension OfflineCacheManager {
    /// 智能加载（先缓存后网络）
    func loadWithFallback<T: Codable>(
        _ type: T.Type,
        forKey key: String,
        networkLoader: @escaping () async throws -> T?,
        cachePolicy: CachePolicy = .cacheWithExpiry(3600)
    ) async -> T? {
        // 先尝试从缓存加载
        if let cached = await load(type, forKey: key) {
            // 如果在线，异步更新缓存
            if NetworkMonitor.shared.isConnected {
                Task {
                    if let fresh = try? await networkLoader() {
                        try? await save(fresh, forKey: key, policy: cachePolicy)
                    }
                }
            }
            return cached
        }
        
        // 缓存没有，尝试从网络加载
        if NetworkMonitor.shared.isConnected {
            if let fresh = try? await networkLoader() {
                try? await save(fresh, forKey: key, policy: cachePolicy)
                return fresh
            }
        }
        
        return nil
    }
}