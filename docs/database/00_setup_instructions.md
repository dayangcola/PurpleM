# 📚 知识库系统数据库设置指南

## 🎯 概述
本指南帮助你在Supabase中设置紫微斗数知识库系统的数据库结构。

## 📋 前置要求
- Supabase项目已创建
- 拥有项目的管理员权限
- 已获取项目URL和API密钥

## 🚀 设置步骤

### Step 1: 登录Supabase控制台
1. 访问 [https://app.supabase.com](https://app.supabase.com)
2. 选择你的项目
3. 进入 SQL Editor 页面

### Step 2: 执行SQL脚本
按照以下顺序执行SQL文件：

#### 1️⃣ 启用扩展 (01_enable_extensions.sql)
```sql
-- 在SQL编辑器中执行
-- 预计用时：1秒
```
**验证**：执行后应看到 `vector` 和 `pg_trgm` 扩展已启用

#### 2️⃣ 创建表结构 (02_create_tables.sql)
```sql
-- 在SQL编辑器中执行
-- 预计用时：2秒
```
**验证**：
- 检查 `books` 表是否创建成功
- 检查 `knowledge_base` 表是否创建成功
- 确认所有索引已创建

#### 3️⃣ 创建函数 (03_create_functions.sql)
```sql
-- 在SQL编辑器中执行
-- 预计用时：1秒
```
**验证**：测试搜索函数
```sql
-- 测试向量搜索函数（使用零向量）
SELECT * FROM search_knowledge(
    ARRAY_FILL(0, ARRAY[1536])::vector(1536),
    5,
    0.7
);
```

#### 4️⃣ 配置RLS策略 (04_create_rls_policies.sql)
```sql
-- 在SQL编辑器中执行
-- 预计用时：1秒
```
**验证**：
```sql
-- 检查RLS是否启用
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('books', 'knowledge_base');
```

### Step 3: 配置Storage存储桶

#### 1️⃣ 创建存储桶
1. 进入 Storage 页面
2. 点击 "New bucket"
3. 配置：
   - **Name**: `pdf-books`
   - **Public**: 关闭（私有桶）
   - **File size limit**: 50MB
   - **Allowed MIME types**: `application/pdf`

#### 2️⃣ 设置存储策略
1. 选择 `pdf-books` 桶
2. 进入 Policies 标签
3. 添加以下策略：

**上传策略**：
- **Name**: Authenticated users can upload
- **Policy**: INSERT
- **Target roles**: authenticated
- **WITH CHECK**: 
```sql
bucket_id = 'pdf-books' 
AND auth.uid()::text = (storage.foldername(name))[1]
```

**查看策略**：
- **Name**: Users can view own files
- **Policy**: SELECT
- **Target roles**: authenticated
- **USING**: 
```sql
bucket_id = 'pdf-books'
AND auth.uid()::text = (storage.foldername(name))[1]
```

### Step 4: 验证设置

#### 运行完整性检查
```sql
-- 检查所有组件是否就绪
WITH checks AS (
    SELECT 'Extensions' as component,
           EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'vector') as status
    UNION ALL
    SELECT 'Books Table',
           EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'books')
    UNION ALL
    SELECT 'Knowledge Table',
           EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'knowledge_base')
    UNION ALL
    SELECT 'Search Function',
           EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'search_knowledge')
    UNION ALL
    SELECT 'RLS Enabled',
           EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'books' AND rowsecurity = true)
)
SELECT 
    component,
    CASE WHEN status THEN '✅ Ready' ELSE '❌ Missing' END as status
FROM checks;
```

**预期结果**：
```
component         | status
------------------|----------
Extensions        | ✅ Ready
Books Table       | ✅ Ready
Knowledge Table   | ✅ Ready
Search Function   | ✅ Ready
RLS Enabled       | ✅ Ready
```

## 🔧 故障排查

### 问题1：pgvector扩展安装失败
**解决方案**：
1. 确认Supabase项目是最新版本
2. 联系Supabase支持启用pgvector

### 问题2：RLS策略不生效
**解决方案**：
```sql
-- 重新启用RLS
ALTER TABLE books DISABLE ROW LEVEL SECURITY;
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
```

### 问题3：索引创建缓慢
**解决方案**：
- 对于大型数据集，考虑使用 `CONCURRENTLY` 选项
```sql
CREATE INDEX CONCURRENTLY idx_knowledge_embedding 
ON knowledge_base USING ivfflat (embedding vector_cosine_ops);
```

## 📊 性能优化建议

### 1. 向量索引优化
```sql
-- 调整lists参数（根据数据量）
-- 1000条数据: lists = 10
-- 10000条数据: lists = 100
-- 100000条数据: lists = 1000
DROP INDEX idx_knowledge_embedding;
CREATE INDEX idx_knowledge_embedding ON knowledge_base 
USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);  -- 根据实际数据量调整
```

### 2. 查询性能监控
```sql
-- 监控慢查询
SELECT 
    query,
    calls,
    mean_exec_time,
    total_exec_time
FROM pg_stat_statements
WHERE query LIKE '%knowledge_base%'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

## 🔐 安全建议

1. **定期备份**
   - 在Supabase控制台启用自动备份
   - 重要更新前手动创建备份

2. **监控配额**
   ```sql
   -- 监控存储使用
   SELECT 
       pg_size_pretty(pg_database_size(current_database())) as db_size,
       pg_size_pretty(pg_total_relation_size('knowledge_base')) as kb_table_size,
       pg_size_pretty(pg_total_relation_size('books')) as books_table_size;
   ```

3. **审计日志**
   - 启用Supabase的审计日志功能
   - 定期检查异常访问

## ✅ 完成确认清单

- [ ] pgvector扩展已启用
- [ ] 所有表已创建
- [ ] 所有函数已创建
- [ ] RLS策略已配置
- [ ] Storage桶已创建
- [ ] 存储策略已设置
- [ ] 完整性检查通过
- [ ] 团队成员已获取访问权限

## 📞 需要帮助？

如遇到问题，请：
1. 检查错误日志：Supabase Console > Logs
2. 查看文档：[Supabase Docs](https://supabase.com/docs)
3. 联系团队：在项目群组中@数据库管理员

---

*最后更新: 2025-01-11*  
*版本: 1.0*