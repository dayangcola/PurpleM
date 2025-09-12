//
//  SafeDataManager.swift
//  PurpleM
//
//  安全的数据管理器 - 修复关键问题
//

import Foundation

// MARK: - 安全数据管理器
@MainActor
class SafeDataManager {
    static let shared = SafeDataManager()
    
    private init() {}
    
    // MARK: - 安全保存消息（验证会话存在）
    func saveMessageSafely(
        sessionId: String,
        userId: String,
        role: String,
        content: String,
        metadata: [String: String]? = nil
    ) async throws {
        print("🔒 安全保存消息...")
        
        // 1. 验证用户已登录
        guard let currentUser = AuthManager.shared.currentUser else {
            throw DataError.notAuthenticated
        }
        
        // 2. 验证userId匹配
        guard currentUser.id == userId else {
            throw DataError.userMismatch
        }
        
        // 3. 验证会话存在
        let sessionValid = await verifySession(sessionId: sessionId, userId: userId)
        
        if !sessionValid {
            print("⚠️ 会话无效，创建新会话...")
            // 创建新会话
            let newSession = try await SessionManager.shared.getOrCreateTodaySession()
            
            // 使用新会话ID保存消息
            try await SupabaseManager.shared.saveMessage(
                sessionId: newSession.id,
                userId: userId,
                role: role,
                content: content,
                metadata: metadata
            )
            
            print("✅ 消息已保存到新会话: \(newSession.id)")
        } else {
            // 直接保存到现有会话
            try await SupabaseManager.shared.saveMessage(
                sessionId: sessionId,
                userId: userId,
                role: role,
                content: content,
                metadata: metadata
            )
            
            print("✅ 消息已保存到会话: \(sessionId)")
        }
    }
    
    // MARK: - 验证会话存在
    private func verifySession(sessionId: String, userId: String) async -> Bool {
        do {
            let endpoint = "/rest/v1/chat_sessions?id=eq.\(sessionId)&user_id=eq.\(userId)"
            let sessions = try await SupabaseManager.shared.makeRequest(
                endpoint: endpoint,
                expecting: [ChatSessionDB].self
            )
            
            return !sessions.isEmpty
        } catch {
            print("❌ 验证会话失败: \(error)")
            return false
        }
    }
    
    // MARK: - 智能重试策略
    func shouldRetryOperation(error: Error, retryCount: Int) -> Bool {
        // 分析错误类型
        let errorType = categorizeError(error)
        
        switch errorType {
        case .permanent:
            print("🚫 永久性错误，不重试")
            return false
            
        case .temporary:
            let shouldRetry = retryCount < 3
            print("🔄 临时性错误，\(shouldRetry ? "重试" : "放弃")")
            return shouldRetry
            
        case .unknown:
            let shouldRetry = retryCount < 1
            print("❓ 未知错误，\(shouldRetry ? "尝试一次" : "放弃")")
            return shouldRetry
        }
    }
    
    // MARK: - 错误分类
    private func categorizeError(_ error: Error) -> ErrorCategory {
        // 检查是否是API错误
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let code):
                // 4xx错误是客户端错误，通常是永久的
                if code >= 400 && code < 500 {
                    // 特殊情况：401/403可能是token过期，可以重试
                    if code == 401 || code == 403 {
                        return .temporary
                    }
                    return .permanent
                }
                // 5xx错误是服务器错误，通常是临时的
                if code >= 500 {
                    return .temporary
                }
                return .unknown
                
            case .networkError:
                // 网络错误是临时的
                return .temporary
                
            case .decodingError:
                // 解码错误是永久的
                return .permanent
                
            default:
                return .unknown
            }
        }
        
        // 检查错误描述中的关键词
        let errorString = error.localizedDescription.lowercased()
        
        // 外键约束错误 - 永久
        if errorString.contains("foreign key") || 
           errorString.contains("constraint") ||
           errorString.contains("violates") {
            return .permanent
        }
        
        // 网络相关 - 临时
        if errorString.contains("network") ||
           errorString.contains("timeout") ||
           errorString.contains("connection") {
            return .temporary
        }
        
        // 重复键 - 永久
        if errorString.contains("duplicate") ||
           errorString.contains("unique") {
            return .permanent
        }
        
        return .unknown
    }
    
    // MARK: - 完整的登录流程（同步等待Profile）
    func performSafeLogin(email: String, password: String) async throws -> User {
        print("🔐 执行安全登录流程...")
        
        // 1. 执行登录
        // 这里应该调用你的实际登录API
        // let user = try await actualLogin(email: email, password: password)
        
        // 2. 同步等待Profile创建完成
        // try await UserProfileManager.shared.ensureUserProfile(for: user)
        
        // 3. 初始化必要的数据
        // await SessionManager.shared.loadRecentSessions()
        
        // 4. 返回用户
        // return user
        
        throw DataError.notImplemented
    }
}

// MARK: - 错误类型
enum ErrorCategory {
    case permanent  // 不应重试
    case temporary  // 可以重试
    case unknown    // 不确定
}

// MARK: - 数据错误
enum DataError: LocalizedError {
    case notAuthenticated
    case userMismatch
    case sessionNotFound
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .userMismatch:
            return "用户ID不匹配"
        case .sessionNotFound:
            return "会话不存在"
        case .notImplemented:
            return "功能未实现"
        }
    }
}