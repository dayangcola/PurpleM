//
//  SessionManager.swift
//  PurpleM
//
//  会话管理器 - 处理聊天会话的创建和管理
//

import Foundation
import SwiftUI

// MARK: - 会话管理器
@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var currentSession: ChatSessionDB?
    @Published var recentSessions: [ChatSessionDB] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {}
    
    // MARK: - 创建新会话（安全版本）
    /// 创建新的聊天会话，确保所有依赖关系正确
    func createSession(
        for scene: ConversationScene = .greeting,
        title: String? = nil
    ) async throws -> ChatSessionDB {
        
        // 1. 确保用户已登录
        guard let user = AuthManager.shared.currentUser else {
            throw SessionError.notAuthenticated
        }
        
        // 2. 确保用户Profile存在
        if UserProfileManager.shared.currentProfile == nil {
            print("⚠️ Profile不存在，尝试创建...")
            try await UserProfileManager.shared.ensureUserProfile(for: user)
        }
        
        // 3. 创建会话标题
        let sessionTitle = title ?? generateSessionTitle(for: scene)
        
        // 4. 使用正确的session_type值
        let sessionType = scene.databaseValue
        
        print("📝 创建新会话:")
        print("   用户ID: \(user.id)")
        print("   场景: \(scene.rawValue) -> \(sessionType)")
        print("   标题: \(sessionTitle)")
        
        // 5. 创建会话
        do {
            let session = try await SupabaseManager.shared.createChatSession(
                userId: user.id,
                sessionType: sessionType,
                title: sessionTitle
            )
            
            self.currentSession = session
            print("✅ 会话创建成功: \(session.id)")
            
            // 6. 刷新会话列表
            await loadRecentSessions()
            
            return session
            
        } catch {
            print("❌ 创建会话失败: \(error)")
            self.error = error.localizedDescription
            throw SessionError.creationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - 获取或创建今日会话
    func getOrCreateTodaySession() async throws -> ChatSessionDB {
        guard let user = AuthManager.shared.currentUser else {
            throw SessionError.notAuthenticated
        }
        
        // 尝试获取今天的会话
        let today = Calendar.current.startOfDay(for: Date())
        let sessions = try await loadSessionsForDate(userId: user.id, date: today)
        
        if let existingSession = sessions.first {
            self.currentSession = existingSession
            return existingSession
        }
        
        // 创建新的今日会话
        return try await createSession(
            for: .greeting,  // 使用greeting作为默认场景
            title: "日常对话 - \(formatDate(today))"
        )
    }
    
    // MARK: - 加载最近会话
    func loadRecentSessions() async {
        guard let user = AuthManager.shared.currentUser else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let endpoint = "/rest/v1/chat_sessions?user_id=eq.\(user.id)&order=created_at.desc&limit=10"
            
            let sessions = try await SupabaseManager.shared.makeRequest(
                endpoint: endpoint,
                expecting: [ChatSessionDB].self
            )
            
            self.recentSessions = sessions
            print("📚 加载了 \(sessions.count) 个最近会话")
            
        } catch {
            print("❌ 加载会话失败: \(error)")
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - 加载特定日期的会话
    private func loadSessionsForDate(userId: String, date: Date) async throws -> [ChatSessionDB] {
        let dateString = ISO8601DateFormatter().string(from: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        let nextDayString = ISO8601DateFormatter().string(from: nextDay)
        
        let endpoint = "/rest/v1/chat_sessions?user_id=eq.\(userId)&created_at=gte.\(dateString)&created_at=lt.\(nextDayString)&order=created_at.desc"
        
        return try await SupabaseManager.shared.makeRequest(
            endpoint: endpoint,
            expecting: [ChatSessionDB].self
        )
    }
    
    // MARK: - 切换会话
    func switchToSession(_ session: ChatSessionDB) {
        self.currentSession = session
        print("🔄 切换到会话: \(session.title ?? session.id)")
        
        // 通知其他组件会话已切换
        NotificationCenter.default.post(
            name: NSNotification.Name("SessionChanged"),
            object: session
        )
    }
    
    // MARK: - 删除会话
    func deleteSession(_ sessionId: String) async throws {
        guard let user = AuthManager.shared.currentUser else {
            throw SessionError.notAuthenticated
        }
        
        let endpoint = "/rest/v1/chat_sessions?id=eq.\(sessionId)&user_id=eq.\(user.id)"
        
        _ = try await SupabaseManager.shared.makeRequest(
            endpoint: endpoint,
            method: "DELETE",
            expecting: Data.self
        )
        
        // 如果删除的是当前会话，清空
        if currentSession?.id == sessionId {
            currentSession = nil
        }
        
        // 刷新列表
        await loadRecentSessions()
    }
    
    // MARK: - 生成会话标题
    private func generateSessionTitle(for scene: ConversationScene) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM月dd日 HH:mm"
        let dateString = dateFormatter.string(from: Date())
        
        switch scene {
        case .greeting:
            return "初次见面 - \(dateString)"
        case .chartReading:
            return "命盘解析 - \(dateString)"
        case .fortuneTelling:
            return "运势咨询 - \(dateString)"
        case .learning:
            return "命理学习 - \(dateString)"
        case .counseling:
            return "人生咨询 - \(dateString)"
        case .emergency:
            return "情绪支持 - \(dateString)"
        }
    }
    
    // MARK: - 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
    
    // MARK: - 清理
    func clearCurrentSession() {
        currentSession = nil
        recentSessions = []
        error = nil
    }
}

// MARK: - 会话错误
enum SessionError: LocalizedError {
    case notAuthenticated
    case creationFailed(String)
    case loadFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "请先登录"
        case .creationFailed(let reason):
            return "创建会话失败: \(reason)"
        case .loadFailed(let reason):
            return "加载会话失败: \(reason)"
        case .deleteFailed(let reason):
            return "删除会话失败: \(reason)"
        }
    }
}