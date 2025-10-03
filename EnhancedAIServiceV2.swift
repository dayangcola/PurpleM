//
//  EnhancedAIServiceV2.swift
//  PurpleM
//
//  Phase 5: 完整AI知识库集成
//  符合技术设计文档的增强提示词模板和引用格式
//

import Foundation
import SwiftUI

// MARK: - AI增强服务V2（完整实现）
@MainActor
class EnhancedAIServiceV2: ObservableObject {
    @Published var isProcessing = false
    @Published var knowledgeReferences: [KnowledgeReference] = []
    @Published var responseMetadata: ResponseMetadata?
    
    private let retriever: KnowledgeRetriever
    private let openAIKey: String
    
    init(openAIKey: String) {
        self.openAIKey = openAIKey
        self.retriever = KnowledgeRetriever(openAIKey: openAIKey)
    }
    
    // MARK: - 核心方法：发送增强消息
    
    /// 发送带知识库增强的消息（完整实现）
    func sendEnhancedMessage(
        _ message: String,
        conversationHistory: [ChatMessage],
        userInfo: UserInfo? = nil,
        chartData: ChartData? = nil
    ) async -> String {
        
        isProcessing = true
        knowledgeReferences = []
        
        // 1. 检索相关知识（混合搜索）
        await retriever.hybridSearch(message, limit: 5)
        let searchResults = retriever.searchResults
        
        // 2. 获取上下文扩展（前后文）
        var enhancedResults: [EnhancedSearchResult] = []
        for result in searchResults.prefix(3) {
            let context = await retriever.getContextWindow(for: result.id)
            enhancedResults.append(EnhancedSearchResult(
                result: result,
                expandedContext: context
            ))
        }
        
        // 3. 构建增强提示词（符合技术设计文档格式）
        let enhancedPrompt = buildEnhancedPrompt(
            basePrompt: AIPersonality.systemPrompt,
            userContext: AIPersonality.getContextPrompt(userInfo: userInfo, chartData: chartData),
            knowledgeResults: enhancedResults,
            userQuestion: message
        )
        
        // 4. 调用AI服务
        let aiResponse = await callAIWithEnhancedPrompt(
            prompt: enhancedPrompt,
            message: message,
            history: conversationHistory
        )
        
        // 5. 处理引用标注
        let (processedResponse, references) = processReferences(
            response: aiResponse,
            searchResults: enhancedResults
        )
        
        // 6. 更新引用列表
        self.knowledgeReferences = references
        
        // 7. 生成最终回复（带引用）
        let finalResponse = formatFinalResponse(
            response: processedResponse,
            references: references
        )
        
        // 8. 更新元数据
        self.responseMetadata = ResponseMetadata(
            searchTime: retriever.searchStats?.searchTime ?? 0,
            resultsCount: searchResults.count,
            cacheHit: retriever.searchStats?.cacheHit ?? false,
            averageRelevance: retriever.searchStats?.averageScore ?? 0
        )
        
        isProcessing = false
        
        return finalResponse
    }
    
    // MARK: - 构建增强提示词（技术文档格式）
    
    private func buildEnhancedPrompt(
        basePrompt: String,
        userContext: String,
        knowledgeResults: [EnhancedSearchResult],
        userQuestion: String
    ) -> String {
        
        var prompt = """
        # 基础角色设定
        \(basePrompt)
        
        # 用户信息
        \(userContext)
        
        """
        
        // 添加知识库参考（技术文档指定格式）
        if !knowledgeResults.isEmpty {
            prompt += """
            # 知识库参考
            【参考资料】
            
            """
            
            for (index, result) in knowledgeResults.enumerated() {
                let num = index + 1
                let citation = result.result.citation
                let relevance = Int(result.result.score * 100)
                
                prompt += """
                来源\(num)：《\(citation)》
                相关度：\(relevance)%
                内容：\(result.result.content.prefix(500))
                
                """
                
                // 如果有扩展上下文
                if !result.expandedContext.isEmpty {
                    prompt += """
                    扩展上下文：
                    \(result.expandedContext.prefix(300))
                    
                    """
                }
            }
            
            prompt += """
            
            # 回答要求
            1. 基于参考资料提供准确回答
            2. 如引用资料请使用[1][2]等上标数字标注来源
            3. 资料不足时说明并提供一般性建议
            4. 保持紫微斗数的专业性和神秘感
            5. 回答要温暖、积极、给人希望
            
            # 引用格式示例
            根据《紫微斗数全书》记载，紫微星是北斗主星，象征帝王之尊[1]。
            在命宫时主贵，性格高傲但有领导才能[2]。
            
            """
        } else {
            prompt += """
            
            # 注意
            未找到相关知识库资料，请基于你的专业知识回答，但需说明这是一般性建议。
            
            """
        }
        
        prompt += """
        
        # 用户问题
        \(userQuestion)
        """
        
        return prompt
    }
    
    // MARK: - 调用AI服务
    
    private func callAIWithEnhancedPrompt(
        prompt: String,
        message: String,
        history: [ChatMessage]
    ) async -> String {
        
        // 这里应该调用你的后端API
        // 为了演示，使用模拟实现
        let url = URL(string: AIConfig.backendURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            ["role": "system", "content": prompt]
        ] + history.map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        } + [
            ["role": "user", "content": message]
        ]
        
        let body = [
            "messages": messages,
            "model": "gpt-4",
            "temperature": 0.8,
            "max_tokens": 1000
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // 解析响应
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                return response
            }
            
            return "抱歉，我暂时无法回答您的问题。"
            
        } catch {
            print("AI调用失败: \(error)")
            return "抱歉，服务暂时不可用。错误：\(error.localizedDescription)"
        }
    }
    
    // MARK: - 处理引用标注
    
    private func processReferences(
        response: String,
        searchResults: [EnhancedSearchResult]
    ) -> (String, [KnowledgeReference]) {
        
        var processedResponse = response
        var references: [KnowledgeReference] = []
        
        // 查找所有[数字]格式的引用
        let pattern = "\\[(\\d+)\\]"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(
            in: response,
            range: NSRange(response.startIndex..., in: response)
        )
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: response) {
                let numStr = String(response[range])
                if let num = Int(numStr), num > 0 && num <= searchResults.count {
                    let result = searchResults[num - 1]
                    
                    // 创建引用
                    let reference = KnowledgeReference(
                        number: num,
                        source: result.result.citation,
                        content: result.result.content,
                        relevance: result.result.score
                    )
                    
                    if !references.contains(where: { $0.number == num }) {
                        references.append(reference)
                    }
                }
            }
        }
        
        // 排序引用
        references.sort { $0.number < $1.number }
        
        return (processedResponse, references)
    }
    
    // MARK: - 格式化最终回复
    
    private func formatFinalResponse(
        response: String,
        references: [KnowledgeReference]
    ) -> String {
        
        var finalResponse = response
        
        // 如果有引用，添加参考资料部分
        if !references.isEmpty {
            finalResponse += "\n\n---\n📚 **参考资料**\n"
            
            for ref in references {
                finalResponse += "[\(ref.number)] \(ref.source)"
                if ref.relevance > 0.8 {
                    finalResponse += " ⭐"
                }
                finalResponse += "\n"
            }
        }
        
        return finalResponse
    }
    
    // MARK: - 特殊查询
    
    /// 直接查询知识库（不经过AI）
    func queryKnowledgeDirectly(_ query: String) async -> String {
        await retriever.hybridSearch(query, limit: 3)
        
        guard !retriever.searchResults.isEmpty else {
            return "未找到相关知识。"
        }
        
        var response = "📚 **知识库查询结果**\n\n"
        
        for (index, result) in retriever.searchResults.enumerated() {
            response += "**\(index + 1). \(result.citation)**\n"
            response += "相关度：\(Int(result.score * 100))%\n"
            response += "\(result.content.prefix(300))...\n\n"
        }
        
        return response
    }
    
    /// 获取知识推荐
    func getKnowledgeRecommendations(for chartData: ChartData?) async -> [SearchResult] {
        // 基于用户星盘推荐相关知识
        guard chartData != nil else {
            // 如果没有星盘，推荐基础知识
            await retriever.hybridSearch("紫微斗数基础", limit: 5)
            return retriever.searchResults
        }
        
        // 根据命宫主星推荐（这里需要根据实际ChartData结构调整）
        await retriever.hybridSearch("紫微星 命宫", limit: 5)
        return retriever.searchResults
    }
}

// MARK: - 辅助模型

struct EnhancedSearchResult {
    let result: SearchResult
    let expandedContext: String
}

struct KnowledgeReference: Identifiable {
    let id = UUID()
    let number: Int
    let source: String
    let content: String
    let relevance: Float
}

struct ResponseMetadata {
    let searchTime: TimeInterval
    let resultsCount: Int
    let cacheHit: Bool
    let averageRelevance: Float
    
    var summary: String {
        """
        检索耗时: \(Int(searchTime * 1000))ms
        相关结果: \(resultsCount)条
        缓存命中: \(cacheHit ? "是" : "否")
        平均相关度: \(Int(averageRelevance * 100))%
        """
    }
}

// MARK: - UI集成示例
struct ChatViewIntegration: View {
    @StateObject private var aiService: EnhancedAIServiceV2
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    
    init(openAIKey: String) {
        _aiService = StateObject(wrappedValue: EnhancedAIServiceV2(openAIKey: openAIKey))
    }
    
    var body: some View {
        VStack {
            // 消息列表
            ScrollView {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                }
            }
            
            // 知识引用卡片
            if !aiService.knowledgeReferences.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("参考资料", systemImage: "book.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(aiService.knowledgeReferences) { ref in
                        HStack {
                            Text("[\(ref.number)]")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(ref.source)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(ref.relevance * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            // 输入区域
            HStack {
                TextField("问些什么...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(aiService.isProcessing || messageText.isEmpty)
            }
            .padding()
            
            // 元数据显示（调试用）
            if let metadata = aiService.responseMetadata {
                Text(metadata.summary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }
    
    private func sendMessage() {
        let userMessage = ChatMessage(role: .user, content: messageText)
        messages.append(userMessage)
        
        let query = messageText
        messageText = ""
        
        Task {
            let response = await aiService.sendEnhancedMessage(
                query,
                conversationHistory: messages,
                userInfo: nil,
                chartData: nil
            )
            
            let assistantMessage = ChatMessage(role: .assistant, content: response)
            messages.append(assistantMessage)
        }
    }
}

// 辅助视图
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            Text(message.content)
                .padding()
                .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(15)
            
            if message.role == .assistant {
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}