//
//  DiagnosticReport.swift
//  PurpleM
//
//  深度诊断报告 - 检查所有潜在问题
//

import Foundation

// MARK: - 问题诊断报告

/*
 ==========================================
 🔍 深度诊断分析报告
 ==========================================
 
 ## 1. 🔴 关键问题（需要立即修复）
 
 ### 问题 1.1: 会话创建的外键依赖链
 - 现象：创建chat_messages时报错 "Key is not present in table chat_sessions"
 - 原因：sessionId不存在或无效
 - 当前代码位置：
   * EnhancedAIService+Supabase.swift:70 - getCurrentOrCreateSession
   * OfflineQueueManager.swift:333 - saveMessage操作
 
 - 修复方案：
 */

// 修复1: 确保会话存在后再保存消息
extension SupabaseManager {
    func saveMessageSafe(
        sessionId: String,
        userId: String,
        role: String,
        content: String,
        metadata: [String: String]? = nil
    ) async throws {
        // 先验证会话存在
        let sessionExists = try await verifySessionExists(sessionId: sessionId, userId: userId)
        
        if !sessionExists {
            print("⚠️ 会话不存在，尝试创建新会话...")
            let newSession = try await SessionManager.shared.createSession()
            return try await saveMessage(
                sessionId: newSession.id,
                userId: userId,
                role: role,
                content: content,
                metadata: metadata
            )
        }
        
        // 会话存在，直接保存
        try await saveMessage(
            sessionId: sessionId,
            userId: userId,
            role: role,
            content: content,
            metadata: metadata
        )
    }
    
    private func verifySessionExists(sessionId: String, userId: String) async throws -> Bool {
        let endpoint = "/rest/v1/chat_sessions?id=eq.\(sessionId)&user_id=eq.\(userId)"
        let sessions = try await makeRequest(
            endpoint: endpoint,
            expecting: [ChatSessionDB].self
        )
        return !sessions.isEmpty
    }
}

/*
 ### 问题 1.2: User Profile创建时机
 - 现象：用户登录后立即操作可能失败
 - 原因：Profile创建是异步的，可能还未完成
 - 当前代码位置：AuthManager.swift:140-148
 
 - 修复方案：
 */

// 修复2: 同步等待Profile创建
extension AuthManager {
    func signInWithProfileSync(email: String, password: String) async throws -> User {
        // 执行登录
        let user = try await performSignIn(email: email, password: password)
        
        // 同步等待Profile创建
        try await UserProfileManager.shared.ensureUserProfile(for: user)
        
        // 更新状态
        await MainActor.run {
            self.currentUser = user
            self.authState = .authenticated(user)
        }
        
        return user
    }
    
    private func performSignIn(email: String, password: String) async throws -> User {
        // 原有登录逻辑...
        fatalError("实现原有登录逻辑")
    }
}

/*
 ## 2. 🟡 中等问题（影响体验）
 
 ### 问题 2.1: 离线队列重试策略
 - 现象：失败的操作会不断重试，即使是永久性错误
 - 原因：没有区分临时错误和永久错误
 - 修复方案：
 */

enum OperationError {
    case temporary(Error)   // 网络错误、超时等
    case permanent(Error)   // 外键约束、数据格式错误等
    
    static func categorize(_ error: Error) -> OperationError {
        if let supabaseError = error as? APIError {
            switch supabaseError {
            case .serverError(let code):
                // 4xx错误通常是永久性的
                if code >= 400 && code < 500 {
                    return .permanent(error)
                }
                // 5xx错误是临时的
                return .temporary(error)
            case .networkError:
                return .temporary(error)
            default:
                return .permanent(error)
            }
        }
        return .temporary(error)
    }
}

/*
 ### 问题 2.2: 数据同步冲突
 - 现象：本地数据和云端数据可能不一致
 - 原因：没有冲突解决策略
 - 修复方案：
 */

struct ConflictResolution {
    enum Strategy {
        case localWins      // 本地数据优先
        case remoteWins     // 云端数据优先
        case merge          // 合并数据
        case askUser        // 询问用户
    }
    
    static func resolve<T>(
        local: T,
        remote: T,
        strategy: Strategy = .remoteWins
    ) -> T {
        switch strategy {
        case .localWins:
            return local
        case .remoteWins:
            return remote
        case .merge:
            // 实现合并逻辑
            return remote
        case .askUser:
            // 显示UI让用户选择
            return remote
        }
    }
}

/*
 ## 3. 🟢 优化建议（提升性能）
 
 ### 建议 3.1: 批量操作优化
 */

extension SupabaseManager {
    func batchSaveMessages(_ messages: [(sessionId: String, userId: String, content: String)]) async throws {
        // 批量插入而非逐条插入
        let batchData = messages.map { msg in
            [
                "id": UUID().uuidString,
                "session_id": msg.sessionId,
                "user_id": msg.userId,
                "content": msg.content,
                "created_at": ISO8601DateFormatter().string(from: Date())
            ]
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: batchData)
        _ = try await makeRequest(
            endpoint: "/rest/v1/chat_messages",
            method: "POST",
            body: jsonData,
            expecting: Data.self
        )
    }
}

/*
 ### 建议 3.2: 缓存策略
 */

class DataCache {
    static let shared = DataCache()
    
    private var sessionCache: [String: ChatSessionDB] = [:]
    private var profileCache: [String: UserProfile] = [:]
    private let cacheExpiry: TimeInterval = 300 // 5分钟
    
    func getCachedSession(id: String) -> ChatSessionDB? {
        return sessionCache[id]
    }
    
    func cacheSession(_ session: ChatSessionDB) {
        sessionCache[session.id] = session
        
        // 定时清理
        DispatchQueue.main.asyncAfter(deadline: .now() + cacheExpiry) {
            self.sessionCache.removeValue(forKey: session.id)
        }
    }
}

/*
 ## 4. 🔵 架构改进建议
 
 ### 建议 4.1: 使用Repository模式
 */

protocol SessionRepository {
    func create(userId: String, type: String) async throws -> ChatSessionDB
    func get(id: String) async throws -> ChatSessionDB?
    func list(userId: String) async throws -> [ChatSessionDB]
    func delete(id: String) async throws
}

class SupabaseSessionRepository: SessionRepository {
    func create(userId: String, type: String) async throws -> ChatSessionDB {
        // 实现...
        fatalError("实现创建逻辑")
    }
    
    func get(id: String) async throws -> ChatSessionDB? {
        // 实现...
        fatalError("实现获取逻辑")
    }
    
    func list(userId: String) async throws -> [ChatSessionDB] {
        // 实现...
        fatalError("实现列表逻辑")
    }
    
    func delete(id: String) async throws {
        // 实现...
        fatalError("实现删除逻辑")
    }
}

/*
 ### 建议 4.2: 使用Combine进行响应式编程
 */

import Combine

class ReactiveDataManager {
    @Published var sessions: [ChatSessionDB] = []
    @Published var messages: [ChatMessageDB] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    func observeChanges() {
        // 监听数据变化
        NotificationCenter.default.publisher(for: NSNotification.Name("DataChanged"))
            .sink { _ in
                Task {
                    await self.refreshData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func refreshData() async {
        // 刷新数据...
    }
}

/*
 ==========================================
 📊 问题优先级排序
 ==========================================
 
 1. 🔴 修复会话创建的外键依赖 (紧急)
 2. 🔴 确保Profile同步创建 (紧急)
 3. 🟡 改进离线队列重试策略 (重要)
 4. 🟡 实现数据冲突解决 (重要)
 5. 🟢 批量操作优化 (建议)
 6. 🟢 添加缓存层 (建议)
 7. 🔵 架构重构 (长期)
 
 ==========================================
 🎯 下一步行动计划
 ==========================================
 
 1. 立即修复：
    - saveMessageSafe方法
    - signInWithProfileSync方法
 
 2. 本周完成：
    - 错误分类系统
    - 冲突解决策略
 
 3. 下个版本：
    - 批量操作API
    - 缓存系统
 
 4. 长期规划：
    - Repository模式重构
    - 响应式架构升级
 */