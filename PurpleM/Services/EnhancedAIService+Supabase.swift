//
//  EnhancedAIService+Supabase.swift
//  PurpleM
//
//  EnhancedAIService的Supabase云端集成扩展
//

import Foundation
import SwiftUI

// MARK: - Supabase集成扩展
extension EnhancedAIService {
    
    // MARK: - 初始化云端数据
    func initializeFromCloud() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("用户未登录，跳过云端初始化")
            return
        }
        
        // 并行加载多个数据源
        async let preferencesTask = loadUserPreferences(userId: userId)
        async let memoryTask = loadCloudMemory(userId: userId)
        async let messagesTask = loadRecentMessages(userId: userId)
        async let quotaTask = loadUserQuota(userId: userId)
        
        // 等待所有任务完成
        await (preferencesTask, memoryTask, messagesTask, quotaTask)
        
        print("云端数据初始化完成")
    }
    
    // MARK: - 增强版发送消息（带云端同步）
    func sendMessageWithCloud(_ message: String) async -> String {
        guard let userId = AuthManager.shared.currentUser?.id else {
            // 未登录用户使用本地版本
            return await sendMessage(message)
        }
        
        // 1. 检查配额（测试模式：跳过配额检查）
        // 检查是否是超级用户 test@gmail.com
        if let email = AuthManager.shared.currentUser?.email,
           email.lowercased() == "test@gmail.com" {
            print("👑 超级用户模式 - 无限使用")
        } else {
            #if DEBUG
            // 测试模式下不限制配额
            print("🔧 测试模式：跳过配额检查")
            #else
            let quotaAvailable = await SupabaseManager.shared.checkQuotaAvailable()
            if !quotaAvailable {
                return """
                您今日的免费额度已用完 😊
            
            升级到专业版可享受：
            • 无限对话次数
            • 更快的响应速度
            • 云端记忆同步
            • 专属功能解锁
            
            点击"个人中心"了解更多
            """
            }
            #endif
        }
        
        // 2. 创建或获取会话
        let sessionId: String
        do {
            let session = try await SupabaseManager.shared.getCurrentOrCreateSession(userId: userId)
            sessionId = session.id
        } catch {
            print("创建会话失败: \(error)")
            // 降级到本地版本
            return await sendMessage(message)
        }
        
        // 3. 执行AI处理（复用现有逻辑）
        let response = await sendMessage(message)
        
        // 4. 异步保存到云端（不阻塞返回）
        Task {
            await saveConversationToCloud(
                sessionId: sessionId,
                userId: userId,
                userMessage: message,
                aiResponse: response
            )
            
            // 更新配额
            #if DEBUG
            // 测试模式：使用极小的token数
            _ = try? await SupabaseManager.shared.incrementQuotaUsage(
                userId: userId,
                tokens: 1  // 测试时只记录1个token
            )
            #else
            let estimatedTokens = estimateTokens(message: message, response: response)
            _ = try? await SupabaseManager.shared.incrementQuotaUsage(
                userId: userId,
                tokens: estimatedTokens
            )
            #endif
            
            // 同步记忆
            await syncMemoryToCloud(userId: userId)
        }
        
        return response
    }
    
    // MARK: - 加载用户偏好
    private func loadUserPreferences(userId: String) async {
        do {
            if let preferences = try await SupabaseManager.shared.getUserPreferences(userId: userId) {
                // 恢复对话风格
                if let style = preferences.conversationStyle {
                    // 可以根据风格调整AI的回复方式
                    print("加载用户对话风格: \(style)")
                }
                
                // 恢复自定义人格（记忆）
                if let customPersonality = preferences.getCustomPersonalityDict() {
                    restoreMemoryFromCloud(customPersonality)
                }
                
                // 恢复偏好话题
                if let topics = preferences.preferredTopics {
                    userMemory.preferences = topics
                }
            }
        } catch {
            print("加载用户偏好失败: \(error)")
        }
    }
    
    // MARK: - 加载云端记忆
    private func loadCloudMemory(userId: String) async {
        // 这里可以从专门的记忆表加载，暂时从preferences中加载
        // 已在loadUserPreferences中处理
    }
    
    // MARK: - 加载最近消息
    private func loadRecentMessages(userId: String) async {
        do {
            let messages = try await SupabaseManager.shared.getRecentMessages(userId: userId)
            
            // 恢复对话历史到内存
            conversationHistory.removeAll()
            
            // 添加历史消息（按时间正序）
            for message in messages.reversed() {
                conversationHistory.append((role: message.role, content: message.content))
                
                // 限制历史长度
                if conversationHistory.count > maxHistoryCount {
                    break
                }
            }
            
            print("加载了 \(messages.count) 条历史消息")
        } catch {
            print("加载历史消息失败: \(error)")
        }
    }
    
    // MARK: - 加载用户配额
    private func loadUserQuota(userId: String) async {
        do {
            let quota = try await SupabaseManager.shared.getUserQuota(userId: userId)
            if let q = quota {
                print("用户配额: \(q.dailyUsed)/\(q.dailyLimit)")
            }
        } catch {
            print("加载配额失败: \(error)")
        }
    }
    
    // MARK: - 保存对话到云端
    private func saveConversationToCloud(
        sessionId: String,
        userId: String,
        userMessage: String,
        aiResponse: String
    ) async {
        // 保存用户消息
        do {
            try await SupabaseManager.shared.saveMessage(
                sessionId: sessionId,
                userId: userId,
                role: "user",
                content: userMessage,
                metadata: [
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ]
            )
        } catch {
            print("保存用户消息失败: \(error)")
        }
        
        // 保存AI回复
        do {
            try await SupabaseManager.shared.saveMessage(
                sessionId: sessionId,
                userId: userId,
                role: "assistant",
                content: aiResponse,
                metadata: [
                    "emotion": detectedEmotion.rawValue,
                    "scene": currentScene.rawValue,
                    "suggested_questions": suggestedQuestions,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ]
            )
        } catch {
            print("保存AI回复失败: \(error)")
        }
    }
    
    // MARK: - 同步记忆到云端
    func syncMemoryToCloud(userId: String) async {
        // 准备记忆数据
        let memoryData: [String: Any] = [
            "key_events": userMemory.keyEvents.map { event in
                [
                    "date": ISO8601DateFormatter().string(from: event.date),
                    "event": event.event,
                    "importance": event.importance
                ]
            },
            "concerns": userMemory.concerns,
            "preferences": userMemory.preferences,
            "consult_history": userMemory.consultHistory.map { record in
                [
                    "date": ISO8601DateFormatter().string(from: record.date),
                    "topic": record.topic,
                    "advice": record.advice,
                    "feedback": record.feedback ?? ""
                ]
            },
            "learning_progress": userMemory.learningProgress
        ]
        
        // 创建偏好对象
        let preferences = UserAIPreferencesDB(
            id: nil,
            userId: userId,
            conversationStyle: detectConversationStyle(),
            responseLength: "medium",
            customPersonality: memoryData,
            preferredTopics: userMemory.concerns,
            enableSuggestions: true,
            createdAt: nil,
            updatedAt: nil
        )
        
        // 保存到云端
        do {
            try await SupabaseManager.shared.saveUserPreferences(
                userId: userId,
                preferences: preferences
            )
            print("记忆同步成功")
        } catch {
            print("记忆同步失败: \(error)")
            // 加入离线队列
            OfflineQueueManager.shared.enqueue(
                .syncMemory(userId: userId, data: memoryData)
            )
        }
    }
    
    // MARK: - 从云端恢复记忆
    private func restoreMemoryFromCloud(_ data: [String: Any]) {
        // 恢复关键事件
        if let events = data["key_events"] as? [[String: Any]] {
            userMemory.keyEvents = events.compactMap { eventData -> UserMemory.KeyEvent? in
                guard let dateString = eventData["date"] as? String,
                      let date = ISO8601DateFormatter().date(from: dateString),
                      let event = eventData["event"] as? String,
                      let importance = eventData["importance"] as? Int else {
                    return nil
                }
                return UserMemory.KeyEvent(date: date, event: event, importance: importance)
            }
        }
        
        // 恢复关注点
        if let concerns = data["concerns"] as? [String] {
            userMemory.concerns = concerns
        }
        
        // 恢复偏好
        if let preferences = data["preferences"] as? [String] {
            userMemory.preferences = preferences
        }
        
        // 恢复咨询历史
        if let history = data["consult_history"] as? [[String: Any]] {
            userMemory.consultHistory = history.compactMap { recordData -> UserMemory.ConsultRecord? in
                guard let dateString = recordData["date"] as? String,
                      let date = ISO8601DateFormatter().date(from: dateString),
                      let topic = recordData["topic"] as? String,
                      let advice = recordData["advice"] as? String else {
                    return nil
                }
                return UserMemory.ConsultRecord(
                    date: date,
                    topic: topic,
                    advice: advice,
                    feedback: recordData["feedback"] as? String
                )
            }
        }
        
        // 恢复学习进度
        if let progress = data["learning_progress"] as? [String: Int] {
            userMemory.learningProgress = progress
        }
        
        print("从云端恢复记忆完成")
    }
    
    // MARK: - 辅助方法
    internal func detectConversationStyle() -> String {
        // 基于最近的对话判断用户偏好的对话风格
        if conversationHistory.count > 10 {
            // 分析对话特征
            let recentMessages = conversationHistory.suffix(10)
            var formalCount = 0
            var casualCount = 0
            
            for (_, content) in recentMessages {
                if content.contains("请") || content.contains("您") {
                    formalCount += 1
                } else {
                    casualCount += 1
                }
            }
            
            if formalCount > casualCount {
                return "professional"
            } else {
                return "friendly"
            }
        }
        
        return "balanced"
    }
    
    private func estimateTokens(message: String, response: String) -> Int {
        // 简单估算：中文约1.5字符=1token，英文约4字符=1token
        let totalLength = message.count + response.count
        return totalLength / 2  // 粗略估算
    }
    
    // MARK: - 搜索知识库增强
    func searchKnowledgeBase(query: String) async -> [(citation: String, content: String)] {
        do {
            // 使用新的text_search函数搜索知识库
            let results = try await SupabaseManager.shared.searchKnowledgeWithTextSearch(query: query, limit: 5)
            
            // 提取相关知识并格式化引用
            return results.compactMap { item in
                guard let content = item["content"] as? String,
                      let chapter = item["chapter"] as? String else {
                    return nil
                }
                
                // 创建引用格式
                let citation = "《紫微斗数知识库·\(chapter)》"
                
                // 截取内容预览（保留完整内容用于上下文）
                return (citation: citation, content: content)
            }
        } catch {
            print("搜索知识库失败: \(error)")
            return []
        }
    }
}
