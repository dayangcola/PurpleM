//
//  StreamingDetector.swift
//  PurpleM
//
//  流式响应检测器 - 始终启用流式响应
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
        // 始终使用流式响应，提供一致的用户体验
        return true
    }
    
    // MARK: - 获取流式配置
    static func getStreamingConfig() -> StreamingConfig {
        return StreamingConfig(
            enabled: true,  // 始终启用
            smartDetection: false,  // 不需要智能检测
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
        usedStreaming: Bool = true  // 默认总是使用流式
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
    }
    
    // 获取统计信息
    func getStats() -> [StreamingStat] {
        return stats
    }
}