//
//  EnhancedAIService.swift
//  PurpleM
//
//  增强版AI命理导师服务
//

import Foundation
import SwiftUI

// MARK: - 对话场景枚举
enum ConversationScene: String {
    case greeting = "问候"
    case chartReading = "解盘"
    case fortuneTelling = "运势"
    case learning = "学习"
    case counseling = "咨询"
    case emergency = "情绪支持"
    
    var systemPrompt: String {
        switch self {
        case .greeting:
            return "你正在与用户初次见面，请温暖友好地介绍自己，并主动引导用户探索命盘。"
        case .chartReading:
            return "你正在为用户解读命盘，请专业详细地分析星耀、宫位、格局，给出深刻见解。"
        case .fortuneTelling:
            return "你正在预测运势，请结合大运、流年、流月给出具体的时间节点和建议。"
        case .learning:
            return "你正在教授命理知识，请循序渐进，用通俗易懂的语言解释专业概念。"
        case .counseling:
            return "你正在提供人生咨询，请共情理解，结合命理给出智慧的建议。"
        case .emergency:
            return "用户可能处于情绪低谷，请首先给予情感支持，然后温柔地引导。"
        }
    }
}

// MARK: - 用户情绪枚举
enum UserEmotion: String {
    case anxious = "焦虑"
    case confused = "迷茫"
    case excited = "兴奋"
    case sad = "悲伤"
    case angry = "愤怒"
    case curious = "好奇"
    case neutral = "平静"
    
    var responsePrefix: String {
        switch self {
        case .anxious:
            return "我感受到您内心的不安。深呼吸，让我们一起看看星盘带来的指引..."
        case .confused:
            return "人生的十字路口确实令人迷茫。您的命盘中蕴含着答案..."
        case .excited:
            return "您的喜悦感染了我！让我们看看这份好运会持续多久..."
        case .sad:
            return "我理解您的心情。有时候，了解命运的安排能带来一些慰藉..."
        case .angry:
            return "情绪是能量的流动。让我们看看如何转化这股力量..."
        case .curious:
            return "好奇心是智慧的开始！让我为您揭开命理的奥秘..."
        case .neutral:
            return "很高兴与您交流。让我们开始今天的命理探索..."
        }
    }
}

// MARK: - 用户记忆系统
struct UserMemory: Codable {
    let userId: String
    var keyEvents: [KeyEvent] = []
    var concerns: [String] = []
    var preferences: [String] = []
    var consultHistory: [ConsultRecord] = []
    var learningProgress: [String: Int] = [:]
    
    struct KeyEvent: Codable {
        let date: Date
        let event: String
        let importance: Int // 1-5
    }
    
    struct ConsultRecord: Codable {
        let date: Date
        let topic: String
        let advice: String
        let feedback: String?
    }
    
    mutating func remember(event: String, importance: Int = 3) {
        keyEvents.append(KeyEvent(date: Date(), event: event, importance: importance))
        // 只保留最近20个重要事件
        if keyEvents.count > 20 {
            keyEvents = Array(keyEvents.suffix(20))
        }
    }
    
    mutating func addConcern(_ concern: String) {
        concerns.append(concern)
        // 只保留最近10个关注点
        if concerns.count > 10 {
            concerns = Array(concerns.suffix(10))
        }
    }
    
    func getRecentContext() -> String {
        var context = ""
        
        if let lastEvent = keyEvents.last {
            context += "最近事件：\(lastEvent.event)\n"
        }
        
        if let lastConcern = concerns.last {
            context += "主要关注：\(lastConcern)\n"
        }
        
        if let lastConsult = consultHistory.last {
            context += "上次咨询：\(lastConsult.topic)\n"
        }
        
        return context
    }
}

// MARK: - 命盘上下文提取器
struct ChartContextExtractor {
    
    static func extract(from message: String, chart: ChartData?) -> String {
        guard let chart = chart else {
            return "用户尚未生成命盘，建议先创建命盘以获得个性化指导。"
        }
        
        var context = "【命盘关键信息】\n"
        
        // 提取相关宫位
        let palaceKeywords = [
            "事业": "官禄宫",
            "工作": "官禄宫",
            "感情": "夫妻宫",
            "爱情": "夫妻宫",
            "财运": "财帛宫",
            "金钱": "财帛宫",
            "健康": "疾厄宫",
            "家庭": "田宅宫",
            "父母": "父母宫",
            "子女": "子女宫",
            "朋友": "交友宫",
            "学习": "官禄宫"
        ]
        
        for (keyword, palaceName) in palaceKeywords {
            if message.contains(keyword) {
                // 这里需要从chart中提取具体宫位信息
                context += "相关宫位：\(palaceName)\n"
            }
        }
        
        // 添加当前运势
        context += "当前大运：\(chart.currentDecadal ?? "未知")\n"
        context += "当前流年：\(chart.currentYear ?? "未知")\n"
        
        return context
    }
}

// MARK: - 增强版AI服务
@MainActor
class EnhancedAIService: NSObject, ObservableObject {
    static let shared = EnhancedAIService()
    
    @Published var currentScene: ConversationScene = .greeting
    @Published var detectedEmotion: UserEmotion = .neutral
    @Published var isLoading = false
    @Published var suggestedQuestions: [String] = []
    
    internal var userMemory: UserMemory
    internal var conversationHistory: [(role: String, content: String)] = []
    internal let maxHistoryCount = 20
    
    // MARK: - 新增：情绪检测器实例
    private let emotionDetector = EmotionDetector()
    private let promptBuilder = PromptBuilder()
    
    override private init() {
        // 加载或创建用户记忆
        if let savedMemory = UserDefaults.standard.data(forKey: "userMemory"),
           let memory = try? JSONDecoder().decode(UserMemory.self, from: savedMemory) {
            self.userMemory = memory
        } else {
            self.userMemory = UserMemory(userId: UUID().uuidString)
        }
        
        super.init()
        
        // 初始化对话
        resetConversation()
        updateSuggestedQuestions()
    }
    
    // MARK: - 核心对话方法
    func sendMessage(_ message: String) async -> String {
        isLoading = true
        defer { isLoading = false }
        
        // 1. 使用新的混合检测器检测情绪（优先使用关键词，置信度低时使用LLM）
        detectedEmotion = await emotionDetector.detectEmotion(
            from: message,
            strategy: .hybrid,
            previousContext: conversationHistory.suffix(3).map { $0.content }
        )
        
        // 2. 使用新的混合检测器检测场景
        currentScene = await emotionDetector.detectScene(
            from: message,
            strategy: .hybrid,
            userHistory: conversationHistory.suffix(5).map { $0.content }
        )
        
        // 3. 提取命盘上下文
        let chartContext = ChartContextExtractor.extract(
            from: message,
            chart: UserDataManager.shared.currentChart
        )
        
        // 3.5 搜索知识库（新增）
        let knowledgeReferences = await searchKnowledgeBase(query: message)
        
        // 4. 构建增强型Prompt（包含知识库引用）
        let enhancedPrompt = buildEnhancedPrompt(
            message: message,
            emotion: detectedEmotion,
            scene: currentScene,
            chartContext: chartContext,
            knowledgeRefs: knowledgeReferences
        )
        
        // 5. 调用AI（这里调用现有的AIService）
        let response = await AIService.shared.sendMessage(enhancedPrompt)
        
        // 6. 更新记忆
        updateMemory(message: message, response: response)
        
        // 7. 更新建议问题
        updateSuggestedQuestions()
        
        // 8. 添加主动提醒
        let reminders = generateProactiveReminders()
        var finalResponse = response
        if !reminders.isEmpty {
            finalResponse += "\n\n💫 **温馨提醒**\n" + reminders.joined(separator: "\n")
        }
        
        // 9. 添加知识库引用列表（如果有）
        if !knowledgeReferences.isEmpty {
            finalResponse += "\n\n---\n📚 **参考资料**\n"
            for (index, ref) in knowledgeReferences.enumerated() {
                let num = index + 1
                finalResponse += "[\(num)] \(ref.citation)\n"
            }
        }
        
        return finalResponse
    }
    
    // MARK: - 情绪和场景检测已迁移到 EmotionDetector.swift
    // 使用更强大的混合检测策略（关键词 + LLM）
    // 详见 emotionDetector.detectEmotion() 和 emotionDetector.detectScene()
    
    // MARK: - 构建增强型Prompt
    private func buildEnhancedPrompt(
        message: String,
        emotion: UserEmotion,
        scene: ConversationScene,
        chartContext: String,
        knowledgeRefs: [(citation: String, content: String)] = []
    ) -> String {
        
        // 使用新的 PromptBuilder 构建基础提示词
        let basePrompt = promptBuilder.buildSystemPrompt(
            scene: scene,
            emotion: emotion,
            memory: userMemory
        )
        
        // 构建知识库参考部分
        var knowledgeSection = ""
        if !knowledgeRefs.isEmpty {
            knowledgeSection = """
            
            # 知识库参考
            """
            for (index, ref) in knowledgeRefs.enumerated() {
                let num = index + 1
                let preview = String(ref.content.prefix(300))
                knowledgeSection += """
                
                参考[\(num)]：\(ref.citation)
                内容：\(preview)...
                """
            }
            
            knowledgeSection += """
            
            
            【回答要求】
            1. 基于以上参考资料提供准确回答
            2. 使用[1][2][3]标注引用来源
            3. 如果参考资料不足，说明并提供你的专业建议
            """
        }
        
        // 添加命盘上下文和当前消息
        let enhancedPrompt = """
        \(basePrompt)
        \(knowledgeSection)
        
        # 命盘信息
        \(chartContext)
        
        # 当前对话
        用户消息：\(message)
        
        请以星语导师的身份，基于以上信息提供专业而温暖的回复。
        """
        
        return enhancedPrompt
    }
    
    // MARK: - 更新记忆
    private func updateMemory(message: String, response: String) {
        // 提取关键信息
        if message.count > 20 {
            userMemory.addConcern(message)
        }
        
        // 保存记忆
        if let encoded = try? JSONEncoder().encode(userMemory) {
            UserDefaults.standard.set(encoded, forKey: "userMemory")
        }
        
        // 更新对话历史
        conversationHistory.append((role: "user", content: message))
        conversationHistory.append((role: "assistant", content: response))
        
        // 限制历史长度
        if conversationHistory.count > maxHistoryCount {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryCount))
        }
    }
    
    // MARK: - 更新建议问题
    private func updateSuggestedQuestions() {
        switch currentScene {
        case .greeting:
            suggestedQuestions = [
                "我的性格特点是什么？",
                "今年运势如何？",
                "我适合什么工作？"
            ]
        case .chartReading:
            suggestedQuestions = [
                "我的命宫代表什么？",
                "我有什么特殊格局吗？",
                "我的贵人在哪里？"
            ]
        case .fortuneTelling:
            suggestedQuestions = [
                "本月财运如何？",
                "什么时候会遇到真爱？",
                "今年事业有突破吗？"
            ]
        case .learning:
            suggestedQuestions = [
                "什么是四化？",
                "如何看大运？",
                "紫微星代表什么？"
            ]
        case .counseling:
            suggestedQuestions = [
                "我该换工作吗？",
                "这段感情值得坚持吗？",
                "如何改善财运？"
            ]
        case .emergency:
            suggestedQuestions = [
                "有人理解我吗？",
                "事情会好转吗？",
                "我该如何面对？"
            ]
        }
    }
    
    // MARK: - 生成主动提醒
    private func generateProactiveReminders() -> [String] {
        var reminders: [String] = []
        
        // 基于当前日期和命盘生成提醒
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        
        // 示例提醒逻辑
        if weekday == 3 { // 周三
            reminders.append("• 今天是您的财运日，适合谈判和投资决策")
        }
        
        // 检查是否接近大运交替
        if UserDataManager.shared.currentChart != nil {
            // 这里需要实际的大运计算逻辑
            // reminders.append("• 您即将进入新的大运周期，建议提前规划")
        }
        
        return reminders
    }
    
    // MARK: - 重置对话
    func resetConversation() {
        conversationHistory = []
        currentScene = .greeting
        detectedEmotion = .neutral
        updateSuggestedQuestions()
    }
}

// MARK: - 扩展ChartData
extension ChartData {
    var currentDecadal: String? {
        // TODO: 实现获取当前大运的逻辑
        return "25-34岁大运"
    }
    
    var currentYear: String? {
        // TODO: 实现获取当前流年的逻辑
        return "甲辰年"
    }
}