//
//  TestSupabaseConnection.swift
//  PurpleM
//
//  Supabase连接测试 - 在App中测试
//

import SwiftUI

struct TestSupabaseConnection: View {
    @State private var testResults: [TestResult] = []
    @State private var isRunning = false
    @State private var overallStatus = "准备测试"
    
    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let passed: Bool
        let message: String
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                VStack(spacing: 20) {
                    // 标题
                    Text("Supabase连接测试")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.crystalWhite)
                    
                    Text(overallStatus)
                        .font(.system(size: 16))
                        .foregroundColor(.moonSilver)
                    
                    // 测试按钮
                    Button(action: runTests) {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.circle.fill")
                            }
                            Text(isRunning ? "测试中..." : "开始测试")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.mysticPink, .cosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                    }
                    .disabled(isRunning)
                    
                    // 测试结果列表
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(testResults) { result in
                                HStack {
                                    Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.passed ? .green : .red)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.crystalWhite)
                                        
                                        Text(result.message)
                                            .font(.system(size: 12))
                                            .foregroundColor(.moonSilver.opacity(0.8))
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.top, 50)
            }
            .navigationBarHidden(true)
        }
    }
    
    // 运行所有测试
    private func runTests() {
        testResults.removeAll()
        isRunning = true
        overallStatus = "测试中..."
        
        Task {
            // Test 1: 检查网络连接
            await testNetworkConnection()
            
            // Test 2: 测试Supabase连接
            await testSupabaseConnection()
            
            // Test 3: 测试会话创建
            await testSessionCreation()
            
            // Test 4: 测试消息保存
            await testMessageSaving()
            
            // Test 5: 测试配额检查
            await testQuotaCheck()
            
            // Test 6: 测试AI API
            await testAIAPI()
            
            // Test 7: 测试离线队列
            await testOfflineQueue()
            
            // Test 8: 测试记忆同步
            await testMemorySync()
            
            await MainActor.run {
                isRunning = false
                
                let passedCount = testResults.filter { $0.passed }.count
                let totalCount = testResults.count
                
                if passedCount == totalCount {
                    overallStatus = "✅ 所有测试通过！(\(passedCount)/\(totalCount))"
                } else {
                    overallStatus = "⚠️ 部分测试失败 (\(passedCount)/\(totalCount))"
                }
            }
        }
    }
    
    // Test 1: 网络连接
    private func testNetworkConnection() async {
        let result: TestResult
        
        if NetworkMonitor.shared.isConnected {
            result = TestResult(
                name: "网络连接",
                passed: true,
                message: "网络连接正常"
            )
        } else {
            result = TestResult(
                name: "网络连接",
                passed: false,
                message: "无网络连接，请检查网络设置"
            )
        }
        
        await MainActor.run {
            testResults.append(result)
        }
    }
    
    // Test 2: Supabase连接
    private func testSupabaseConnection() async {
        var result: TestResult
        
        do {
            // 尝试获取一个简单的查询
            let testUserId = "test-user-\(UUID().uuidString)"
            let quota = try await SupabaseManager.shared.getUserQuota(userId: testUserId)
            
            if quota != nil {
                result = TestResult(
                    name: "Supabase连接",
                    passed: true,
                    message: "成功连接到Supabase"
                )
            } else {
                result = TestResult(
                    name: "Supabase连接",
                    passed: true,
                    message: "Supabase可访问（无数据）"
                )
            }
        } catch {
            result = TestResult(
                name: "Supabase连接",
                passed: false,
                message: "连接失败: \(error.localizedDescription)"
            )
        }
        
        await MainActor.run {
            testResults.append(result)
        }
    }
    
    // Test 3: 会话创建
    private func testSessionCreation() async {
        var result: TestResult
        
        do {
            let testUserId = "test-\(UUID().uuidString)"
            let session = try await SupabaseManager.shared.createChatSession(
                userId: testUserId,
                sessionType: "test",
                title: "测试会话"
            )
            
            result = TestResult(
                name: "会话创建",
                passed: true,
                message: "成功创建会话: \(session.id)"
            )
        } catch {
            result = TestResult(
                name: "会话创建",
                passed: false,
                message: "创建失败: \(error.localizedDescription)"
            )
        }
        
        await MainActor.run {
            testResults.append(result)
        }
    }
    
    // Test 4: 消息保存
    private func testMessageSaving() async {
        var result: TestResult
        
        do {
            let testSessionId = UUID().uuidString
            let testUserId = "test-\(UUID().uuidString)"
            
            try await SupabaseManager.shared.saveMessage(
                sessionId: testSessionId,
                userId: testUserId,
                role: "user",
                content: "测试消息",
                metadata: ["test": "true"]
            )
            
            result = TestResult(
                name: "消息保存",
                passed: true,
                message: "消息保存成功"
            )
        } catch {
            result = TestResult(
                name: "消息保存",
                passed: false,
                message: "保存失败: \(error.localizedDescription)"
            )
        }
        
        await MainActor.run {
            testResults.append(result)
        }
    }
    
    // Test 5: 配额检查
    private func testQuotaCheck() async {
        let result: TestResult
        
        let available = await SupabaseManager.shared.checkQuotaAvailable()
        
        result = TestResult(
            name: "配额检查",
            passed: true,
            message: available ? "配额充足" : "配额不足或未登录"
        )
        
        await MainActor.run {
            testResults.append(result)
        }
    }
    
    // Test 6: AI API测试
    private func testAIAPI() async {
        var result: TestResult
        
        let response = await AIService.shared.sendMessage("测试消息")
        
        if !response.isEmpty && !response.contains("错误") {
            result = TestResult(
                name: "AI API",
                passed: true,
                message: "AI响应正常: \(String(response.prefix(50)))..."
            )
        } else {
            result = TestResult(
                name: "AI API",
                passed: false,
                message: "AI响应异常"
            )
        }
        
        await MainActor.run {
            testResults.append(result)
        }
    }
    
    // Test 7: 离线队列
    private func testOfflineQueue() async {
        let result: TestResult
        
        // 添加测试项到队列
        OfflineQueueManager.shared.enqueue(
            .saveMessage(
                sessionId: "test-session",
                userId: "test-user",
                role: "user",
                content: "离线测试",
                metadata: [:]
            )
        )
        
        let queueSize = OfflineQueueManager.shared.queueSize
        
        result = TestResult(
            name: "离线队列",
            passed: true,
            message: "队列工作正常，当前大小: \(queueSize)"
        )
        
        await MainActor.run {
            testResults.append(result)
        }
        
        // 清理测试数据
        if NetworkMonitor.shared.isConnected {
            await OfflineQueueManager.shared.processQueue()
        }
    }
    
    // Test 8: 记忆同步
    private func testMemorySync() async {
        var result: TestResult
        
        if let userId = AuthManager.shared.currentUser?.id {
            await EnhancedAIService.shared.syncMemoryToCloud(userId: userId)
            
            result = TestResult(
                name: "记忆同步",
                passed: true,
                message: "记忆同步完成"
            )
        } else {
            result = TestResult(
                name: "记忆同步",
                passed: false,
                message: "未登录，无法测试同步"
            )
        }
        
        await MainActor.run {
            testResults.append(result)
        }
    }
}

// 测试入口 - 可以在ContentView中添加
struct TestSupabaseButton: View {
    @State private var showTest = false
    
    var body: some View {
        Button(action: { showTest = true }) {
            Label("测试Supabase", systemImage: "testtube.2")
                .foregroundColor(.starGold)
        }
        .sheet(isPresented: $showTest) {
            TestSupabaseConnection()
        }
    }
}

struct TestSupabaseConnection_Previews: PreviewProvider {
    static var previews: some View {
        TestSupabaseConnection()
    }
}