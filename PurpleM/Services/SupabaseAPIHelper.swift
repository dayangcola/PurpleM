//
//  SupabaseAPIHelper.swift
//  PurpleM
//
//  统一的Supabase API帮助类 - 标准化认证和字段映射
//

import Foundation

// MARK: - API认证类型
enum SupabaseAuthType {
    case anon           // 只使用apikey (anon key)
    case authenticated  // 使用Bearer token (用户认证)
    case both          // 同时使用两者（仅在必要时）
}

// MARK: - 字段映射帮助类
struct SupabaseFieldMapper {
    
    // Swift到数据库的字段映射（基于实际数据库schema）
    static let swiftToDatabase: [String: String] = [
        // 用户相关 (profiles表)
        "userId": "user_id",
        "email": "email",
        "username": "username",
        "fullName": "full_name",
        "avatarUrl": "avatar_url",
        "phone": "phone",
        "subscriptionTier": "subscription_tier",
        "isActive": "is_active",
        
        // 星盘相关（注意：star_charts表使用generated_at而不是created_at）
        "chartId": "chart_id",
        "chartData": "chart_data",
        "chartImageUrl": "chart_image_url",
        "interpretationSummary": "interpretation_summary",
        "isPrimary": "is_primary",
        "generatedAt": "generated_at",  // star_charts表特有
        
        // 出生信息相关
        "birthDate": "birth_date",
        "birthTime": "birth_time",
        "birthLocation": "birth_location",
        "isLunarDate": "is_lunar_date",
        "birthProvince": "birth_province",
        "birthCity": "birth_city",
        
        // 会话相关
        "sessionId": "session_id",
        "starChartId": "star_chart_id",
        "sessionType": "session_type",
        "tokensUsed": "tokens_used",
        "modelPreferences": "model_preferences",
        "qualityScore": "quality_score",
        "isArchived": "is_archived",
        "lastMessageAt": "last_message_at",
        "contextSummary": "context_summary",
        
        // 消息相关
        "contentType": "content_type",
        "tokensCount": "tokens_count",
        "modelUsed": "model_used",
        "serviceUsed": "service_used",
        "responseTimeMs": "response_time_ms",
        "costCredits": "cost_credits",
        "isStarred": "is_starred",
        "isHidden": "is_hidden",
        "feedbackText": "feedback_text",
        
        // AI配额相关 (user_ai_quotas表)
        "dailyLimit": "daily_limit",
        "dailyUsed": "daily_used", 
        "monthlyLimit": "monthly_limit",
        "monthlyUsed": "monthly_used",
        "totalTokensUsed": "total_tokens_used",
        "totalCostCredits": "total_cost_credits",
        "dailyResetAt": "daily_reset_at",
        "monthlyResetAt": "monthly_reset_at",
        "bonusCredits": "bonus_credits",
        "bonusExpiresAt": "bonus_expires_at",
        
        // AI偏好相关 (user_ai_preferences表)
        "conversationStyle": "conversation_style",
        "responseLength": "response_length",
        "languageComplexity": "language_complexity",
        "useTerminology": "use_terminology",
        "customPersonality": "custom_personality",
        "autoIncludeChart": "auto_include_chart",
        "preferredTopics": "preferred_topics",
        "avoidedTopics": "avoided_topics",
        "enableSuggestions": "enable_suggestions",
        "enableVoiceInput": "enable_voice_input",
        "enableMarkdown": "enable_markdown",
        
        // 通用时间戳
        "createdAt": "created_at",
        "updatedAt": "updated_at",
        
        // 其他
        "userInfo": "user_info",
        "metadata": "metadata"
    ]
    
    // 数据库到Swift的字段映射（反向映射）
    static let databaseToSwift: [String: String] = {
        var reversed = [String: String]()
        for (key, value) in swiftToDatabase {
            reversed[value] = key
        }
        return reversed
    }()
    
    // 转换单个字段名
    static func toDatabase(_ swiftField: String) -> String {
        return swiftToDatabase[swiftField] ?? swiftField
    }
    
    static func toSwift(_ dbField: String) -> String {
        return databaseToSwift[dbField] ?? dbField
    }
    
    // 转换整个字典
    static func convertToDatabase(_ swiftDict: [String: Any]) -> [String: Any] {
        var dbDict = [String: Any]()
        for (key, value) in swiftDict {
            let dbKey = toDatabase(key)
            
            // 递归处理嵌套字典
            if let nestedDict = value as? [String: Any] {
                dbDict[dbKey] = convertToDatabase(nestedDict)
            } else if let nestedArray = value as? [[String: Any]] {
                dbDict[dbKey] = nestedArray.map { convertToDatabase($0) }
            } else {
                dbDict[dbKey] = value
            }
        }
        return dbDict
    }
    
    static func convertToSwift(_ dbDict: [String: Any]) -> [String: Any] {
        var swiftDict = [String: Any]()
        for (key, value) in dbDict {
            let swiftKey = toSwift(key)
            
            // 递归处理嵌套字典
            if let nestedDict = value as? [String: Any] {
                swiftDict[swiftKey] = convertToSwift(nestedDict)
            } else if let nestedArray = value as? [[String: Any]] {
                swiftDict[swiftKey] = nestedArray.map { convertToSwift($0) }
            } else {
                swiftDict[swiftKey] = value
            }
        }
        return swiftDict
    }
}

// MARK: - Supabase API帮助类
class SupabaseAPIHelper {
    
    // MARK: - 创建标准化的请求
    static func createRequest(
        url: URL,
        method: String,
        authType: SupabaseAuthType,
        apiKey: String,
        userToken: String? = nil,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // 设置内容类型
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 根据认证类型设置headers
        switch authType {
        case .anon:
            // 只使用apikey（用于公共访问）
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
            
        case .authenticated:
            // 只使用Bearer token（用于用户认证的操作）
            if let token = userToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                // 如果没有用户token，回退到anon key
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
            
        case .both:
            // 同时使用两者（某些特殊情况可能需要）
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
            if let token = userToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        // 添加自定义headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 设置body
        request.httpBody = body
        
        return request
    }
    
    // MARK: - 执行请求并处理响应
    static func executeRequest(
        _ request: URLRequest,
        expectedStatusCodes: Set<Int> = [200, 201, 204]
    ) async throws -> (data: Data?, response: HTTPURLResponse) {
        
        // 添加详细的请求日志
        if let url = request.url {
            print("🌐 API请求: \(request.httpMethod ?? "GET") \(url)")
        }
        
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            // 截断过长的body日志
            let maxLength = 500
            if bodyString.count > maxLength {
                print("📦 请求体: \(bodyString.prefix(maxLength))... (截断)")
            } else {
                print("📦 请求体: \(bodyString)")
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 无效的响应类型")
                throw APIError.invalidResponse
            }
            
            // 记录响应状态
            print("📨 响应状态码: \(httpResponse.statusCode)")
            
            // 检查状态码
            if !expectedStatusCodes.contains(httpResponse.statusCode) {
                let errorMessage = data.isEmpty ? "No error message" : (String(data: data, encoding: .utf8) ?? "Unknown error")
                print("❌ API错误 (\(httpResponse.statusCode)): \(errorMessage)")
                
                // 特殊处理常见错误
                switch httpResponse.statusCode {
                case 401:
                    throw APIError.unauthorized
                case 403:
                    throw APIError.unauthorized  // 使用已有的unauthorized
                case 404:
                    throw APIError.invalidResponse
                case 409:
                    throw APIError.serverError(409)
                case 429:
                    throw APIError.serverError(429)
                default:
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            
            // 成功响应
            if let responseData = data.isEmpty ? nil : data,
               let responseString = String(data: responseData, encoding: .utf8) {
                // 截断过长的响应日志
                let maxLength = 500
                if responseString.count > maxLength {
                    print("✅ 响应数据: \(responseString.prefix(maxLength))... (截断)")
                } else {
                    print("✅ 响应数据: \(responseString)")
                }
            }
            
            return (data.isEmpty ? nil : data, httpResponse)
            
        } catch let error as APIError {
            // 重新抛出API错误
            throw error
        } catch {
            // 包装其他错误
            print("❌ 网络请求失败: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - 便捷方法：GET请求
    static func get(
        endpoint: String,
        baseURL: String,
        authType: SupabaseAuthType,
        apiKey: String,
        userToken: String? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> Data? {
        
        var urlString = baseURL + endpoint
        
        // 添加查询参数
        if let params = queryParams {
            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(
            url: url,
            method: "GET",
            authType: authType,
            apiKey: apiKey,
            userToken: userToken
        )
        
        let (data, _) = try await executeRequest(request)
        return data
    }
    
    // MARK: - 便捷方法：POST请求
    static func post(
        endpoint: String,
        baseURL: String,
        authType: SupabaseAuthType,
        apiKey: String,
        userToken: String? = nil,
        body: [String: Any],
        useFieldMapping: Bool = true
    ) async throws -> Data? {
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        // 应用字段映射
        let finalBody = useFieldMapping ? SupabaseFieldMapper.convertToDatabase(body) : body
        let bodyData = try JSONSerialization.data(withJSONObject: finalBody)
        
        let request = createRequest(
            url: url,
            method: "POST",
            authType: authType,
            apiKey: apiKey,
            userToken: userToken,
            body: bodyData,
            headers: ["Prefer": "return=representation"]
        )
        
        let (data, _) = try await executeRequest(request, expectedStatusCodes: [200, 201])
        return data
    }
    
    // MARK: - 便捷方法：PATCH请求
    static func patch(
        endpoint: String,
        baseURL: String,
        authType: SupabaseAuthType,
        apiKey: String,
        userToken: String? = nil,
        body: [String: Any],
        useFieldMapping: Bool = true
    ) async throws -> Data? {
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        // 应用字段映射
        let finalBody = useFieldMapping ? SupabaseFieldMapper.convertToDatabase(body) : body
        let bodyData = try JSONSerialization.data(withJSONObject: finalBody)
        
        let request = createRequest(
            url: url,
            method: "PATCH",
            authType: authType,
            apiKey: apiKey,
            userToken: userToken,
            body: bodyData
        )
        
        let (data, _) = try await executeRequest(request, expectedStatusCodes: [200, 204])
        return data
    }
    
    // MARK: - 便捷方法：DELETE请求
    static func delete(
        endpoint: String,
        baseURL: String,
        authType: SupabaseAuthType,
        apiKey: String,
        userToken: String? = nil
    ) async throws {
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        let request = createRequest(
            url: url,
            method: "DELETE",
            authType: authType,
            apiKey: apiKey,
            userToken: userToken
        )
        
        _ = try await executeRequest(request, expectedStatusCodes: [204])
    }
}

// MARK: - 扩展的API错误类型
extension APIError {
    static var authenticationFailed: APIError {
        return APIError.unauthorized
    }
    
    static var forbidden: APIError {
        return APIError.unauthorized
    }
    
    static var notFound: APIError {
        return APIError.invalidResponse
    }
    
    static var conflict: APIError {
        return APIError.serverError(409)
    }
    
    static var rateLimited: APIError {
        return APIError.serverError(429)
    }
    
    static var invalidURL: APIError {
        return APIError.invalidResponse
    }
    
    // networkError已在enum定义中存在，不需要重复定义
}