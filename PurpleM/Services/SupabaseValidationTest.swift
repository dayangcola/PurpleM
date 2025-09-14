//
//  SupabaseValidationTest.swift
//  PurpleM
//
//  验证Supabase数据同步功能的测试类
//

import Foundation
import SwiftUI

@MainActor
class SupabaseValidationTest: ObservableObject {
    static let shared = SupabaseValidationTest()
    
    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    
    struct TestResult: Identifiable {
        let id = UUID()
        let testName: String
        let success: Bool
        let message: String
        let timestamp: Date = Date()
    }
    
    // MARK: - 运行所有测试
    func runAllTests() async {
        isRunning = true
        testResults.removeAll()
        
        print("\n========== 开始Supabase同步测试 ==========\n")
        
        // 1. 测试用户认证状态
        await testAuthStatus()
        
        // 2. 测试Profile同步
        await testProfileSync()
        
        // 3. 测试AI配额初始化
        await testQuotaInitialization()
        
        // 4. 测试AI偏好设置
        await testPreferencesInitialization()
        
        // 5. 测试星盘保存
        await testChartSave()
        
        // 6. 测试星盘读取
        await testChartLoad()
        
        // 7. 测试会话创建
        await testSessionCreation()
        
        print("\n========== 测试完成 ==========\n")
        printSummary()
        
        isRunning = false
    }
    
    // MARK: - 1. 测试用户认证状态
    private func testAuthStatus() async {
        let testName = "用户认证状态"
        
        if let user = AuthManager.shared.currentUser {
            addResult(testName: testName, success: true, 
                     message: "已登录用户: \(user.email) (ID: \(user.id))")
            
            // 检查token
            if let token = KeychainManager.shared.getAccessToken() {
                addResult(testName: "Access Token", success: true, 
                         message: "Token存在 (长度: \(token.count))")
            } else {
                addResult(testName: "Access Token", success: false, 
                         message: "未找到Access Token")
            }
        } else {
            addResult(testName: testName, success: false, 
                     message: "未登录")
        }
    }
    
    // MARK: - 2. 测试Profile同步
    private func testProfileSync() async {
        let testName = "Profile同步"
        
        guard let userId = AuthManager.shared.currentUser?.id else {
            addResult(testName: testName, success: false, message: "未登录，跳过测试")
            return
        }
        
        do {
            // 检查profile是否存在
            let endpoint = "/rest/v1/profiles?id=eq.\(userId)&select=*"
            let data = try await SupabaseManager.shared.makeRequest(
                endpoint: endpoint,
                method: "GET",
                expecting: Data.self
            )
            
            if let profiles = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let profile = profiles.first {
                addResult(testName: testName, success: true, 
                         message: "Profile存在: \(profile["email"] ?? "未知")")
                
                // 检查各字段
                checkField(profile, fieldName: "username", tableName: "profiles")
                checkField(profile, fieldName: "subscription_tier", tableName: "profiles")
                checkField(profile, fieldName: "created_at", tableName: "profiles")
                checkField(profile, fieldName: "updated_at", tableName: "profiles")
                
                // 确保quota字段不在profiles表中
                if profile["quota_limit"] != nil || profile["quota_used"] != nil {
                    addResult(testName: "Profile字段检查", success: false, 
                             message: "⚠️ profiles表不应包含quota字段")
                }
            } else {
                addResult(testName: testName, success: false, 
                         message: "Profile不存在或解析失败")
            }
        } catch {
            addResult(testName: testName, success: false, 
                     message: "查询失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 3. 测试AI配额初始化
    private func testQuotaInitialization() async {
        let testName = "AI配额初始化"
        
        guard let userId = AuthManager.shared.currentUser?.id else {
            addResult(testName: testName, success: false, message: "未登录，跳过测试")
            return
        }
        
        do {
            let endpoint = "/rest/v1/user_ai_quotas?user_id=eq.\(userId)&select=*"
            let data = try await SupabaseManager.shared.makeRequest(
                endpoint: endpoint,
                method: "GET",
                expecting: Data.self
            )
            
            if let quotas = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let quota = quotas.first {
                addResult(testName: testName, success: true, 
                         message: "配额记录存在")
                
                // 检查字段
                checkField(quota, fieldName: "daily_limit", tableName: "user_ai_quotas")
                checkField(quota, fieldName: "daily_used", tableName: "user_ai_quotas")
                checkField(quota, fieldName: "monthly_limit", tableName: "user_ai_quotas")
                checkField(quota, fieldName: "monthly_used", tableName: "user_ai_quotas")
                checkField(quota, fieldName: "reset_date", tableName: "user_ai_quotas")
            } else {
                addResult(testName: testName, success: false, 
                         message: "配额记录不存在")
            }
        } catch {
            addResult(testName: testName, success: false, 
                     message: "查询失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 4. 测试AI偏好设置
    private func testPreferencesInitialization() async {
        let testName = "AI偏好设置"
        
        guard let userId = AuthManager.shared.currentUser?.id else {
            addResult(testName: testName, success: false, message: "未登录，跳过测试")
            return
        }
        
        do {
            let endpoint = "/rest/v1/user_ai_preferences?user_id=eq.\(userId)&select=*"
            let data = try await SupabaseManager.shared.makeRequest(
                endpoint: endpoint,
                method: "GET",
                expecting: Data.self
            )
            
            if let preferences = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let preference = preferences.first {
                addResult(testName: testName, success: true, 
                         message: "偏好设置存在")
                
                // 检查字段
                checkField(preference, fieldName: "conversation_style", tableName: "user_ai_preferences")
                checkField(preference, fieldName: "response_length", tableName: "user_ai_preferences")
                checkField(preference, fieldName: "enable_suggestions", tableName: "user_ai_preferences")
                checkField(preference, fieldName: "preferred_topics", tableName: "user_ai_preferences")
            } else {
                addResult(testName: testName, success: false, 
                         message: "偏好设置不存在")
            }
        } catch {
            addResult(testName: testName, success: false, 
                     message: "查询失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 5. 测试星盘保存
    private func testChartSave() async {
        let testName = "星盘保存"
        
        guard let userId = AuthManager.shared.currentUser?.id,
              let chart = UserDataManager.shared.currentChart else {
            addResult(testName: testName, success: false, 
                     message: "无用户或星盘数据，跳过测试")
            return
        }
        
        do {
            let savedChart = try await SupabaseManager.shared.saveChartToCloud(
                userId: userId,
                chartData: chart
            )
            
            addResult(testName: testName, success: true, 
                     message: "星盘保存成功 (ID: \(savedChart.id ?? "未知"))")
            
            // 验证字段
            if savedChart.generatedAt != nil {
                addResult(testName: "星盘时间戳", success: true, 
                         message: "使用正确的generated_at字段")
            } else {
                addResult(testName: "星盘时间戳", success: false, 
                         message: "generated_at字段缺失")
            }
            
        } catch {
            addResult(testName: testName, success: false, 
                     message: "保存失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 6. 测试星盘读取
    private func testChartLoad() async {
        let testName = "星盘读取"
        
        guard let userId = AuthManager.shared.currentUser?.id else {
            addResult(testName: testName, success: false, 
                     message: "未登录，跳过测试")
            return
        }
        
        do {
            if let cloudChart = try await SupabaseManager.shared.getUserChart(userId: userId) {
                addResult(testName: testName, success: true, 
                         message: "星盘读取成功")
                
                // 验证数据完整性
                if let localChart = cloudChart.toLocalChartData() {
                    addResult(testName: "星盘数据转换", success: true, 
                             message: "成功转换为本地格式")
                } else {
                    addResult(testName: "星盘数据转换", success: false, 
                             message: "转换失败，可能缺少userInfo")
                }
            } else {
                addResult(testName: testName, success: false, 
                         message: "云端没有星盘数据")
            }
        } catch {
            addResult(testName: testName, success: false, 
                     message: "读取失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 7. 测试会话创建
    private func testSessionCreation() async {
        let testName = "会话创建"
        
        guard let userId = AuthManager.shared.currentUser?.id else {
            addResult(testName: testName, success: false, message: "未登录，跳过测试")
            return
        }
        
        do {
            let endpoint = "/rest/v1/chat_sessions?user_id=eq.\(userId)&select=*"
            let data = try await SupabaseManager.shared.makeRequest(
                endpoint: endpoint,
                method: "GET",
                expecting: Data.self
            )
            
            if let sessions = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                if sessions.isEmpty {
                    addResult(testName: testName, success: false, 
                             message: "没有会话记录")
                } else {
                    addResult(testName: testName, success: true, 
                             message: "找到\(sessions.count)个会话")
                    
                    if let firstSession = sessions.first {
                        checkField(firstSession, fieldName: "title", tableName: "chat_sessions")
                        checkField(firstSession, fieldName: "session_type", tableName: "chat_sessions")
                    }
                }
            }
        } catch {
            addResult(testName: testName, success: false, 
                     message: "查询失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 辅助方法
    private func checkField(_ data: [String: Any], fieldName: String, tableName: String) {
        if data[fieldName] != nil {
            print("✅ \(tableName).\(fieldName) 字段存在")
        } else {
            addResult(testName: "\(tableName)字段检查", success: false, 
                     message: "缺少字段: \(fieldName)")
        }
    }
    
    private func addResult(testName: String, success: Bool, message: String) {
        let result = TestResult(testName: testName, success: success, message: message)
        testResults.append(result)
        
        let icon = success ? "✅" : "❌"
        print("\(icon) \(testName): \(message)")
    }
    
    private func printSummary() {
        let successCount = testResults.filter { $0.success }.count
        let totalCount = testResults.count
        let successRate = totalCount > 0 ? (Double(successCount) / Double(totalCount) * 100) : 0
        
        print("\n📊 测试总结:")
        print("   总测试数: \(totalCount)")
        print("   成功: \(successCount)")
        print("   失败: \(totalCount - successCount)")
        print("   成功率: \(String(format: "%.1f", successRate))%")
        
        if successRate == 100 {
            print("\n🎉 所有测试通过！Supabase同步功能正常工作。")
        } else {
            print("\n⚠️ 部分测试失败，请检查上面的错误信息。")
        }
    }
}

// MARK: - 测试视图（可选）
struct SupabaseTestView: View {
    @StateObject private var tester = SupabaseValidationTest.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("测试控制") {
                    Button(action: {
                        Task {
                            await tester.runAllTests()
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("运行所有测试")
                        }
                    }
                    .disabled(tester.isRunning)
                }
                
                Section("测试结果") {
                    if tester.testResults.isEmpty {
                        Text("尚未运行测试")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(tester.testResults) { result in
                            HStack {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.success ? .green : .red)
                                
                                VStack(alignment: .leading) {
                                    Text(result.testName)
                                        .font(.headline)
                                    Text(result.message)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Supabase同步测试")
        }
    }
}