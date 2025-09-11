# 🧪 知识库系统测试指南

## 测试前准备

### 1. 确认数据库设置
在Supabase SQL编辑器中运行以下测试查询：

```sql
-- 测试1: 验证扩展安装
SELECT extname, extversion 
FROM pg_extension 
WHERE extname IN ('vector', 'pg_trgm');

-- 预期结果：应该看到两个扩展
```

```sql
-- 测试2: 验证表结构
SELECT 
    table_name,
    COUNT(*) as column_count
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name IN ('books', 'knowledge_base')
GROUP BY table_name;

-- 预期结果：
-- books: 14列
-- knowledge_base: 12列 + 1个生成列
```

```sql
-- 测试3: 验证函数
SELECT 
    proname as function_name,
    pronargs as arg_count
FROM pg_proc
WHERE proname IN (
    'search_knowledge',
    'hybrid_search',
    'get_knowledge_context',
    'update_book_progress',
    'get_user_book_stats'
)
ORDER BY proname;

-- 预期结果：5个函数都存在
```

### 2. 测试RLS策略
```sql
-- 测试4: 验证RLS启用
SELECT 
    tablename,
    rowsecurity,
    COUNT(polname) as policy_count
FROM pg_tables
LEFT JOIN pg_policies ON tablename = schemaname || '.' || tablename
WHERE tablename IN ('books', 'knowledge_base')
GROUP BY tablename, rowsecurity;

-- 预期结果：rowsecurity = true，每个表有多个策略
```

## Swift端测试代码

创建一个测试文件来验证连接：

### TestKnowledgeBase.swift
```swift
import SwiftUI

struct TestKnowledgeBaseView: View {
    @State private var testResults: [TestResult] = []
    @State private var isLoading = false
    
    struct TestResult: Identifiable {
        let id = UUID()
        let testName: String
        let success: Bool
        let message: String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("知识库系统测试")
                .font(.largeTitle)
                .bold()
            
            Button("开始测试") {
                runTests()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(testResults) { result in
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
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }
    
    func runTests() {
        isLoading = true
        testResults = []
        
        Task {
            // 测试1: 创建测试书籍
            await testCreateBook()
            
            // 测试2: 获取书籍列表
            await testGetBooks()
            
            // 测试3: 获取统计信息
            await testGetStatistics()
            
            // 测试4: 搜索功能（需要先有数据）
            await testSearch()
            
            isLoading = false
        }
    }
    
    func testCreateBook() async {
        do {
            let book = try await SupabaseManager.shared.createBook(
                title: "测试书籍 - \(Date().timeIntervalSince1970)",
                author: "测试作者",
                category: "紫微斗数",
                description: "这是一本测试书籍",
                totalPages: 100,
                isPublic: false
            )
            
            testResults.append(TestResult(
                testName: "创建书籍",
                success: true,
                message: "成功创建书籍: \(book.title)"
            ))
        } catch {
            testResults.append(TestResult(
                testName: "创建书籍",
                success: false,
                message: "错误: \(error.localizedDescription)"
            ))
        }
    }
    
    func testGetBooks() async {
        do {
            let books = try await SupabaseManager.shared.getUserBooks()
            
            testResults.append(TestResult(
                testName: "获取书籍列表",
                success: true,
                message: "找到 \(books.count) 本书籍"
            ))
        } catch {
            testResults.append(TestResult(
                testName: "获取书籍列表",
                success: false,
                message: "错误: \(error.localizedDescription)"
            ))
        }
    }
    
    func testGetStatistics() async {
        do {
            let stats = try await SupabaseManager.shared.getUserBookStatistics()
            
            testResults.append(TestResult(
                testName: "获取统计信息",
                success: true,
                message: "总书籍: \(stats.totalBooks), 知识条目: \(stats.totalKnowledgeItems)"
            ))
        } catch {
            testResults.append(TestResult(
                testName: "获取统计信息",
                success: false,
                message: "错误: \(error.localizedDescription)"
            ))
        }
    }
    
    func testSearch() async {
        do {
            // 模拟搜索（使用零向量）
            let zeroEmbedding = Array(repeating: Float(0), count: 1536)
            let results = try await SupabaseManager.shared.searchKnowledgeByVector(
                embedding: zeroEmbedding,
                matchCount: 5,
                similarityThreshold: 0.0  // 降低阈值以获得结果
            )
            
            testResults.append(TestResult(
                testName: "向量搜索",
                success: true,
                message: "搜索返回 \(results.count) 条结果"
            ))
        } catch {
            testResults.append(TestResult(
                testName: "向量搜索",
                success: false,
                message: "错误: \(error.localizedDescription)"
            ))
        }
    }
}
```

## 测试步骤

### Phase 1: 数据库验证
1. ✅ 运行SQL测试查询1-4
2. ✅ 确认所有组件就绪

### Phase 2: Swift连接测试
1. ✅ 在App中添加TestKnowledgeBaseView
2. ✅ 运行测试，确认能创建书籍
3. ✅ 确认能获取书籍列表
4. ✅ 确认统计功能正常

### Phase 3: Storage测试
1. ✅ 在Supabase控制台创建pdf-books桶
2. ✅ 测试PDF上传（手动上传一个测试PDF）
3. ✅ 验证访问权限

## 常见问题解决

### 问题: "relation does not exist"
**解决**: 确保执行了所有SQL脚本，特别是02_create_tables.sql

### 问题: "permission denied for schema"
**解决**: 检查RLS策略，确保用户已登录

### 问题: "vector type not found"
**解决**: 确保pgvector扩展已启用
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### 问题: Swift连接失败
**解决**: 检查SupabaseManager配置
- URL正确
- API Key正确
- 网络连接正常

## 测试数据准备

如果需要测试数据，运行以下SQL：

```sql
-- 插入测试书籍
INSERT INTO books (
    title, 
    author, 
    category, 
    description,
    total_pages,
    processing_status,
    user_id,
    is_public
) VALUES (
    '紫微斗数测试书籍',
    '测试作者',
    '紫微斗数',
    '这是一本用于测试的书籍',
    200,
    'completed',
    auth.uid(),  -- 当前用户
    false
);

-- 插入测试知识（需要先有书籍ID）
INSERT INTO knowledge_base (
    book_id,
    book_title,
    chapter,
    section,
    page_number,
    content,
    content_length,
    chunk_index,
    embedding
)
SELECT 
    id as book_id,
    title as book_title,
    '第一章' as chapter,
    '介绍' as section,
    1 as page_number,
    '这是测试内容，紫微斗数是中国传统的命理学说...' as content,
    30 as content_length,
    0 as chunk_index,
    ARRAY_FILL(0.1, ARRAY[1536])::vector(1536) as embedding
FROM books
WHERE title = '紫微斗数测试书籍'
LIMIT 1;
```

## 成功标准

✅ 所有SQL组件创建成功  
✅ Swift能够连接数据库  
✅ 能够创建和查询书籍  
✅ RLS策略正常工作  
✅ Storage桶配置正确  

当所有测试通过后，Phase 1基础架构搭建就完成了！

---

*测试日期: 2025-01-11*