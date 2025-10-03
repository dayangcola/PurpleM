-- ================================================
-- 🔍 分步验证 - 一次执行一个查询
-- ================================================
-- 复制每个查询单独执行，确保能看到结果
-- ================================================

-- ==========================================
-- 查询1：检查扩展
-- ==========================================
SELECT 
    '扩展检查' as check_type,
    extname,
    extversion,
    CASE 
        WHEN extname = 'vector' THEN '✅ 向量搜索'
        WHEN extname = 'pg_trgm' THEN '✅ 文本搜索'
    END as status
FROM pg_extension 
WHERE extname IN ('vector', 'pg_trgm');

-- 预期：看到2行，vector和pg_trgm

-- ==========================================
-- 查询2：检查表和RLS
-- ==========================================
SELECT 
    '表检查' as check_type,
    tablename,
    hasindexes as has_indexes,
    rowsecurity as rls_enabled,
    CASE 
        WHEN rowsecurity THEN '✅ RLS已启用'
        ELSE '❌ RLS未启用'
    END as rls_status
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('books', 'knowledge_base');

-- 预期：看到2行，都应该显示RLS已启用

-- ==========================================
-- 查询3：检查索引数量
-- ==========================================
SELECT 
    '索引检查' as check_type,
    COUNT(*) as index_count,
    STRING_AGG(indexname, ', ') as index_names
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename IN ('books', 'knowledge_base');

-- 预期：index_count >= 6

-- ==========================================
-- 查询4：检查函数
-- ==========================================
SELECT 
    '函数检查' as check_type,
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

-- 预期：看到5个函数

-- ==========================================
-- 查询5：检查Storage策略
-- ==========================================
SELECT 
    '存储策略检查' as check_type,
    COUNT(*) as policy_count,
    STRING_AGG(policyname, ', ') as policy_names
FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects';

-- 预期：policy_count >= 3

-- ==========================================
-- 查询6：快速数据测试
-- ==========================================
DO $$
DECLARE
    test_result TEXT;
BEGIN
    -- 尝试插入测试数据
    BEGIN
        INSERT INTO books (title, author, user_id, processing_status)
        VALUES ('测试书_' || NOW()::text, '测试', auth.uid(), 'pending');
        
        DELETE FROM books WHERE title LIKE '测试书_%';
        
        test_result := '✅ 数据操作测试通过';
    EXCEPTION
        WHEN OTHERS THEN
            test_result := '❌ 数据操作失败: ' || SQLERRM;
    END;
    
    RAISE NOTICE '%', test_result;
END $$;

-- 预期：看到"数据操作测试通过"