//
//  KnowledgeManager.swift
//  PurpleM
//
//  知识库管理器 - 优化版
//  提供缓存、预加载和智能搜索
//

import Foundation
import SwiftUI

// MARK: - 知识库管理器
@MainActor
class KnowledgeManager: ObservableObject {
    static let shared = KnowledgeManager()
    
    @Published var isSearching = false
    @Published var cachedResults: [String: [KnowledgeItem]] = [:]
    @Published var searchHistory: [String] = []
    @Published var hotTopics: [String] = []
    
    private let cacheTimeout: TimeInterval = 900 // 15分钟缓存
    private var cacheTimestamps: [String: Date] = [:]
    private let maxCacheSize = 50 // 最多缓存50个查询
    private let maxHistorySize = 20 // 最多保存20条历史
    
    // MARK: - 知识项模型
    struct KnowledgeItem: Codable, Identifiable {
        let id: UUID
        let bookTitle: String?
        let chapter: String?
        let content: String
        let relevance: Float?
        let similarity: Float?
        
        var citation: String {
            if let chapter = chapter {
                return "《紫微斗数知识库·\(chapter)》"
            }
            return "《紫微斗数知识库》"
        }
        
        var preview: String {
            String(content.prefix(200))
        }
        
        var score: Float {
            // 综合评分
            return (relevance ?? 0) * 0.3 + (similarity ?? 0) * 0.7
        }
    }
    
    // MARK: - 智能搜索引用
    struct KnowledgeReference: Identifiable {
        let id = UUID()
        let number: Int
        let citation: String
        let content: String
        let score: Float
        
        var formatted: String {
            "[\(number)] \(citation)"
        }
    }
    
    init() {
        loadHotTopics()
        loadSearchHistory()
        preloadCommonQueries()
    }
    
    // MARK: - 核心搜索方法
    func searchKnowledge(
        _ query: String,
        useCache: Bool = true,
        limit: Int = 5
    ) async -> [KnowledgeItem] {
        
        // 1. 检查缓存
        if useCache, let cached = getCachedResults(for: query) {
            print("📦 使用缓存结果: \(query)")
            return cached
        }
        
        isSearching = true
        defer { isSearching = false }
        
        // 2. 记录搜索历史
        addToHistory(query)
        
        do {
            // 3. 执行智能搜索（混合搜索）
            let results = try await SupabaseManager.shared.smartSearch(
                query: query,
                limit: limit
            )
            
            // 4. 缓存结果
            cacheResults(results, for: query)
            
            // 5. 更新热门话题
            updateHotTopics(query)
            
            return results
            
        } catch {
            print("❌ 搜索失败: \(error)")
            
            // 降级到文本搜索
            return await fallbackTextSearch(query, limit: limit)
        }
    }
    
    // MARK: - 增强搜索（带上下文）
    func searchWithContext(
        query: String,
        context: [String] = [],
        userChart: Chart? = nil
    ) async -> (items: [KnowledgeItem], references: [KnowledgeReference]) {
        
        // 1. 构建增强查询
        var enhancedQuery = query
        
        // 添加命盘上下文
        if let chart = userChart {
            if query.contains("命宫") || query.contains("我的") {
                enhancedQuery += " \(chart.mingGong.mainStar)"
            }
        }
        
        // 添加对话上下文
        for ctx in context.suffix(2) {
            if ctx.contains("紫微") || ctx.contains("天机") || ctx.contains("星") {
                enhancedQuery += " \(ctx)"
            }
        }
        
        // 2. 执行搜索
        let items = await searchKnowledge(enhancedQuery)
        
        // 3. 生成引用
        let references = items.enumerated().map { index, item in
            KnowledgeReference(
                number: index + 1,
                citation: item.citation,
                content: item.content,
                score: item.score
            )
        }
        
        return (items, references)
    }
    
    // MARK: - 降级文本搜索
    private func fallbackTextSearch(_ query: String, limit: Int) async -> [KnowledgeItem] {
        do {
            let results = try await SupabaseManager.shared.searchKnowledgeWithTextSearch(
                query: query,
                limit: limit
            )
            
            return results.compactMap { dict in
                guard let id = (dict["id"] as? String).flatMap(UUID.init),
                      let content = dict["content"] as? String else {
                    return nil
                }
                
                return KnowledgeItem(
                    id: id,
                    bookTitle: dict["book_title"] as? String,
                    chapter: dict["chapter"] as? String,
                    content: content,
                    relevance: dict["relevance"] as? Float,
                    similarity: nil
                )
            }
        } catch {
            print("❌ 文本搜索也失败: \(error)")
            return []
        }
    }
    
    // MARK: - 缓存管理
    private func getCachedResults(for query: String) -> [KnowledgeItem]? {
        guard let cached = cachedResults[query],
              let timestamp = cacheTimestamps[query],
              Date().timeIntervalSince(timestamp) < cacheTimeout else {
            return nil
        }
        return cached
    }
    
    private func cacheResults(_ results: [KnowledgeItem], for query: String) {
        cachedResults[query] = results
        cacheTimestamps[query] = Date()
        
        // 限制缓存大小
        if cachedResults.count > maxCacheSize {
            // 删除最旧的缓存
            if let oldestKey = cacheTimestamps.min(by: { $0.value < $1.value })?.key {
                cachedResults.removeValue(forKey: oldestKey)
                cacheTimestamps.removeValue(forKey: oldestKey)
            }
        }
    }
    
    func clearCache() {
        cachedResults.removeAll()
        cacheTimestamps.removeAll()
        print("🗑️ 缓存已清空")
    }
    
    // MARK: - 搜索历史
    private func addToHistory(_ query: String) {
        // 避免重复
        searchHistory.removeAll { $0 == query }
        searchHistory.insert(query, at: 0)
        
        // 限制历史大小
        if searchHistory.count > maxHistorySize {
            searchHistory = Array(searchHistory.prefix(maxHistorySize))
        }
        
        // 保存到UserDefaults
        UserDefaults.standard.set(searchHistory, forKey: "knowledge_search_history")
    }
    
    private func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: "knowledge_search_history") ?? []
    }
    
    // MARK: - 热门话题
    private func updateHotTopics(_ query: String) {
        // 提取关键词
        let keywords = extractKeywords(from: query)
        
        for keyword in keywords {
            if !hotTopics.contains(keyword) {
                hotTopics.append(keyword)
            }
        }
        
        // 保持热门话题在10个以内
        if hotTopics.count > 10 {
            hotTopics = Array(hotTopics.suffix(10))
        }
    }
    
    private func loadHotTopics() {
        // 预设热门话题
        hotTopics = [
            "紫微星",
            "命宫",
            "财帛宫",
            "夫妻宫",
            "事业宫",
            "化忌",
            "化禄",
            "流年",
            "大运",
            "十四主星"
        ]
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let keywords = ["紫微", "天机", "太阳", "武曲", "天同", "廉贞",
                       "天府", "太阴", "贪狼", "巨门", "天相", "天梁",
                       "七杀", "破军", "命宫", "财帛", "夫妻", "事业",
                       "化禄", "化权", "化科", "化忌"]
        
        return keywords.filter { text.contains($0) }
    }
    
    // MARK: - 预加载常用查询
    private func preloadCommonQueries() {
        Task {
            let commonQueries = [
                "紫微星",
                "命宫",
                "十二宫位",
                "四化"
            ]
            
            for query in commonQueries {
                _ = await searchKnowledge(query, useCache: true, limit: 3)
            }
            
            print("📦 预加载完成: \(commonQueries.count) 个常用查询")
        }
    }
    
    // MARK: - 智能推荐
    func getRecommendedQueries(basedOn currentQuery: String) -> [String] {
        var recommendations: [String] = []
        
        // 基于当前查询推荐相关内容
        if currentQuery.contains("紫微") {
            recommendations.append(contentsOf: ["紫微星性质", "紫微在十二宫", "紫微化权"])
        }
        
        if currentQuery.contains("命宫") {
            recommendations.append(contentsOf: ["命宫主星", "命宫空宫", "命宫三方四正"])
        }
        
        if currentQuery.contains("流年") {
            recommendations.append(contentsOf: ["流年运势", "流年四化", "流年吉凶"])
        }
        
        // 添加搜索历史中的相关查询
        let relatedHistory = searchHistory.filter { history in
            history != currentQuery &&
            extractKeywords(from: history).contains { keyword in
                currentQuery.contains(keyword)
            }
        }
        recommendations.append(contentsOf: relatedHistory.prefix(2))
        
        // 去重并限制数量
        let uniqueRecommendations = Array(Set(recommendations)).prefix(5)
        
        return Array(uniqueRecommendations)
    }
}

// MARK: - SwiftUI视图扩展
struct KnowledgeSearchView: View {
    @StateObject private var manager = KnowledgeManager.shared
    @State private var searchText = ""
    @State private var searchResults: [KnowledgeManager.KnowledgeItem] = []
    
    var body: some View {
        VStack {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜索紫微斗数知识...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                
                if manager.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            
            // 热门话题
            if searchResults.isEmpty && !manager.hotTopics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(manager.hotTopics, id: \.self) { topic in
                            Button(action: {
                                searchText = topic
                                performSearch()
                            }) {
                                Text(topic)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(15)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 搜索结果
            List(searchResults) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.citation)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(item.preview)
                        .font(.body)
                        .lineLimit(3)
                    
                    if let score = item.relevance {
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text("相关度: \(Int(score * 100))%")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Spacer()
        }
        .navigationTitle("知识库")
    }
    
    private func performSearch() {
        Task {
            searchResults = await manager.searchKnowledge(searchText)
        }
    }
}

// MARK: - 使用示例
extension KnowledgeManager {
    static let usageExample = """
    // 1. 基础搜索
    let results = await KnowledgeManager.shared.searchKnowledge("紫微星")
    
    // 2. 带上下文的搜索
    let (items, refs) = await KnowledgeManager.shared.searchWithContext(
        query: "我的命宫如何",
        context: conversationHistory,
        userChart: currentChart
    )
    
    // 3. 获取推荐查询
    let recommendations = KnowledgeManager.shared.getRecommendedQueries(
        basedOn: "紫微星"
    )
    
    // 4. 清空缓存
    KnowledgeManager.shared.clearCache()
    """
}