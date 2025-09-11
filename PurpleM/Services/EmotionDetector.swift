//
//  EmotionDetector.swift
//  PurpleM
//
//  混合式情绪和场景检测系统
//

import Foundation

// MARK: - 检测策略枚举
enum DetectionStrategy {
    case keyword      // 纯关键词（快速）
    case llm         // 纯LLM（准确）
    case hybrid      // 混合模式（平衡）
}

// MARK: - 情绪检测器
class EmotionDetector {
    
    // MARK: - 关键词权重配置
    private struct KeywordWeight {
        let keyword: String
        let weight: Int
        let patterns: [String]? // 可选的正则表达式模式
    }
    
    // 情绪关键词库（可以从配置文件加载）
    private let emotionKeywords: [UserEmotion: [KeywordWeight]] = [
        .excited: [  // 用excited代替happy
            KeywordWeight(keyword: "开心", weight: 20, patterns: nil),
            KeywordWeight(keyword: "高兴", weight: 20, patterns: nil),
            KeywordWeight(keyword: "太好了", weight: 25, patterns: nil),
            KeywordWeight(keyword: "哈哈", weight: 15, patterns: ["哈{2,}"]),
            KeywordWeight(keyword: "😄", weight: 30, patterns: nil),
            KeywordWeight(keyword: "真棒", weight: 20, patterns: nil),
            KeywordWeight(keyword: "幸福", weight: 25, patterns: nil),
            KeywordWeight(keyword: "激动", weight: 30, patterns: nil),
            KeywordWeight(keyword: "兴奋", weight: 30, patterns: nil)
        ],
        .sad: [
            KeywordWeight(keyword: "难过", weight: 25, patterns: nil),
            KeywordWeight(keyword: "伤心", weight: 25, patterns: nil),
            KeywordWeight(keyword: "失望", weight: 20, patterns: nil),
            KeywordWeight(keyword: "😢", weight: 30, patterns: nil),
            KeywordWeight(keyword: "唉", weight: 15, patterns: ["唉{1,}"]),
            KeywordWeight(keyword: "难受", weight: 25, patterns: nil),
            KeywordWeight(keyword: "痛苦", weight: 30, patterns: nil)
        ],
        .anxious: [
            KeywordWeight(keyword: "焦虑", weight: 30, patterns: nil),
            KeywordWeight(keyword: "担心", weight: 25, patterns: nil),
            KeywordWeight(keyword: "紧张", weight: 25, patterns: nil),
            KeywordWeight(keyword: "不安", weight: 20, patterns: nil),
            KeywordWeight(keyword: "害怕", weight: 25, patterns: nil),
            KeywordWeight(keyword: "慌", weight: 20, patterns: ["好慌", "慌张"]),
            KeywordWeight(keyword: "压力", weight: 20, patterns: ["压力.{0,2}大"])
        ],
        .confused: [
            KeywordWeight(keyword: "迷茫", weight: 30, patterns: nil),
            KeywordWeight(keyword: "困惑", weight: 25, patterns: nil),
            KeywordWeight(keyword: "不知道", weight: 20, patterns: nil),
            KeywordWeight(keyword: "纠结", weight: 25, patterns: nil),
            KeywordWeight(keyword: "该怎么办", weight: 30, patterns: nil),
            KeywordWeight(keyword: "选择", weight: 15, patterns: ["不知道.*选"]),
            KeywordWeight(keyword: "犹豫", weight: 25, patterns: nil)
        ],
        .angry: [
            KeywordWeight(keyword: "生气", weight: 25, patterns: nil),
            KeywordWeight(keyword: "愤怒", weight: 30, patterns: nil),
            KeywordWeight(keyword: "讨厌", weight: 20, patterns: nil),
            KeywordWeight(keyword: "烦", weight: 20, patterns: ["好烦", "真烦"]),
            KeywordWeight(keyword: "气死", weight: 25, patterns: nil),
            KeywordWeight(keyword: "可恶", weight: 25, patterns: nil)
        ],
        .curious: [
            KeywordWeight(keyword: "为什么", weight: 25, patterns: nil),
            KeywordWeight(keyword: "是什么", weight: 25, patterns: nil),
            KeywordWeight(keyword: "怎么", weight: 20, patterns: ["怎么会", "怎么样"]),
            KeywordWeight(keyword: "请问", weight: 15, patterns: nil),
            KeywordWeight(keyword: "想知道", weight: 25, patterns: nil),
            KeywordWeight(keyword: "好奇", weight: 30, patterns: nil)
        ]
    ]
    
    // 场景关键词库
    private let sceneKeywords: [ConversationScene: [KeywordWeight]] = [
        .greeting: [
            KeywordWeight(keyword: "你好", weight: 30, patterns: nil),
            KeywordWeight(keyword: "嗨", weight: 30, patterns: nil),
            KeywordWeight(keyword: "您好", weight: 30, patterns: nil),
            KeywordWeight(keyword: "早上好", weight: 35, patterns: nil),
            KeywordWeight(keyword: "晚上好", weight: 35, patterns: nil),
            KeywordWeight(keyword: "初次见面", weight: 40, patterns: nil)
        ],
        .chartReading: [
            KeywordWeight(keyword: "命盘", weight: 35, patterns: nil),
            KeywordWeight(keyword: "主星", weight: 30, patterns: nil),
            KeywordWeight(keyword: "宫位", weight: 30, patterns: nil),
            KeywordWeight(keyword: "格局", weight: 25, patterns: nil),
            KeywordWeight(keyword: "紫微", weight: 25, patterns: ["紫微.*星"]),
            KeywordWeight(keyword: "星曜", weight: 30, patterns: nil),
            KeywordWeight(keyword: "三方四正", weight: 40, patterns: nil),
            KeywordWeight(keyword: "命宫", weight: 35, patterns: nil)
        ],
        .fortuneTelling: [
            KeywordWeight(keyword: "运势", weight: 35, patterns: nil),
            KeywordWeight(keyword: "运程", weight: 30, patterns: nil),
            KeywordWeight(keyword: "流年", weight: 35, patterns: nil),
            KeywordWeight(keyword: "大运", weight: 35, patterns: nil),
            KeywordWeight(keyword: "最近", weight: 20, patterns: ["最近.*运"]),
            KeywordWeight(keyword: "今年", weight: 25, patterns: ["今年.*运"]),
            KeywordWeight(keyword: "明年", weight: 25, patterns: nil),
            KeywordWeight(keyword: "本月", weight: 25, patterns: nil)
        ],
        .learning: [
            KeywordWeight(keyword: "什么是", weight: 30, patterns: nil),
            KeywordWeight(keyword: "如何", weight: 25, patterns: ["如何.*理解"]),
            KeywordWeight(keyword: "为什么", weight: 25, patterns: nil),
            KeywordWeight(keyword: "解释", weight: 25, patterns: nil),
            KeywordWeight(keyword: "学习", weight: 30, patterns: nil),
            KeywordWeight(keyword: "教", weight: 25, patterns: ["教.*我"]),
            KeywordWeight(keyword: "懂", weight: 20, patterns: ["看不懂", "不太懂"]),
            KeywordWeight(keyword: "意思", weight: 20, patterns: ["什么意思"])
        ],
        .counseling: [
            KeywordWeight(keyword: "建议", weight: 30, patterns: nil),
            KeywordWeight(keyword: "怎么办", weight: 35, patterns: nil),
            KeywordWeight(keyword: "选择", weight: 30, patterns: ["选择.*还是"]),
            KeywordWeight(keyword: "应该", weight: 25, patterns: ["我应该"]),
            KeywordWeight(keyword: "值得", weight: 25, patterns: ["值得.*吗"]),
            KeywordWeight(keyword: "适合", weight: 25, patterns: ["适合.*吗"]),
            KeywordWeight(keyword: "分析", weight: 25, patterns: ["帮.*分析"])
        ],
        .emergency: [
            KeywordWeight(keyword: "崩溃", weight: 40, patterns: nil),
            KeywordWeight(keyword: "受不了", weight: 35, patterns: nil),
            KeywordWeight(keyword: "绝望", weight: 40, patterns: nil),
            KeywordWeight(keyword: "想死", weight: 50, patterns: nil),
            KeywordWeight(keyword: "活不下去", weight: 45, patterns: nil),
            KeywordWeight(keyword: "救救我", weight: 45, patterns: nil),
            KeywordWeight(keyword: "坚持不下去", weight: 40, patterns: nil)
        ]
    ]
    
    // MARK: - 混合检测方法
    func detectEmotion(
        from message: String,
        strategy: DetectionStrategy = .hybrid,
        previousContext: [String] = []
    ) async -> UserEmotion {
        
        switch strategy {
        case .keyword:
            return detectEmotionByKeywords(message)
            
        case .llm:
            return await detectEmotionByLLM(message, context: previousContext)
            
        case .hybrid:
            // 先用关键词快速检测
            let keywordResult = detectEmotionByKeywords(message)
            let confidence = calculateConfidence(for: keywordResult, in: message)
            
            // 如果置信度低于阈值，使用LLM验证
            if confidence < 0.7 {
                return await detectEmotionByLLM(message, context: previousContext)
            }
            
            return keywordResult
        }
    }
    
    // MARK: - 关键词检测（本地）
    private func detectEmotionByKeywords(_ message: String) -> UserEmotion {
        var scores: [UserEmotion: Int] = [:]
        
        for (emotion, keywords) in emotionKeywords {
            var score = 0
            
            for keywordWeight in keywords {
                // 直接关键词匹配
                if message.contains(keywordWeight.keyword) {
                    score += keywordWeight.weight
                }
                
                // 正则表达式匹配
                if let patterns = keywordWeight.patterns {
                    for pattern in patterns {
                        if let regex = try? NSRegularExpression(pattern: pattern),
                           regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) != nil {
                            score += keywordWeight.weight
                        }
                    }
                }
            }
            
            scores[emotion] = score
        }
        
        // 返回得分最高的情绪，如果都是0则返回neutral
        let maxScore = scores.values.max() ?? 0
        if maxScore == 0 {
            return .neutral
        }
        
        return scores.first(where: { $0.value == maxScore })?.key ?? .neutral
    }
    
    // MARK: - LLM检测（调用AI）
    private func detectEmotionByLLM(_ message: String, context: [String]) async -> UserEmotion {
        let prompt = """
        分析以下消息的情绪状态，只返回一个词：
        happy（开心）、sad（难过）、anxious（焦虑）、confused（困惑）、excited（兴奋）、neutral（平和）
        
        历史对话：
        \(context.joined(separator: "\n"))
        
        当前消息：\(message)
        
        情绪判断（只返回一个词）：
        """
        
        // 这里调用AI服务（简化版，实际需要完整的API调用）
        // let response = await AIService.shared.quickAnalysis(prompt)
        
        // 模拟返回，实际应该解析AI响应
        return .neutral
    }
    
    // MARK: - 置信度计算
    private func calculateConfidence(for emotion: UserEmotion, in message: String) -> Double {
        var totalScore = 0
        var emotionScore = 0
        
        // 计算所有情绪的总分
        for (_, keywords) in emotionKeywords {
            for keywordWeight in keywords {
                if message.contains(keywordWeight.keyword) {
                    totalScore += keywordWeight.weight
                }
            }
        }
        
        // 计算检测到的情绪的分数
        if let keywords = emotionKeywords[emotion] {
            for keywordWeight in keywords {
                if message.contains(keywordWeight.keyword) {
                    emotionScore += keywordWeight.weight
                }
            }
        }
        
        // 计算置信度
        guard totalScore > 0 else { return 0 }
        return Double(emotionScore) / Double(totalScore)
    }
    
    // MARK: - 场景检测
    func detectScene(
        from message: String,
        strategy: DetectionStrategy = .hybrid,
        userHistory: [String] = []
    ) async -> ConversationScene {
        
        switch strategy {
        case .keyword:
            return detectSceneByKeywords(message)
            
        case .llm:
            return await detectSceneByLLM(message, history: userHistory)
            
        case .hybrid:
            let keywordResult = detectSceneByKeywords(message)
            let confidence = calculateSceneConfidence(for: keywordResult, in: message)
            
            if confidence < 0.6 {
                return await detectSceneByLLM(message, history: userHistory)
            }
            
            return keywordResult
        }
    }
    
    private func detectSceneByKeywords(_ message: String) -> ConversationScene {
        var scores: [ConversationScene: Int] = [:]
        
        for (scene, keywords) in sceneKeywords {
            var score = 0
            
            for keywordWeight in keywords {
                if message.contains(keywordWeight.keyword) {
                    score += keywordWeight.weight
                }
                
                if let patterns = keywordWeight.patterns {
                    for pattern in patterns {
                        if let regex = try? NSRegularExpression(pattern: pattern),
                           regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) != nil {
                            score += keywordWeight.weight
                        }
                    }
                }
            }
            
            scores[scene] = score
        }
        
        let maxScore = scores.values.max() ?? 0
        if maxScore == 0 {
            return .greeting
        }
        
        return scores.first(where: { $0.value == maxScore })?.key ?? .greeting
    }
    
    private func detectSceneByLLM(_ message: String, history: [String]) async -> ConversationScene {
        // LLM场景检测实现
        return .greeting
    }
    
    private func calculateSceneConfidence(for scene: ConversationScene, in message: String) -> Double {
        // 场景置信度计算
        return 0.8
    }
}

// MARK: - 检测结果包装
struct DetectionResult {
    let emotion: UserEmotion
    let emotionConfidence: Double
    let scene: ConversationScene
    let sceneConfidence: Double
    let strategy: DetectionStrategy
    let keywords: [String]  // 匹配到的关键词
    
    var needsLLMVerification: Bool {
        return emotionConfidence < 0.7 || sceneConfidence < 0.6
    }
}

// MARK: - 批量检测优化
extension EmotionDetector {
    /// 批量检测消息情绪，提高效率
    func batchDetect(messages: [String]) async -> [DetectionResult] {
        return await withTaskGroup(of: DetectionResult.self) { group in
            for message in messages {
                group.addTask {
                    let emotion = self.detectEmotionByKeywords(message)
                    let scene = self.detectSceneByKeywords(message)
                    
                    return DetectionResult(
                        emotion: emotion,
                        emotionConfidence: self.calculateConfidence(for: emotion, in: message),
                        scene: scene,
                        sceneConfidence: self.calculateSceneConfidence(for: scene, in: message),
                        strategy: .keyword,
                        keywords: self.extractMatchedKeywords(from: message)
                    )
                }
            }
            
            var results: [DetectionResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    private func extractMatchedKeywords(from message: String) -> [String] {
        var matched: [String] = []
        
        for (_, keywords) in emotionKeywords {
            for kw in keywords where message.contains(kw.keyword) {
                matched.append(kw.keyword)
            }
        }
        
        return matched
    }
}