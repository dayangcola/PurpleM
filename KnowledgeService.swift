//
//  KnowledgeService.swift
//  PurpleM
//
//  知识库搜索和管理服务
//

import Foundation
import SwiftUI
import Supabase

// MARK: - 知识模型
struct Knowledge: Codable, Identifiable {
    let id: UUID
    let content: String
    let category: String?
    let keywords: [String]?
    var relevance: Double?
    
    var title: String {
        // 从内容中提取标题
        if let range = content.range(of: "】") {
            let titlePart = String(content[...range.lowerBound])
            return titlePart.replacingOccurrences(of: "【", with: "")
        }
        return String(content.prefix(30))
    }
    
    var preview: String {
        // 获取内容预览
        let cleanContent = content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        return String(cleanContent.prefix(200))
    }
}

// MARK: - 搜索结果
struct SearchResult: Codable {
    let success: Bool
    let query: String
    let results: [Knowledge]
    let count: Int
}

// MARK: - 知识分类
enum KnowledgeCategory: String, CaseIterable {
    case basic = "基础理论"
    case palace = "十二宫位"
    case star = "十四主星"
    case sihua = "四化理论"
    case pattern = "星曜组合"
    case practice = "实际应用"
    case classic1 = "古籍-卷一"
    case classic2 = "古籍-卷二"
    case classic3 = "古籍-卷三"
    case formula = "实用口诀"
    case other = "其他"
    
    var icon: String {
        switch self {
        case .basic: return "book.fill"
        case .palace: return "square.grid.3x3.fill"
        case .star: return "star.fill"
        case .sihua: return "arrow.triangle.2.circlepath"
        case .pattern: return "star.circle.fill"
        case .practice: return "lightbulb.fill"
        case .classic1, .classic2, .classic3: return "scroll.fill"
        case .formula: return "text.quote"
        case .other: return "folder.fill"
        }
    }
}

// MARK: - 知识库服务
@MainActor
class KnowledgeService: ObservableObject {
    @Published var searchResults: [Knowledge] = []
    @Published var isSearching = false
    @Published var searchError: String?
    @Published var categories: [KnowledgeCategory: [Knowledge]] = [:]
    @Published var favorites: Set<UUID> = []
    
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: SupabaseConfig.projectURL)!,
        supabaseKey: SupabaseConfig.anonKey
    )
    
    // MARK: - 搜索功能
    
    /// 文本搜索知识库
    func searchKnowledge(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        do {
            // 调用搜索函数
            let response: [Knowledge] = try await supabase
                .rpc("search_knowledge_by_text", params: [
                    "search_query": query,
                    "match_count": 10
                ])
                .execute()
                .value
            
            searchResults = response
        } catch {
            searchError = "搜索失败: \(error.localizedDescription)"
            searchResults = []
        }
        
        isSearching = false
    }
    
    /// 向量语义搜索（需要先生成embedding）
    func semanticSearch(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        do {
            // 调用Edge Function进行语义搜索
            let url = URL(string: "\(SupabaseConfig.projectURL)/functions/v1/search-knowledge")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
            
            let body = ["query": query, "limit": 10, "useEmbedding": true]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let result = try JSONDecoder().decode(SearchResult.self, from: data)
            
            if result.success {
                searchResults = result.results
            } else {
                throw NSError(domain: "SearchError", code: 0, userInfo: [NSLocalizedDescriptionKey: "搜索失败"])
            }
        } catch {
            searchError = "语义搜索失败: \(error.localizedDescription)"
            searchResults = []
        }
        
        isSearching = false
    }
    
    // MARK: - 分类浏览
    
    /// 按分类获取知识
    func loadKnowledgeByCategory(_ category: KnowledgeCategory) async {
        do {
            let response: [Knowledge] = try await supabase
                .rpc("get_knowledge_by_category", params: [
                    "target_category": category.rawValue,
                    "page_size": 20,
                    "page_offset": 0
                ])
                .execute()
                .value
            
            categories[category] = response
        } catch {
            print("加载分类失败: \(error)")
        }
    }
    
    /// 加载所有分类
    func loadAllCategories() async {
        await withTaskGroup(of: Void.self) { group in
            for category in KnowledgeCategory.allCases {
                group.addTask {
                    await self.loadKnowledgeByCategory(category)
                }
            }
        }
    }
    
    // MARK: - 关键词搜索
    
    /// 通过关键词搜索
    func searchByKeywords(_ keywords: [String]) async {
        guard !keywords.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        do {
            let response: [Knowledge] = try await supabase
                .rpc("search_by_keywords", params: [
                    "search_keywords": keywords,
                    "match_count": 10
                ])
                .execute()
                .value
            
            searchResults = response
        } catch {
            searchError = "关键词搜索失败: \(error.localizedDescription)"
            searchResults = []
        }
        
        isSearching = false
    }
    
    // MARK: - AI增强
    
    /// 获取与问题相关的知识，用于增强AI回答
    func getRelatedKnowledge(for question: String) async -> String {
        // 先进行搜索
        await searchKnowledge(question)
        
        guard !searchResults.isEmpty else {
            return ""
        }
        
        // 构建知识上下文
        var context = "相关知识参考：\n\n"
        for (index, knowledge) in searchResults.prefix(3).enumerated() {
            context += "【参考\(index + 1)】\n"
            context += knowledge.content.prefix(500) + "\n\n"
        }
        
        return context
    }
    
    // MARK: - 收藏功能
    
    /// 添加收藏
    func addToFavorites(_ knowledgeId: UUID) {
        favorites.insert(knowledgeId)
        saveFavorites()
    }
    
    /// 移除收藏
    func removeFromFavorites(_ knowledgeId: UUID) {
        favorites.remove(knowledgeId)
        saveFavorites()
    }
    
    /// 检查是否已收藏
    func isFavorite(_ knowledgeId: UUID) -> Bool {
        favorites.contains(knowledgeId)
    }
    
    private func saveFavorites() {
        // 保存到UserDefaults
        let favoriteIds = favorites.map { $0.uuidString }
        UserDefaults.standard.set(favoriteIds, forKey: "knowledge_favorites")
    }
    
    private func loadFavorites() {
        // 从UserDefaults加载
        if let favoriteIds = UserDefaults.standard.stringArray(forKey: "knowledge_favorites") {
            favorites = Set(favoriteIds.compactMap { UUID(uuidString: $0) })
        }
    }
    
    // MARK: - 初始化
    
    init() {
        loadFavorites()
    }
}