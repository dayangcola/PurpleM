//
//  EnhancedAIService.swift
//  PurpleM
//
//  增强版AI服务 - 集成知识库检索
//

import Foundation
import SwiftUI
import Supabase

// MARK: - 知识检索结果
struct KnowledgeContext {
    let content: String
    let source: String
    let relevance: Float
    
    var citation: String {
        if source.contains("卷") {
            return "《紫微斗数古籍·\(source)》"
        } else if source.contains("口诀") {
            return "《紫微斗数实用口诀》"
        } else {
            return "《紫微斗数知识库》"
        }
    }
}

// MARK: - 增强版AI服务
@MainActor
class EnhancedAIService: ObservableObject {
    @Published var isSearchingKnowledge = false
    @Published var knowledgeResults: [KnowledgeContext] = []
    
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: SupabaseConfig.projectURL)!,
        supabaseKey: SupabaseConfig.anonKey
    )
    
    // MARK: - 知识库检索
    
    /// 检索相关知识
    private func searchKnowledge(for query: String) async -> [KnowledgeContext] {
        // 提取关键词
        let keywords = extractKeywords(from: query)
        
        do {
            // 使用文本搜索（暂时不用向量搜索，因为embedding可能还没生成）
            let searchQuery = keywords.joined(separator: " ")
            
            // 构建搜索请求
            let results: [[String: Any]] = try await supabase
                .from("knowledge_base_simple")
                .select("content, category")
                .textSearch("content", searchQuery)
                .limit(5)
                .execute()
                .value
            
            // 转换为KnowledgeContext
            return results.compactMap { item in
                guard let content = item["content"] as? String,
                      let category = item["category"] as? String else { return nil }
                
                // 计算简单的相关度（基于关键词匹配）
                let relevance = calculateRelevance(content: content, keywords: keywords)
                
                return KnowledgeContext(
                    content: content,
                    source: category,
                    relevance: relevance
                )
            }.sorted { $0.relevance > $1.relevance }
            
        } catch {
            print("知识检索失败: \(error)")
            return []
        }
    }
    
    /// 提取关键词
    private func extractKeywords(from query: String) -> [String] {
        var keywords: [String] = []
        
        // 星曜关键词
        let stars = ["紫微", "天机", "太阳", "武曲", "天同", "廉贞",
                     "天府", "太阴", "贪狼", "巨门", "天相", "天梁",
                     "七杀", "破军"]
        
        // 宫位关键词
        let palaces = ["命宫", "兄弟宫", "夫妻宫", "子女宫", "财帛宫",
                       "疾厄宫", "迁移宫", "奴仆宫", "官禄宫", "田宅宫",
                       "福德宫", "父母宫"]
        
        // 四化关键词
        let sihua = ["化禄", "化权", "化科", "化忌"]
        
        // 其他重要概念
        let concepts = ["大限", "流年", "排盘", "格局", "三方四正"]
        
        // 检查查询中包含的关键词
        for keyword in stars + palaces + sihua + concepts {
            if query.contains(keyword) {
                keywords.append(keyword)
            }
        }
        
        // 如果没有找到特定关键词，使用通用分词
        if keywords.isEmpty {
            // 简单分词：按标点和空格分割
            let words = query.components(separatedBy: CharacterSet.punctuationCharacters.union(.whitespaces))
            keywords = words.filter { $0.count >= 2 } // 至少2个字符
        }
        
        return keywords
    }
    
    /// 计算相关度
    private func calculateRelevance(content: String, keywords: [String]) -> Float {
        var score: Float = 0
        
        for keyword in keywords {
            if content.contains(keyword) {
                // 标题中出现权重更高
                if content.prefix(50).contains(keyword) {
                    score += 2.0
                } else {
                    score += 1.0
                }
            }
        }
        
        return min(score / Float(max(keywords.count, 1)), 1.0)
    }
    
    // MARK: - 增强版聊天
    
    /// 发送增强版聊天消息（带知识库）
    func sendEnhancedMessage(
        _ message: String,
        conversationHistory: [ChatMessage],
        userInfo: UserInfo? = nil,
        chartData: ChartData? = nil
    ) async -> String {
        
        // 1. 检索相关知识
        isSearchingKnowledge = true
        let knowledgeContexts = await searchKnowledge(for: message)
        knowledgeResults = knowledgeContexts
        isSearchingKnowledge = false
        
        // 2. 构建增强提示词
        var enhancedPrompt = AIPersonality.systemPrompt + "\n\n"
        enhancedPrompt += AIPersonality.getContextPrompt(userInfo: userInfo, chartData: chartData)
        
        // 3. 添加知识库参考
        if !knowledgeContexts.isEmpty {
            enhancedPrompt += "\n\n【知识库参考】\n"
            enhancedPrompt += "以下是从紫微斗数专业知识库中检索到的相关内容，请参考这些内容提供更准确的回答：\n\n"
            
            for (index, context) in knowledgeContexts.prefix(3).enumerated() {
                enhancedPrompt += "参考\(index + 1) - \(context.citation)\n"
                enhancedPrompt += "相关度：\(Int(context.relevance * 100))%\n"
                
                // 截取内容摘要
                let contentPreview = String(context.content.prefix(300))
                enhancedPrompt += "内容：\(contentPreview)...\n\n"
            }
            
            enhancedPrompt += """
            【回答要求】
            1. 如果参考资料与问题相关，请基于资料提供准确回答
            2. 引用时请使用上标数字标注，如"根据记载[1]..."
            3. 回答末尾列出参考来源
            4. 如果参考资料不足，请说明并提供你的专业建议
            """
        }
        
        // 4. 调用AI服务
        do {
            let response = try await callBackendAPI(
                message: message,
                systemPrompt: enhancedPrompt,
                conversationHistory: conversationHistory,
                userInfo: userInfo
            )
            
            // 5. 添加引用标注
            var finalResponse = response
            if !knowledgeContexts.isEmpty {
                finalResponse += "\n\n---\n📚 参考资料：\n"
                for (index, context) in knowledgeContexts.prefix(3).enumerated() {
                    finalResponse += "[\(index + 1)] \(context.citation)\n"
                }
            }
            
            return finalResponse
            
        } catch {
            return "抱歉，我暂时无法回答你的问题。错误：\(error.localizedDescription)"
        }
    }
    
    /// 调用后端API
    private func callBackendAPI(
        message: String,
        systemPrompt: String,
        conversationHistory: [ChatMessage],
        userInfo: UserInfo?
    ) async throws -> String {
        
        let url = URL(string: AIConfig.backendURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        let requestBody = BackendChatRequest(
            message: message,
            conversationHistory: conversationHistory.map { msg in
                BackendChatRequest.APIMessage(
                    role: msg.role.rawValue,
                    content: msg.content
                )
            },
            userInfo: userInfo != nil ? BackendChatRequest.UserInfoData(
                name: userInfo!.name,
                gender: userInfo!.gender,
                hasChart: true
            ) : nil
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // 发送请求
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(BackendChatResponse.self, from: data)
        
        if response.success {
            return response.response
        } else {
            throw NSError(
                domain: "AIService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: response.error ?? "未知错误"]
            )
        }
    }
    
    // MARK: - 特定知识查询
    
    /// 查询特定主题的知识
    func querySpecificKnowledge(topic: String) async -> String {
        let contexts = await searchKnowledge(for: topic)
        
        guard !contexts.isEmpty else {
            return "未找到关于「\(topic)」的相关知识。"
        }
        
        var result = "关于「\(topic)」的知识：\n\n"
        
        for context in contexts.prefix(3) {
            result += "📖 \(context.citation)\n"
            result += "\(context.content)\n\n"
            result += "---\n\n"
        }
        
        return result
    }
    
    // MARK: - 知识推荐
    
    /// 根据用户星盘推荐相关知识
    func recommendKnowledge(for chartData: ChartData?) async -> [KnowledgeContext] {
        guard let chart = chartData else { return [] }
        
        // 基于命宫主星推荐
        var query = ""
        
        // 这里需要根据实际的ChartData结构来构建查询
        // 示例：假设能获取命宫主星
        query = "紫微星 命宫" // 这里应该是动态的
        
        return await searchKnowledge(for: query)
    }
}

// MARK: - 使用示例
extension EnhancedAIService {
    static let example = """
    // 在ChatView中使用
    @StateObject private var aiService = EnhancedAIService()
    
    // 发送增强消息
    let response = await aiService.sendEnhancedMessage(
        "紫微星在命宫代表什么？",
        conversationHistory: messages,
        userInfo: userInfo,
        chartData: chartData
    )
    
    // 查询特定知识
    let knowledge = await aiService.querySpecificKnowledge("化忌")
    
    // 获取推荐知识
    let recommendations = await aiService.recommendKnowledge(for: chartData)
    """
}