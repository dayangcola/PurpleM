//
//  QuickAIIntegration.swift
//  PurpleM
//
//  快速AI知识库集成 - 使用文本搜索（无需向量）
//

import Foundation
import SwiftUI
import Supabase

// MARK: - 快速知识搜索服务
@MainActor
class QuickKnowledgeService: ObservableObject {
    @Published var isSearching = false
    @Published var searchResults: [KnowledgeItem] = []
    
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: SupabaseConfig.projectURL)!,
        supabaseKey: SupabaseConfig.anonKey
    )
    
    // 知识项模型
    struct KnowledgeItem: Codable, Identifiable {
        let id: UUID
        let bookTitle: String?
        let chapter: String?
        let content: String
        let relevance: Float?
        
        var citation: String {
            if let chapter = chapter {
                return "《紫微斗数知识库·\(chapter)》"
            }
            return "《紫微斗数知识库》"
        }
        
        var preview: String {
            String(content.prefix(200))
        }
    }
    
    // MARK: - 文本搜索（立即可用）
    func searchKnowledge(_ query: String) async -> [KnowledgeItem] {
        do {
            // 调用text_search函数
            let response: [[String: Any]] = try await supabase
                .rpc("text_search", params: [
                    "query_text": query,
                    "result_limit": 5
                ])
                .execute()
                .value
            
            // 转换结果
            let items = response.compactMap { dict -> KnowledgeItem? in
                guard let id = (dict["id"] as? String).flatMap(UUID.init),
                      let content = dict["content"] as? String else {
                    return nil
                }
                
                return KnowledgeItem(
                    id: id,
                    bookTitle: dict["book_title"] as? String,
                    chapter: dict["chapter"] as? String,
                    content: content,
                    relevance: dict["relevance"] as? Float
                )
            }
            
            return items
            
        } catch {
            print("搜索失败: \(error)")
            return []
        }
    }
}

// MARK: - 增强版AI服务（快速版）
@MainActor
class QuickEnhancedAIService: ObservableObject {
    @Published var knowledgeReferences: [KnowledgeReference] = []
    @Published var isProcessing = false
    
    private let knowledgeService = QuickKnowledgeService()
    
    struct KnowledgeReference: Identifiable {
        let id = UUID()
        let number: Int
        let citation: String
        let content: String
        let relevance: Float?
    }
    
    // MARK: - 发送增强消息
    func sendEnhancedMessage(
        _ message: String,
        conversationHistory: [ChatMessage],
        userInfo: UserInfo? = nil
    ) async -> String {
        
        isProcessing = true
        
        // 1. 搜索相关知识
        let knowledgeItems = await knowledgeService.searchKnowledge(message)
        
        // 2. 构建增强提示词
        var enhancedSystemPrompt = AIPersonality.systemPrompt
        
        if !knowledgeItems.isEmpty {
            enhancedSystemPrompt += "\n\n【知识库参考】\n"
            
            for (index, item) in knowledgeItems.prefix(3).enumerated() {
                let num = index + 1
                enhancedSystemPrompt += """
                
                参考[\(num)]：\(item.citation)
                内容：\(item.preview)...
                
                """
                
                // 保存引用
                knowledgeReferences.append(KnowledgeReference(
                    number: num,
                    citation: item.citation,
                    content: item.content,
                    relevance: item.relevance
                ))
            }
            
            enhancedSystemPrompt += """
            
            【回答要求】
            1. 基于以上参考资料提供准确回答
            2. 使用[1][2][3]标注引用来源
            3. 如果参考资料不足，说明并提供你的专业建议
            """
        }
        
        // 3. 调用AI（使用你现有的后端）
        let response = await callAIBackend(
            message: message,
            systemPrompt: enhancedSystemPrompt,
            history: conversationHistory
        )
        
        // 4. 添加引用列表
        var finalResponse = response
        if !knowledgeReferences.isEmpty {
            finalResponse += "\n\n---\n📚 参考资料：\n"
            for ref in knowledgeReferences {
                finalResponse += "[\(ref.number)] \(ref.citation)\n"
            }
        }
        
        isProcessing = false
        
        return finalResponse
    }
    
    // 调用后端API
    private func callAIBackend(
        message: String,
        systemPrompt: String,
        history: [ChatMessage]
    ) async -> String {
        // 使用你现有的API配置
        let url = URL(string: AIConfig.backendURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建消息数组
        var messages = [["role": "system", "content": systemPrompt]]
        messages += history.map { ["role": $0.role.rawValue, "content": $0.content] }
        messages.append(["role": "user", "content": message])
        
        let requestBody = BackendChatRequest(
            message: message,
            conversationHistory: history.map {
                BackendChatRequest.APIMessage(
                    role: $0.role.rawValue,
                    content: $0.content
                )
            },
            userInfo: nil
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let response = try JSONDecoder().decode(BackendChatResponse.self, from: data)
            return response.response
            
        } catch {
            return "抱歉，服务暂时不可用。"
        }
    }
}

// MARK: - 简化的聊天视图集成
struct QuickChatView: View {
    @StateObject private var aiService = QuickEnhancedAIService()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    
    var body: some View {
        VStack {
            // 消息列表
            ScrollView {
                ForEach(messages) { message in
                    HStack {
                        if message.role == .user {
                            Spacer()
                        }
                        
                        Text(message.content)
                            .padding()
                            .background(
                                message.role == .user ? 
                                Color.blue : Color.gray.opacity(0.2)
                            )
                            .foregroundColor(
                                message.role == .user ? .white : .primary
                            )
                            .cornerRadius(12)
                        
                        if message.role == .assistant {
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 知识引用显示
            if !aiService.knowledgeReferences.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(aiService.knowledgeReferences) { ref in
                            VStack(alignment: .leading) {
                                Text("[\(ref.number)]")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text(ref.citation)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 输入区
            HStack {
                TextField("问点什么...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .disabled(inputText.isEmpty || aiService.isProcessing)
                
                if aiService.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
        }
    }
    
    private func sendMessage() {
        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)
        
        let query = inputText
        inputText = ""
        
        // 清空之前的引用
        aiService.knowledgeReferences = []
        
        Task {
            let response = await aiService.sendEnhancedMessage(
                query,
                conversationHistory: messages,
                userInfo: nil
            )
            
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: response
            )
            messages.append(assistantMessage)
        }
    }
}

// MARK: - 使用示例
extension QuickEnhancedAIService {
    static let usageExample = """
    // 1. 在你的ChatView中替换AIService
    @StateObject private var aiService = QuickEnhancedAIService()
    
    // 2. 发送消息时自动搜索知识库
    let response = await aiService.sendEnhancedMessage(
        "紫微星在命宫代表什么？",
        conversationHistory: messages
    )
    
    // 3. AI会自动引用知识库，如：
    // "根据《紫微斗数知识库·十四主星》记载[1]，
    //  紫微星在命宫代表尊贵、领导、权威..."
    //
    // 参考资料：
    // [1] 《紫微斗数知识库·十四主星》
    """
}