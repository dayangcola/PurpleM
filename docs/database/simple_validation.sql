-- ================================================
-- 📋 简化验证脚本 - 确保能看到所有结果
-- ================================================
-- 分步执行，每步都能看到结果
-- ================================================

-- ▶️ 步骤1：基础组件检查
WITH system_check AS (
    SELECT 
        -- 扩展检查
        (SELECT COUNT(*) FROM pg_extension WHERE extname IN ('vector', 'pg_trgm')) as ext_count,
        -- 表检查
        (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('books', 'knowledge_base')) as table_count,
        -- 索引检查
        (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('books', 'knowledge_base')) as index_count,
        -- 函数检查
        (SELECT COUNT(*) FROM pg_proc WHERE proname IN ('search_knowledge', 'hybrid_search', 'get_knowledge_context', 'update_book_progress', 'get_user_book_stats')) as func_count,
        -- RLS检查
        (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('books', 'knowledge_base') AND rowsecurity = true) as rls_count,
        -- Storage策略检查
        (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects') as storage_count
)
SELECT 
    '1. 扩展 (需要2)' as "检查项",
    ext_count as "实际",
    CASE WHEN ext_count = 2 THEN '✅' ELSE '❌' END as "状态"
FROM system_check
UNION ALL
SELECT 
    '2. 表 (需要2)',
    table_count,
    CASE WHEN table_count = 2 THEN '✅' ELSE '❌' END
FROM system_check
UNION ALL
SELECT 
    '3. 索引 (需要≥6)',
    index_count,
    CASE WHEN index_count >= 6 THEN '✅' ELSE '❌' END
FROM system_check
UNION ALL
SELECT 
    '4. 函数 (需要5)',
    func_count,
    CASE WHEN func_count >= 5 THEN '✅' ELSE '❌' END
FROM system_check
UNION ALL
SELECT 
    '5. RLS (需要2)',
    rls_count,
    CASE WHEN rls_count = 2 THEN '✅' ELSE '❌' END
FROM system_check
UNION ALL
SELECT 
    '6. Storage策略 (需要≥3)',
    storage_count,
    CASE WHEN storage_count >= 3 THEN '✅' ELSE '⚠️' END
FROM system_check
ORDER BY 1;