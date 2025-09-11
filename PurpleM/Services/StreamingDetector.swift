//
//  StreamingDetector.swift
//  PurpleM
//
//  智能流式响应检测器 - 根据场景和消息内容决定是否使用流式
//

import Foundation

// MARK: - 流式检测器
struct StreamingDetector {
    
    // MARK: - 检测是否应该使用流式响应
    static func shouldUseStreaming(
        for scene: ConversationScene,
        message: String,
        settings: SettingsManager = .shared
    ) -> Bool {
        
        // 1. 首先检查用户是否启用了流式响应
        guard settings.enableStreaming else {
            return false
        }
        
        // 2. 如果启用了智能检测，进行场景判断
        if settings.smartStreamingDetection {
            return shouldStreamForScene(scene, message: message)
        }
        
        // 3. 如果没有启用智能检测，所有场景都使用流式
        return true
    }
    
    // MARK: - 场景化流式判断
    private static func shouldStreamForScene(_ scene: ConversationScene, message: String) -> Bool {
        // 场景优先级判断
        switch scene {
        case .chartReading:
            // 命盘解读 - 总是使用流式（通常回复较长）
            return true
            
        case .fortuneTelling:
            // 运势分析 - 总是使用流式（详细分析）
            return true
            
        case .learning:
            // 学习模式 - 根据问题复杂度判断
            return isComplexQuestion(message)
            
        case .counseling:
            // 深度咨询 - 通常需要详细回答
            return true
            
        case .greeting:
            // 问候 - 不需要流式（简短回复）
            return false
            
        case .emergency:
            // 紧急情况 - 快速响应，不用流式
            return false
        }
    }
    
    // MARK: - 复杂问题判断
    private static func isComplexQuestion(_ message: String) -> Bool {
        // 消息长度判断
        if message.count > 50 {
            return true  // 长问题可能需要详细回答
        }
        
        // 关键词判断 - 这些关键词通常需要详细解释
        let streamKeywords = [
            "详细", "解释", "分析", "告诉我",
            "为什么", "如何", "怎么样", "什么是",
            "帮我看看", "解读", "含义", "意思"
        ]
        
        for keyword in streamKeywords {
            if message.contains(keyword) {
                return true
            }
        }
        
        // 简单问题关键词 - 这些不需要流式
        let simpleKeywords = [
            "是不是", "对吗", "好吗", "可以吗",
            "什么时候", "多少", "几个", "哪个"
        ]
        
        for keyword in simpleKeywords {
            if message.contains(keyword) {
                return false
            }
        }
        
        return false
    }
    
    // MARK: - 获取流式配置
    static func getStreamingConfig() -> StreamingConfig {
        return StreamingConfig(
            enabled: SettingsManager.shared.enableStreaming,
            smartDetection: SettingsManager.shared.smartStreamingDetection,
            typingSpeed: getOptimalTypingSpeed(),
            bufferSize: 10  // 每次缓存10个字符后更新UI
        )
    }
    
    // MARK: - 根据设备性能调整打字速度
    private static func getOptimalTypingSpeed() -> Double {
        // 返回每秒字符数
        #if targetEnvironment(simulator)
        return 60.0  // 模拟器上更快
        #else
        // 真机根据性能调整
        let processorCount = ProcessInfo.processInfo.processorCount
        if processorCount >= 6 {
            return 50.0  // 高性能设备
        } else {
            return 30.0  // 普通设备
        }
        #endif
    }
}

// MARK: - 流式配置
struct StreamingConfig {
    let enabled: Bool
    let smartDetection: Bool
    let typingSpeed: Double  // 字符/秒
    let bufferSize: Int      // 缓存大小
    
    var delayPerCharacter: TimeInterval {
        return 1.0 / typingSpeed
    }
}

// MARK: - 流式统计（用于优化）
class StreamingAnalytics {
    static let shared = StreamingAnalytics()
    
    private var stats: [StreamingStat] = []
    
    struct StreamingStat {
        let scene: ConversationScene
        let messageLength: Int
        let responseLength: Int
        let usedStreaming: Bool
        let userSatisfied: Bool?  // 可以通过用户反馈获取
        let timestamp: Date
    }
    
    // 记录流式使用情况
    func recordUsage(
        scene: ConversationScene,
        messageLength: Int,
        responseLength: Int,
        usedStreaming: Bool
    ) {
        let stat = StreamingStat(
            scene: scene,
            messageLength: messageLength,
            responseLength: responseLength,
            usedStreaming: usedStreaming,
            userSatisfied: nil,
            timestamp: Date()
        )
        
        stats.append(stat)
        
        // 保留最近100条记录
        if stats.count > 100 {
            stats.removeFirst()
        }
        
        // 分析并优化
        analyzeAndOptimize()
    }
    
    // 分析使用模式并优化
    private func analyzeAndOptimize() {
        // 统计各场景的平均响应长度
        let sceneStats = Dictionary(grouping: stats, by: { $0.scene })
        
        for (scene, sceneData) in sceneStats {
            let avgResponseLength = sceneData.reduce(0) { $0 + $1.responseLength } / sceneData.count
            
            // 如果某个场景的平均响应长度很短，可以建议关闭流式
            if avgResponseLength < 100 {
                print("📊 场景 \(scene) 平均响应长度较短(\(avgResponseLength)字)，建议关闭流式")
            }
        }
    }
    
    // 获取场景推荐
    func getRecommendation(for scene: ConversationScene) -> Bool {
        let sceneData = stats.filter { $0.scene == scene }
        guard !sceneData.isEmpty else { return true }  // 默认推荐使用
        
        let avgLength = sceneData.reduce(0) { $0 + $1.responseLength } / sceneData.count
        return avgLength > 150  // 平均长度超过150字推荐使用流式
    }
}