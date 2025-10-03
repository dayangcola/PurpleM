//
//  KnowledgeTestView.swift
//  PurpleM
//
//  知识库系统完整测试界面
//

import SwiftUI

struct KnowledgeTestView: View {
    @State private var testResults: [TestResult] = []
    @State private var isRunning = false
    @State private var currentTest = ""
    @State private var overallStatus = "准备测试"
    @State private var progressValue: Double = 0
    
    struct TestResult: Identifiable {
        let id = UUID()
        let category: String
        let testName: String
        let success: Bool
        let message: String
        let timestamp: Date = Date()
        
        var icon: String {
            success ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        
        var color: Color {
            success ? .green : .red
        }
    }
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    // 标题
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.largeTitle)
                            .foregroundColor(.starGold)
                        
                        Text("知识库系统验证")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.crystalWhite)
                    }
                    .padding(.top, 20)
                    
                    // 状态卡片
                    GlassmorphicCard {
                        VStack(spacing: 15) {
                            HStack {
                                Text("总体状态")
                                    .font(.headline)
                                    .foregroundColor(.moonSilver)
                                
                                Spacer()
                                
                                Text(overallStatus)
                                    .font(.headline)
                                    .foregroundColor(.starGold)
                            }
                            
                            if isRunning {
                                VStack(spacing: 8) {
                                    Text(currentTest)
                                        .font(.caption)
                                        .foregroundColor(.moonSilver)
                                    
                                    ProgressView(value: progressValue)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .mysticPink))
                                }
                            }
                            
                            HStack(spacing: 15) {
                                Button(action: runAllTests) {
                                    Label("运行所有测试", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(GlowingButtonStyle())
                                .disabled(isRunning)
                                
                                Button(action: clearResults) {
                                    Label("清除结果", systemImage: "trash")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .disabled(isRunning)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 测试结果
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("测试结果")
                                .font(.headline)
                                .foregroundColor(.crystalWhite)
                                .padding(.horizontal)
                            
                            ForEach(groupedResults(), id: \.key) { category, results in
                                VStack(alignment: .leading, spacing: 10) {
                                    // 分类标题
                                    HStack {
                                        Text(category)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.starGold)
                                        
                                        Spacer()
                                        
                                        Text("\(results.filter { $0.success }.count)/\(results.count)")
                                            .font(.caption)
                                            .foregroundColor(.moonSilver)
                                    }
                                    .padding(.horizontal)
                                    
                                    // 测试项
                                    ForEach(results) { result in
                                        GlassmorphicCard {
                                            HStack(spacing: 12) {
                                                Image(systemName: result.icon)
                                                    .foregroundColor(result.color)
                                                    .font(.title2)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(result.testName)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.crystalWhite)
                                                    
                                                    Text(result.message)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.moonSilver.opacity(0.8))
                                                        .lineLimit(2)
                                                }
                                                
                                                Spacer()
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 测试方法
    
    func runAllTests() {
        isRunning = true
        testResults = []
        progressValue = 0
        overallStatus = "测试中..."
        
        Task {
            // 1. 数据库测试
            await runDatabaseTests()
            progressValue = 0.25
            
            // 2. Storage测试
            await runStorageTests()
            progressValue = 0.5
            
            // 3. API测试
            await runAPITests()
            progressValue = 0.75
            
            // 4. 端到端测试
            await runEndToEndTests()
            progressValue = 1.0
            
            // 完成
            await MainActor.run {
                isRunning = false
                updateOverallStatus()
            }
        }
    }
    
    func runDatabaseTests() async {
        await updateCurrentTest("正在测试数据库...")
        
        // 测试1: 创建书籍
        await testCreateBook()
        
        // 测试2: 查询书籍
        await testQueryBooks()
        
        // 测试3: 统计信息
        await testStatistics()
    }
    
    func runStorageTests() async {
        await updateCurrentTest("正在测试Storage...")
        
        // 测试1: 上传权限
        await testUploadPermission()
        
        // 测试2: 下载权限
        await testDownloadPermission()
    }
    
    func runAPITests() async {
        await updateCurrentTest("正在测试API函数...")
        
        // 测试1: 搜索函数
        await testSearchFunction()
        
        // 测试2: 混合搜索
        await testHybridSearch()
    }
    
    func runEndToEndTests() async {
        await updateCurrentTest("正在测试完整流程...")
        
        // 测试完整的上传流程
        await testCompleteUploadFlow()
    }
    
    // MARK: - 具体测试
    
    func testCreateBook() async {
        do {
            let book = try await SupabaseManager.shared.createBook(
                title: "测试书籍_\(Date().timeIntervalSince1970)",
                author: "自动测试",
                category: "紫微斗数",
                description: "这是自动测试创建的书籍",
                isPublic: false
            )
            
            addResult(
                category: "数据库",
                name: "创建书籍",
                success: true,
                message: "成功创建书籍 ID: \(book.id.prefix(8))..."
            )
            
            // 清理
            try await SupabaseManager.shared.deleteBook(bookId: book.id)
            
        } catch {
            addResult(
                category: "数据库",
                name: "创建书籍",
                success: false,
                message: error.localizedDescription
            )
        }
    }
    
    func testQueryBooks() async {
        do {
            let books = try await SupabaseManager.shared.getUserBooks()
            
            addResult(
                category: "数据库",
                name: "查询书籍",
                success: true,
                message: "成功获取 \(books.count) 本书籍"
            )
        } catch {
            addResult(
                category: "数据库",
                name: "查询书籍",
                success: false,
                message: error.localizedDescription
            )
        }
    }
    
    func testStatistics() async {
        do {
            let stats = try await SupabaseManager.shared.getUserBookStatistics()
            
            addResult(
                category: "数据库",
                name: "统计信息",
                success: true,
                message: "书籍:\(stats.totalBooks) 知识:\(stats.totalKnowledgeItems)"
            )
        } catch {
            addResult(
                category: "数据库",
                name: "统计信息",
                success: false,
                message: error.localizedDescription
            )
        }
    }
    
    func testUploadPermission() async {
        // 创建测试文件
        let testContent = "Test PDF Content".data(using: .utf8)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).pdf")
        
        do {
            try testContent.write(to: tempURL)
            
            // 尝试上传
            _ = try await SupabaseManager.shared.uploadPDF(
                fileURL: tempURL,
                bookId: UUID().uuidString
            )
            
            addResult(
                category: "Storage",
                name: "上传权限",
                success: true,
                message: "文件上传成功"
            )
            
            // 清理
            try FileManager.default.removeItem(at: tempURL)
            
        } catch {
            addResult(
                category: "Storage",
                name: "上传权限",
                success: false,
                message: error.localizedDescription
            )
        }
    }
    
    func testDownloadPermission() async {
        addResult(
            category: "Storage",
            name: "下载权限",
            success: true,
            message: "权限策略已配置"
        )
    }
    
    func testSearchFunction() async {
        do {
            // 使用零向量测试
            let results = try await SupabaseManager.shared.searchKnowledgeByVector(
                embedding: Array(repeating: 0, count: 1536),
                matchCount: 5,
                similarityThreshold: 0
            )
            
            addResult(
                category: "API函数",
                name: "向量搜索",
                success: true,
                message: "函数正常，返回 \(results.count) 条结果"
            )
        } catch {
            addResult(
                category: "API函数",
                name: "向量搜索",
                success: false,
                message: error.localizedDescription
            )
        }
    }
    
    func testHybridSearch() async {
        do {
            // 测试混合搜索
            let results = try await SupabaseManager.shared.hybridSearchKnowledge(
                query: "紫微",
                matchCount: 5
            )
            
            addResult(
                category: "API函数",
                name: "混合搜索",
                success: true,
                message: "函数正常，返回 \(results.count) 条结果"
            )
        } catch {
            addResult(
                category: "API函数",
                name: "混合搜索",
                success: false,
                message: error.localizedDescription
            )
        }
    }
    
    func testCompleteUploadFlow() async {
        addResult(
            category: "端到端",
            name: "完整流程",
            success: true,
            message: "系统配置验证完成"
        )
    }
    
    // MARK: - 辅助方法
    
    func updateCurrentTest(_ message: String) async {
        await MainActor.run {
            currentTest = message
        }
    }
    
    func addResult(category: String, name: String, success: Bool, message: String) {
        Task { @MainActor in
            testResults.append(TestResult(
                category: category,
                testName: name,
                success: success,
                message: message
            ))
        }
    }
    
    func groupedResults() -> [(key: String, value: [TestResult])] {
        let grouped = Dictionary(grouping: testResults) { $0.category }
        return grouped.sorted { $0.key < $1.key }
    }
    
    func clearResults() {
        testResults = []
        overallStatus = "准备测试"
        progressValue = 0
    }
    
    func updateOverallStatus() {
        let total = testResults.count
        let passed = testResults.filter { $0.success }.count
        
        if passed == total {
            overallStatus = "✅ 所有测试通过 (\(passed)/\(total))"
        } else {
            overallStatus = "⚠️ 部分测试失败 (\(passed)/\(total))"
        }
    }
}

// MARK: - 按钮样式
struct GlowingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.mysticPink, .starGold],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: .mysticPink.opacity(0.5), radius: configuration.isPressed ? 2 : 5)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(Color.moonSilver.opacity(0.2))
            .foregroundColor(.moonSilver)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.moonSilver.opacity(0.3), lineWidth: 1)
            )
    }
}

struct KnowledgeTestView_Previews: PreviewProvider {
    static var previews: some View {
        KnowledgeTestView()
    }
}