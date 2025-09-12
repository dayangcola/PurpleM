import Foundation
import Combine

// MARK: - User Model
struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let username: String?
    let avatarUrl: String?
    let subscriptionTier: String?
    let createdAt: String  // 改为String，因为API返回的是ISO字符串
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case avatarUrl = "avatar_url"
        case subscriptionTier = "subscription_tier"
        case createdAt = "created_at"
    }
    
    // 计算属性，获取订阅等级
    var tier: String {
        return subscriptionTier ?? "free"
    }
}

// MARK: - Auth State
enum AuthState: Equatable {
    case loading
    case authenticated(User)
    case unauthenticated
    case error(String)
    
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.authenticated(let lUser), .authenticated(let rUser)):
            return lUser.id == rUser.id
        case (.unauthenticated, .unauthenticated):
            return true
        case (.error(let lError), .error(let rError)):
            return lError == rError
        default:
            return false
        }
    }
}

// MARK: - Auth Manager
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var authState: AuthState = .loading
    @Published var currentUser: User?
    
    private var cancellables = Set<AnyCancellable>()
    
    var isAuthenticated: Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Check Auth Status
    func checkAuthStatus() {
        authState = .loading
        
        // Check if we have a stored session
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.authState = .authenticated(user)
            
            // Validate session with server
            validateSession(userId: user.id)
        } else {
            authState = .unauthenticated
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        authState = .loading
        
        do {
            let url = URL(string: "\(SupabaseConfig.apiBaseURL)/auth?action=login")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            
            let body = ["email": email, "password": password]
            request.httpBody = try JSONEncoder().encode(body)
            
            print("🔐 Attempting login for: \(email)")
            print("📍 API URL: \(url.absoluteString)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw AuthError.networkError
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Login failed: \(errorMessage)")
                throw AuthError.invalidCredentials
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            print("✅ Login successful for user: \(authResponse.user.id)")
            
            // Save user data
            self.currentUser = authResponse.user
            self.authState = .authenticated(authResponse.user)
            
            // Persist user data
            if let userData = try? JSONEncoder().encode(authResponse.user) {
                UserDefaults.standard.set(userData, forKey: "currentUser")
            }
            
            // Save access token
            if let token = authResponse.accessToken {
                UserDefaults.standard.set(token, forKey: "accessToken")
            }
            
            // 发送认证状态变化通知
            NotificationCenter.default.post(
                name: NSNotification.Name("AuthStateChanged"),
                object: nil
            )
            
        } catch let error as AuthError {
            print("❌ Auth error: \(error.localizedDescription)")
            authState = .error(error.localizedDescription)
        } catch {
            print("❌ Unexpected error: \(error)")
            authState = .error("网络连接失败，请检查网络设置")
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, username: String) async {
        authState = .loading
        
        do {
            let url = URL(string: "\(SupabaseConfig.apiBaseURL)/auth?action=signup")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            
            let body = [
                "email": email,
                "password": password,
                "username": username
            ]
            request.httpBody = try JSONEncoder().encode(body)
            
            print("📝 Attempting signup for: \(email)")
            print("📍 API URL: \(url.absoluteString)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw AuthError.networkError
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Signup failed: \(errorMessage)")
                throw AuthError.signUpFailed
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            print("✅ Signup successful for user: \(authResponse.user.id)")
            
            // Check if we have a session token (user might need email verification)
            if authResponse.accessToken != nil {
                // Auto login successful
                self.currentUser = authResponse.user
                self.authState = .authenticated(authResponse.user)
                
                // Persist user data
                if let userData = try? JSONEncoder().encode(authResponse.user) {
                    UserDefaults.standard.set(userData, forKey: "currentUser")
                }
                
                // Save access token
                UserDefaults.standard.set(authResponse.accessToken!, forKey: "accessToken")
            } else {
                // Need email verification
                print("⚠️ Email verification required")
                self.authState = .unauthenticated
            }
            
        } catch let error as AuthError {
            print("❌ Auth error: \(error.localizedDescription)")
            authState = .error(error.localizedDescription)
        } catch {
            print("❌ Unexpected error: \(error)")
            authState = .error("网络连接失败，请检查网络设置")
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        do {
            let url = URL(string: "\(SupabaseConfig.apiBaseURL)/auth?action=logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            if let token = UserDefaults.standard.string(forKey: "accessToken") {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (_, _) = try await URLSession.shared.data(for: request)
            
            // Clear local data
            clearLocalData()
            
        } catch {
            // Even if logout fails on server, clear local data
            clearLocalData()
        }
    }
    
    // MARK: - Reset Password
    func resetPassword(email: String) async throws {
        let url = URL(string: "\(SupabaseConfig.apiBaseURL)/auth?action=reset-password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.resetPasswordFailed
        }
    }
    
    // MARK: - Private Methods
    private func validateSession(userId: String) {
        Task {
            do {
                let url = URL(string: "\(SupabaseConfig.apiBaseURL)/auth?action=validate")!
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                if let token = UserDefaults.standard.string(forKey: "accessToken") {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    await MainActor.run {
                        self.clearLocalData()
                    }
                    return
                }
                
            } catch {
                await MainActor.run {
                    self.clearLocalData()
                }
            }
        }
    }
    
    private func clearLocalData() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "accessToken")
        self.currentUser = nil
        self.authState = .unauthenticated
        
        // 发送认证状态变化通知
        NotificationCenter.default.post(
            name: NSNotification.Name("AuthStateChanged"),
            object: nil
        )
    }
}

// MARK: - Auth Response
struct AuthResponse: Codable {
    let user: User
    let accessToken: String?
    let refreshToken: String?
    let success: Bool?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case success
        case message
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case signUpFailed
    case resetPasswordFailed
    case sessionExpired
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "邮箱或密码错误"
        case .signUpFailed:
            return "注册失败，请稍后重试"
        case .resetPasswordFailed:
            return "重置密码失败"
        case .sessionExpired:
            return "登录已过期，请重新登录"
        case .networkError:
            return "网络连接失败"
        }
    }
}