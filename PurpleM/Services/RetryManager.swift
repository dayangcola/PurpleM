//
//  RetryManager.swift
//  PurpleM
//
//  智能重试管理器 - 处理网络请求的暂时性失败
//

import Foundation

// MARK: - 重试策略
enum RetryStrategy {
    case exponentialBackoff  // 指数退避
    case linear             // 线性间隔
    case immediate          // 立即重试
    
    func delayForRetry(_ retryCount: Int) -> TimeInterval {
        switch self {
        case .exponentialBackoff:
            // 2^n 秒，最多32秒
            return min(pow(2.0, Double(retryCount)), 32.0)
        case .linear:
            // n * 2 秒
            return Double(retryCount) * 2.0
        case .immediate:
            return 0.1
        }
    }
}

// MARK: - 重试配置
struct RetryConfiguration {
    let maxRetries: Int
    let strategy: RetryStrategy
    let retryableErrors: Set<Int>  // 可重试的HTTP状态码
    let shouldRetryBlock: ((Error, Int) -> Bool)?
    
    static let `default` = RetryConfiguration(
        maxRetries: 3,
        strategy: .exponentialBackoff,
        retryableErrors: [408, 429, 500, 502, 503, 504],  // 超时、限流、服务器错误
        shouldRetryBlock: nil
    )
    
    static let aggressive = RetryConfiguration(
        maxRetries: 5,
        strategy: .exponentialBackoff,
        retryableErrors: [408, 429, 500, 502, 503, 504, 409],  // 包括冲突
        shouldRetryBlock: nil
    )
    
    static let conservative = RetryConfiguration(
        maxRetries: 2,
        strategy: .linear,
        retryableErrors: [503, 504],  // 只重试服务不可用
        shouldRetryBlock: nil
    )
}

// MARK: - 重试管理器
class RetryManager {
    
    static let shared = RetryManager()
    
    private init() {}
    
    // MARK: - 执行带重试的操作
    func performWithRetry<T>(
        operation: @escaping () async throws -> T,
        configuration: RetryConfiguration = .default
    ) async throws -> T {
        
        var lastError: Error?
        
        for retryCount in 0...configuration.maxRetries {
            do {
                // 执行操作
                let result = try await operation()
                
                // 成功则返回
                if retryCount > 0 {
                    print("✅ 重试成功，第 \(retryCount) 次重试")
                }
                return result
                
            } catch {
                lastError = error
                
                // 判断是否应该重试
                let shouldRetry = shouldRetryError(
                    error,
                    retryCount: retryCount,
                    configuration: configuration
                )
                
                if !shouldRetry || retryCount == configuration.maxRetries {
                    // 不重试或已达最大重试次数
                    print("❌ 操作失败，不再重试: \(error.localizedDescription)")
                    throw error
                }
                
                // 计算延迟
                let delay = configuration.strategy.delayForRetry(retryCount)
                print("⏳ 将在 \(delay) 秒后进行第 \(retryCount + 1) 次重试...")
                
                // 等待后重试
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // 理论上不应该到这里
        throw lastError ?? APIError.invalidResponse
    }
    
    // MARK: - 判断是否应该重试
    private func shouldRetryError(
        _ error: Error,
        retryCount: Int,
        configuration: RetryConfiguration
    ) -> Bool {
        
        // 检查自定义重试逻辑
        if let shouldRetryBlock = configuration.shouldRetryBlock {
            return shouldRetryBlock(error, retryCount)
        }
        
        // 检查网络错误
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost,
                 .notConnectedToInternet, .dnsLookupFailed:
                print("🔄 网络错误，将重试: \(urlError.code.rawValue)")
                return true
            default:
                return false
            }
        }
        
        // 检查API错误
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let statusCode):
                let shouldRetry = configuration.retryableErrors.contains(statusCode)
                if shouldRetry {
                    print("🔄 服务器错误 \(statusCode)，将重试")
                }
                return shouldRetry
                
            case .networkError:
                print("🔄 网络错误，将重试")
                return true
                
            case .unauthorized:
                // 认证失败通常不应重试
                return false
                
            default:
                return false
            }
        }
        
        return false
    }
    
    // MARK: - 带重试的Supabase操作
    func retrySupabaseOperation<T>(
        operation: @escaping () async throws -> T,
        operationName: String = "Supabase操作"
    ) async throws -> T {
        
        print("🔄 开始执行: \(operationName)")
        
        // 使用默认配置，但添加自定义逻辑
        let configuration = RetryConfiguration(
            maxRetries: 3,
            strategy: .exponentialBackoff,
            retryableErrors: [408, 429, 500, 502, 503, 504],
            shouldRetryBlock: { error, retryCount in
                // RLS策略错误（403）在第一次可以重试（可能是token过期）
                if let apiError = error as? APIError,
                   case .serverError(403) = apiError,
                   retryCount == 0 {
                    print("🔄 RLS策略错误，尝试刷新认证后重试")
                    return true
                }
                
                // 冲突错误（409）可以重试一次
                if let apiError = error as? APIError,
                   case .serverError(409) = apiError,
                   retryCount == 0 {
                    print("🔄 数据冲突，尝试重试")
                    return true
                }
                
                return false
            }
        )
        
        return try await performWithRetry(
            operation: operation,
            configuration: configuration
        )
    }
}

// MARK: - 扩展：为特定操作提供重试
extension RetryManager {
    
    // 重试星盘同步
    func retrySaveChart(
        userId: String,
        chartData: ChartData
    ) async throws {
        _ = try await retrySupabaseOperation(
            operation: {
                try await SupabaseManager.shared.saveChartToCloud(
                    userId: userId,
                    chartData: chartData
                )
            },
            operationName: "保存星盘到云端"
        )
    }
    
    // 重试消息保存
    func retrySaveMessage(
        sessionId: String,
        userId: String,
        role: String,
        content: String,
        metadata: [String: String]
    ) async throws {
        try await retrySupabaseOperation(
            operation: {
                try await SupabaseManager.shared.saveMessage(
                    sessionId: sessionId,
                    userId: userId,
                    role: role,
                    content: content,
                    metadata: metadata
                )
            },
            operationName: "保存聊天消息"
        )
    }
    
    // 重试配额更新
    func retryIncrementQuota(
        userId: String,
        tokens: Int
    ) async throws -> Bool {
        return try await retrySupabaseOperation(
            operation: {
                try await SupabaseManager.shared.incrementQuotaUsage(
                    userId: userId,
                    tokens: tokens
                )
            },
            operationName: "更新使用配额"
        )
    }
}

// MARK: - API错误扩展
extension APIError {
    static var networkTimeout: APIError {
        return APIError.serverError(408)
    }
    
    // rateLimited已在SupabaseAPIHelper中定义
}