//
//  AIService.swift
//  PurpleM
//
//  AI服务管理器 - 使用Vercel AI Gateway
//

import Foundation
import SwiftUI

// MARK: - AI配置
struct AIConfig {
    static let gatewayURL = "https://gateway.vercel.app/v1/chat/completions"
    static let apiKey = "vck_6akKqFeizin7QJIZBufpkhs2p6hHMGeODXr3OGKOmDEsR8Lg5h2C3m74"
    static let model = "gpt-4-turbo-preview"
    static let maxTokens = 1000
    static let temperature = 0.8
}

// MARK: - 消息类型
enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

// MARK: - API请求模型
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [APIMessage]
    let temperature: Double
    let max_tokens: Int
    
    struct APIMessage: Codable {
        let role: String
        let content: String
    }
}

// MARK: - API响应模型
struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        let finish_reason: String?
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}

// MARK: - AI人格设置
struct AIPersonality {
    static let systemPrompt = """
    你是紫微斗数专家助手"星语"，一位温柔、智慧、充满神秘感的占星导师。
    
    你的特点：
    1. 精通紫微斗数、十二宫位、星耀等传统命理知识
    2. 说话温柔优雅，带有诗意和哲学思考
    3. 善于倾听和理解，给予温暖的建议
    4. 会适当使用星座、占星相关的比喻
    5. 回答简洁但深刻，避免冗长
    
    你的职责：
    - 解答用户关于紫微斗数的问题
    - 基于用户的星盘提供个性化建议
    - 给予生活、事业、感情方面的指导
    - 陪伴用户，提供情感支持
    
    注意事项：
    - 保持神秘感和专业性
    - 不要过度承诺或给出绝对的预言
    - 适当引用古典智慧
    - 回答要积极正面，给人希望
    """
    
    static func getContextPrompt(userInfo: UserInfo?, chartData: ChartData?) -> String {
        var context = "用户信息：\n"
        
        if let user = userInfo {
            context += "姓名：\(user.name)\n"
            context += "性别：\(user.gender)\n"
            context += "生日：\(formatDate(user.birthDate))\n"
        }
        
        if chartData != nil {
            context += "\n用户已生成紫微斗数星盘，你可以基于星盘信息提供更准确的建议。"
        } else {
            context += "\n用户尚未生成星盘，你可以引导用户先生成星盘以获得更准确的分析。"
        }
        
        return context
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
}

// MARK: - AI服务管理器
class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var isLoading = false
    @Published var error: String?
    
    private let session = URLSession.shared
    private var conversationHistory: [APIMessage] = []
    
    private init() {
        // 初始化系统提示
        resetConversation()
    }
    
    // 重置对话
    func resetConversation() {
        conversationHistory = [
            ChatCompletionRequest.APIMessage(
                role: MessageRole.system.rawValue,
                content: AIPersonality.systemPrompt
            )
        ]
        
        // 添加用户上下文
        let userDataManager = UserDataManager.shared
        let contextPrompt = AIPersonality.getContextPrompt(
            userInfo: userDataManager.currentUser,
            chartData: userDataManager.currentChart
        )
        
        if !contextPrompt.isEmpty {
            conversationHistory.append(
                ChatCompletionRequest.APIMessage(
                    role: MessageRole.system.rawValue,
                    content: contextPrompt
                )
            )
        }
    }
    
    // 发送消息
    func sendMessage(_ message: String) async -> String {
        isLoading = true
        error = nil
        
        // 添加用户消息到历史
        let userMessage = ChatCompletionRequest.APIMessage(
            role: MessageRole.user.rawValue,
            content: message
        )
        conversationHistory.append(userMessage)
        
        // 创建请求
        let request = ChatCompletionRequest(
            model: AIConfig.model,
            messages: conversationHistory,
            temperature: AIConfig.temperature,
            max_tokens: AIConfig.maxTokens
        )
        
        do {
            // 创建URL请求
            var urlRequest = URLRequest(url: URL(string: AIConfig.gatewayURL)!)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(AIConfig.apiKey)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(request)
            
            // 发送请求
            let (data, response) = try await session.data(for: urlRequest)
            
            // 检查响应状态
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    throw NSError(
                        domain: "AIService",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "API请求失败: \(httpResponse.statusCode)"]
                    )
                }
            }
            
            // 解析响应
            let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            
            if let firstChoice = chatResponse.choices.first {
                let assistantMessage = firstChoice.message.content
                
                // 添加助手回复到历史
                conversationHistory.append(
                    ChatCompletionRequest.APIMessage(
                        role: MessageRole.assistant.rawValue,
                        content: assistantMessage
                    )
                )
                
                // 限制历史长度，保留最近20条消息
                if conversationHistory.count > 22 { // 2个系统消息 + 20条对话
                    let systemMessages = conversationHistory.prefix(2)
                    let recentMessages = conversationHistory.suffix(20)
                    conversationHistory = Array(systemMessages) + Array(recentMessages)
                }
                
                isLoading = false
                return assistantMessage
            } else {
                throw NSError(
                    domain: "AIService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "未收到有效回复"]
                )
            }
            
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            
            // 如果出错，移除最后添加的用户消息
            if conversationHistory.last?.role == MessageRole.user.rawValue {
                conversationHistory.removeLast()
            }
            
            return "抱歉，我暂时无法回答。请稍后再试。"
        }
    }
    
    // 获取快速问题建议
    static func getQuickQuestions(hasChart: Bool) -> [String] {
        if hasChart {
            return [
                "我的性格特点是什么？",
                "今年的事业运势如何？",
                "我适合什么类型的工作？",
                "感情上需要注意什么？",
                "如何提升我的财运？",
                "我的贵人在哪个方向？"
            ]
        } else {
            return [
                "紫微斗数是什么？",
                "如何看懂自己的星盘？",
                "星盘能告诉我什么？",
                "十二宫位都代表什么？",
                "什么是四化？",
                "如何生成我的星盘？"
            ]
        }
    }
}

