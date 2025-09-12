//
//  KnowledgeRetriever.swift
//  PurpleM
//
//  Phase 4: 检索系统实现
//  混合搜索（向量70% + 全文30%）+ 缓存优化
//

import Foundation
import SwiftUI
import Supabase

// MARK: - 搜索结果模型
struct SearchResult: Codable, Identifiable {
    let id: UUID
    let bookTitle: String
    let chapter: String?
    let content: String
    let pageNumber: Int?
    let score: Float
    let vectorSimilarity: Float?
    let textRank: Float?
    
    // 格式化引用
    var citation: String {
        var cite = bookTitle
        if let chapter = chapter {
            cite += " - \(chapter)"
        }
        if let page = pageNumber {
            cite += "，第\(page)页"
        }
        return cite
    }
    
    // 置信度等级
    var confidenceLevel: String {
        switch score {
        case 0.9...:
            return "极高"
        case 0.8..<0.9:
            return "高"
        case 0.7..<0.8:
            return "中"
        default:
            return "低"
        }
    }
}

// MARK: - 缓存项
struct CacheItem {
    let query: String
    let results: [SearchResult]
    let timestamp: Date
    
    var isExpired: Bool {
        // 15分钟过期
        Date().timeIntervalSince(timestamp) > 900
    }
}

// MARK: - 知识检索器（Phase 4核心实现）
@MainActor
class KnowledgeRetriever: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var searchError: String?
    @Published var searchStats: SearchStatistics?
    
    private let supabase: SupabaseClient
    private let openAIKey: String
    private var cache: [String: CacheItem] = [:]
    private let cacheQueue = DispatchQueue(label: "knowledge.cache")
    
    // 配置参数（符合技术设计文档）
    private let vectorWeight: Float = 0.7
    private let textWeight: Float = 0.3
    private let matchThreshold: Float = 0.7
    private let defaultLimit = 5
    
    init(openAIKey: String) {
        self.openAIKey = openAIKey
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.projectURL)!,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
    
    // MARK: - 混合搜索（核心方法）
    
    /// 执行混合搜索：向量70% + 全文30%
    func hybridSearch(_ query: String, limit: Int? = nil) async {
        let searchLimit = limit ?? defaultLimit
        
        // 检查缓存
        if let cached = getCachedResults(for: query) {
            self.searchResults = cached
            self.searchStats = SearchStatistics(
                totalResults: cached.count,
                searchTime: 0,
                cacheHit: true
            )
            return
        }
        
        isSearching = true
        searchError = nil
        let startTime = Date()
        
        do {
            // 1. 生成查询向量
            let queryEmbedding = await generateEmbedding(for: query)
            
            // 2. 执行混合搜索
            let results: [SearchResult]
            
            if let embedding = queryEmbedding {
                // 有向量：混合搜索
                results = try await performHybridSearch(
                    query: query,
                    embedding: embedding,
                    limit: searchLimit
                )
            } else {
                // 无向量：降级到纯文本搜索
                results = try await performTextSearch(
                    query: query,
                    limit: searchLimit
                )
            }
            
            // 3. 缓存结果
            cacheResults(results, for: query)
            
            // 4. 更新状态
            self.searchResults = results
            self.searchStats = SearchStatistics(
                totalResults: results.count,
                searchTime: Date().timeIntervalSince(startTime),
                cacheHit: false,
                averageScore: results.map { $0.score }.reduce(0, +) / Float(max(results.count, 1))
            )
            
        } catch {
            searchError = "搜索失败: \(error.localizedDescription)"
            searchResults = []
        }
        
        isSearching = false
    }
    
    /// 执行向量搜索
    func vectorSearch(_ query: String, limit: Int? = nil) async {
        let searchLimit = limit ?? defaultLimit
        
        isSearching = true
        searchError = nil
        
        do {
            // 生成查询向量
            guard let queryEmbedding = await generateEmbedding(for: query) else {
                throw SearchError.embeddingFailed
            }
            
            // 调用向量搜索函数
            let results: [SearchResult] = try await supabase
                .rpc("search_knowledge", params: [
                    "query_embedding": queryEmbedding,
                    "match_threshold": matchThreshold,
                    "match_count": searchLimit
                ])
                .execute()
                .value
            
            self.searchResults = results
            
        } catch {
            searchError = "向量搜索失败: \(error.localizedDescription)"
            searchResults = []
        }
        
        isSearching = false
    }
    
    // MARK: - 上下文扩展
    
    /// 获取结果的上下文（前后文）
    func getContextWindow(for resultId: UUID) async -> String {
        do {
            let contexts: [[String: Any]] = try await supabase
                .rpc("get_context_window", params: [
                    "knowledge_id": resultId.uuidString,
                    "window_size": 1
                ])
                .execute()
                .value
            
            // 组合前后文
            var fullContext = ""
            for context in contexts {
                if let position = context["position"] as? String,
                   let content = context["content"] as? String {
                    switch position {
                    case "before":
                        fullContext += "【前文】\n\(content)\n\n"
                    case "current":
                        fullContext += "【当前】\n\(content)\n\n"
                    case "after":
                        fullContext += "【后文】\n\(content)\n"
                    default:
                        break
                    }
                }
            }
            
            return fullContext
            
        } catch {
            return "无法获取上下文"
        }
    }
    
    // MARK: - 私有方法
    
    /// 生成查询向量
    private func generateEmbedding(for text: String) async -> [Float]? {
        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "model": "text-embedding-ada-002",
            "input": text
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let response = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
            return response.data.first?.embedding.map { Float($0) }
            
        } catch {
            print("生成向量失败: \(error)")
            return nil
        }
    }
    
    /// 执行混合搜索
    private func performHybridSearch(
        query: String,
        embedding: [Float],
        limit: Int
    ) async throws -> [SearchResult] {
        
        // 调用数据库的混合搜索函数
        let results: [SearchResult] = try await supabase
            .rpc("hybrid_search", params: [
                "search_query": query,
                "query_embedding": embedding,
                "match_count": limit,
                "vector_weight": vectorWeight,
                "text_weight": textWeight
            ])
            .execute()
            .value
        
        return results
    }
    
    /// 执行纯文本搜索
    private func performTextSearch(
        query: String,
        limit: Int
    ) async throws -> [SearchResult] {
        
        // 降级到纯文本搜索
        let results: [SearchResult] = try await supabase
            .rpc("hybrid_search", params: [
                "search_query": query,
                "query_embedding": nil,
                "match_count": limit
            ])
            .execute()
            .value
        
        return results
    }
    
    // MARK: - 缓存管理
    
    /// 获取缓存结果
    private func getCachedResults(for query: String) -> [SearchResult]? {
        cacheQueue.sync {
            guard let item = cache[query.lowercased()],
                  !item.isExpired else {
                return nil
            }
            return item.results
        }
    }
    
    /// 缓存搜索结果
    private func cacheResults(_ results: [SearchResult], for query: String) {
        cacheQueue.async {
            self.cache[query.lowercased()] = CacheItem(
                query: query,
                results: results,
                timestamp: Date()
            )
            
            // 清理过期缓存
            self.cleanExpiredCache()
        }
    }
    
    /// 清理过期缓存
    private func cleanExpiredCache() {
        let expiredKeys = cache.compactMap { key, value in
            value.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
        
        // 限制缓存大小（最多100个查询）
        if cache.count > 100 {
            let sortedKeys = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let keysToRemove = sortedKeys.prefix(cache.count - 100).map { $0.key }
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
    
    /// 清空所有缓存
    func clearCache() {
        cacheQueue.async {
            self.cache.removeAll()
        }
    }
    
    // MARK: - 批量操作
    
    /// 预加载常用查询
    func preloadCommonQueries() async {
        let commonQueries = [
            "紫微星", "天机星", "太阳星", "武曲星",
            "命宫", "夫妻宫", "财帛宫", "官禄宫",
            "化禄", "化权", "化科", "化忌"
        ]
        
        for query in commonQueries {
            if getCachedResults(for: query) == nil {
                await hybridSearch(query, limit: 3)
                // 避免请求过快
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
        }
    }
}

// MARK: - 辅助模型

struct SearchStatistics {
    let totalResults: Int
    let searchTime: TimeInterval
    let cacheHit: Bool
    let averageScore: Float?
    
    var formattedTime: String {
        String(format: "%.0fms", searchTime * 1000)
    }
}

struct EmbeddingResponse: Codable {
    struct EmbeddingData: Codable {
        let embedding: [Double]
    }
    let data: [EmbeddingData]
}

enum SearchError: Error {
    case embeddingFailed
    case searchFailed
    case noResults
}

// MARK: - 使用示例
extension KnowledgeRetriever {
    static let example = """
    // 创建检索器
    let retriever = KnowledgeRetriever(openAIKey: "your-key")
    
    // 执行混合搜索
    await retriever.hybridSearch("紫微星在命宫")
    
    // 获取上下文
    if let firstResult = retriever.searchResults.first {
        let context = await retriever.getContextWindow(for: firstResult.id)
    }
    
    // 预加载常用查询
    await retriever.preloadCommonQueries()
    
    // 查看搜索统计
    if let stats = retriever.searchStats {
        print("搜索耗时: \\(stats.formattedTime)")
        print("缓存命中: \\(stats.cacheHit)")
    }
    """
}