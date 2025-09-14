//
//  TokenRefreshManager.swift
//  PurpleM
//
//  Token刷新和重试管理器
//

import Foundation

// MARK: - Token刷新管理器
@MainActor
class TokenRefreshManager {
    static let shared = TokenRefreshManager()
    
    private var isRefreshing = false
    private var refreshTask: Task<Bool, Error>?
    private var tokenExpiryDate: Date?
    private var refreshTimer: Timer?
    
    private init() {
        setupTokenExpiryMonitor()
    }
    
    // MARK: - Token过期监控
    private func setupTokenExpiryMonitor() {
        // 监听token更新通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTokenUpdate),
            name: NSNotification.Name("TokenUpdated"),
            object: nil
        )
    }
    
    @objc private func handleTokenUpdate() {
        // 从token中解析过期时间
        if let token = KeychainManager.shared.getAccessToken() {
            if let expiryDate = extractExpiryDate(from: token) {
                tokenExpiryDate = expiryDate
                schedulePreemptiveRefresh(expiryDate: expiryDate)
                print("📅 Token将在 \(expiryDate) 过期")
            }
        }
    }
    
    // 解析JWT token获取过期时间
    private func extractExpiryDate(from token: String) -> Date? {
        let segments = token.split(separator: ".")
        guard segments.count > 1 else { return nil }
        
        let base64String = String(segments[1])
        // 补齐Base64字符串
        let paddedLength = (4 - base64String.count % 4) % 4
        let paddedBase64 = base64String + String(repeating: "=", count: paddedLength)
        
        guard let data = Data(base64Encoded: paddedBase64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        
        return Date(timeIntervalSince1970: exp)
    }
    
    // 安排预先刷新（在过期前5分钟刷新）
    private func schedulePreemptiveRefresh(expiryDate: Date) {
        refreshTimer?.invalidate()
        
        let refreshDate = expiryDate.addingTimeInterval(-300) // 提前5分钟
        let timeInterval = refreshDate.timeIntervalSinceNow
        
        if timeInterval > 0 {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
                Task { @MainActor in
                    print("⏰ Token即将过期，自动刷新...")
                    await self.refreshTokenIfNeeded()
                }
            }
            print("⏱️ 已安排在 \(refreshDate) 自动刷新Token")
        } else {
            // Token已经快过期了，立即刷新
            Task {
                await refreshTokenIfNeeded()
            }
        }
    }
    
    // 检查Token是否需要刷新
    func shouldRefreshToken() -> Bool {
        guard let expiryDate = tokenExpiryDate else {
            // 没有过期时间信息，检查token是否存在
            if let token = KeychainManager.shared.getAccessToken() {
                // 尝试解析过期时间
                if let expiry = extractExpiryDate(from: token) {
                    tokenExpiryDate = expiry
                    return Date().addingTimeInterval(300) > expiry // 5分钟内过期
                }
            }
            return false
        }
        
        // 检查是否在5分钟内过期
        return Date().addingTimeInterval(300) > expiryDate
    }
    
    // MARK: - 刷新Token
    private var refreshRetryCount = 0
    private let maxRefreshRetries = 3
    
    func refreshTokenIfNeeded() async -> Bool {
        // 如果已经在刷新，等待结果
        if let task = refreshTask {
            return await (try? task.value) ?? false
        }
        
        // 开始新的刷新任务
        refreshTask = Task {
            defer {
                self.refreshTask = nil
                self.isRefreshing = false
            }
            
            self.isRefreshing = true
            
            // 获取refresh token
            guard let refreshToken = KeychainManager.shared.getRefreshToken() else {
                print("❌ 没有refresh token，需要重新登录")
                // 不立即登出，而是发送通知让UI处理
                NotificationCenter.default.post(
                    name: NSNotification.Name("TokenRefreshRequired"),
                    object: nil
                )
                return false
            }
            
            // 带重试的token刷新
            for attempt in 0..<maxRefreshRetries {
                do {
                    let refreshData = try await performTokenRefresh(refreshToken: refreshToken)
                    
                    // 保存新的tokens
                    if let newAccessToken = refreshData["access_token"] as? String,
                       let newRefreshToken = refreshData["refresh_token"] as? String {
                        KeychainManager.shared.saveAuthTokens(
                            accessToken: newAccessToken,
                            refreshToken: newRefreshToken
                        )
                        print("✅ Token刷新成功")
                        self.refreshRetryCount = 0 // 重置重试计数器
                        return true
                    }
                } catch {
                    print("⚠️ Token刷新失败 (尝试 \(attempt + 1)/\(maxRefreshRetries)): \(error)")
                    
                    if attempt < maxRefreshRetries - 1 {
                        // 指数退避
                        let delay = Double(attempt + 1) * 2.0
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            }
            
            // 多次重试后仍失败
            print("❌ Token刷新已达最大重试次数")
            NotificationCenter.default.post(
                name: NSNotification.Name("TokenRefreshFailed"),
                object: nil
            )
            
            // 只有在多次失败后才考虑登出
            if self.refreshRetryCount >= 2 {
                await AuthManager.shared.signOut()
            } else {
                self.refreshRetryCount += 1
            }
            
            return false
        }
        
        return await (try? refreshTask?.value) ?? false
    }
    
    // MARK: - 执行Token刷新
    private func performTokenRefresh(refreshToken: String) async throws -> [String: Any] {
        let url = URL(string: "\(SupabaseManager.shared.baseURL)/auth/v1/token?grant_type=refresh_token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseManager.shared.apiKey, forHTTPHeaderField: "apikey")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.tokenRefreshFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }
        
        return json
    }
}

// MARK: - 增强的API请求执行器
extension SupabaseAPIHelper {
    
    // MARK: - 带重试的请求执行
    static func executeWithRetry<T: Decodable>(
        request: URLRequest,
        expecting type: T.Type,
        maxRetries: Int = 2
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // 检查401错误
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 401 {
                    print("⚠️ 收到401错误，尝试刷新token...")
                    
                    // 尝试刷新token
                    if await TokenRefreshManager.shared.refreshTokenIfNeeded() {
                        // Token刷新成功，重建请求
                        var newRequest = request
                        if let newToken = KeychainManager.shared.getAccessToken() {
                            newRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                        }
                        
                        // 使用新token重试
                        let (retryData, retryResponse) = try await URLSession.shared.data(for: newRequest)
                        
                        if let httpRetryResponse = retryResponse as? HTTPURLResponse,
                           httpRetryResponse.statusCode >= 200 && httpRetryResponse.statusCode < 300 {
                            return try JSONDecoder().decode(type, from: retryData)
                        }
                    }
                }
                
                // 检查其他HTTP错误
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode >= 400 {
                    throw APIError.serverError(httpResponse.statusCode)
                }
                
                // 成功的响应
                return try JSONDecoder().decode(type, from: data)
                
            } catch {
                lastError = error
                
                // 如果是网络错误，等待后重试
                if (error as NSError).domain == NSURLErrorDomain {
                    let delay = Double(attempt + 1) * 2.0 // 指数退避
                    print("⏰ 网络错误，\(delay)秒后重试...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                // 其他错误立即抛出
                throw error
            }
        }
        
        throw lastError ?? APIError.unknown
    }
}

// MARK: - API错误扩展
extension APIError {
    static let tokenRefreshFailed = APIError.serverError(498) // 使用498表示Token过期
    static let networkError = APIError.serverError(599) // 使用599表示网络错误
}