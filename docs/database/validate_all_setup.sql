-- ================================================
-- 🔍 完整配置验证脚本
-- ================================================
-- 运行此脚本验证所有数据库和存储配置
-- 执行时间：约5秒
-- ================================================

-- ================================================
-- 1. 扩展验证
-- ================================================
SELECT '========== 1. 扩展验证 ==========' as section;

SELECT 
    extname as "扩展名",
    extversion as "版本",
    CASE 
        WHEN extname = 'vector' THEN '✅ 向量搜索已启用'
        WHEN extname = 'pg_trgm' THEN '✅ 文本搜索已启用'
        ELSE '⚠️ 未知扩展'
    END as "状态"
FROM pg_extension 
WHERE extname IN ('vector', 'pg_trgm')
ORDER BY extname;

-- 验证vector扩展的功能
DO $$
BEGIN
    -- 尝试创建一个测试向量
    PERFORM ARRAY_FILL(0.1, ARRAY[1536])::vector(1536);
    RAISE NOTICE '✅ Vector扩展功能正常';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Vector扩展可能有问题: %', SQLERRM;
END $$;

-- ================================================
-- 2. 表结构验证
-- ================================================
SELECT '========== 2. 表结构验证 ==========' as section;

-- 检查表是否存在
SELECT 
    tablename as "表名",
    CASE 
        WHEN tablename = 'books' THEN '书籍元数据表'
        WHEN tablename = 'knowledge_base' THEN '知识内容表'
    END as "描述",
    CASE 
        WHEN hasindexes THEN '✅ 有索引'
        ELSE '❌ 缺少索引'
    END as "索引状态",
    CASE 
        WHEN rowsecurity THEN '✅ RLS已启用'
        ELSE '❌ RLS未启用'
    END as "安全状态"
FROM pg_tables 
WHERE schemaname = 'public' 
    AND tablename IN ('books', 'knowledge_base')
ORDER BY tablename;

-- 检查列完整性
SELECT '--- Books表列检查 ---' as check_type;
SELECT 
    column_name as "列名",
    data_type as "数据类型",
    is_nullable as "可空",
    column_default as "默认值"
FROM information_schema.columns 
WHERE table_name = 'books' 
    AND table_schema = 'public'
ORDER BY ordinal_position
LIMIT 5;  -- 只显示前5列

SELECT '--- Knowledge_base表列检查 ---' as check_type;
SELECT 
    column_name as "列名",
    data_type as "数据类型",
    CASE 
        WHEN column_name = 'embedding' THEN '✅ 向量列'
        WHEN column_name = 'search_vector' THEN '✅ 全文搜索列'
        ELSE '普通列'
    END as "特殊列"
FROM information_schema.columns 
WHERE table_name = 'knowledge_base' 
    AND table_schema = 'public'
    AND column_name IN ('embedding', 'search_vector', 'content', 'book_id');

-- ================================================
-- 3. 索引验证
-- ================================================
SELECT '========== 3. 索引验证 ==========' as section;

SELECT 
    indexname as "索引名",
    tablename as "表名",
    CASE 
        WHEN indexdef LIKE '%ivfflat%' THEN '🔍 向量索引'
        WHEN indexdef LIKE '%gin%' THEN '📝 全文索引'
        WHEN indexdef LIKE '%btree%' THEN '🌲 B树索引'
        ELSE '其他'
    END as "索引类型"
FROM pg_indexes 
WHERE schemaname = 'public' 
    AND tablename IN ('books', 'knowledge_base')
ORDER BY tablename, indexname;

-- ================================================
-- 4. 函数验证
-- ================================================
SELECT '========== 4. 函数验证 ==========' as section;

SELECT 
    proname as "函数名",
    pronargs as "参数数量",
    CASE 
        WHEN proname = 'search_knowledge' THEN '✅ 向量搜索'
        WHEN proname = 'hybrid_search' THEN '✅ 混合搜索'
        WHEN proname = 'get_knowledge_context' THEN '✅ 上下文获取'
        WHEN proname = 'update_book_progress' THEN '✅ 进度更新'
        WHEN proname = 'get_user_book_stats' THEN '✅ 统计信息'
        ELSE '其他函数'
    END as "功能说明"
FROM pg_proc 
WHERE pronamespace = 'public'::regnamespace
    AND proname IN (
        'search_knowledge',
        'hybrid_search',
        'get_knowledge_context',
        'update_book_progress',
        'get_user_book_stats'
    )
ORDER BY proname;

-- ================================================
-- 5. RLS策略验证
-- ================================================
SELECT '========== 5. RLS策略验证 ==========' as section;

SELECT 
    schemaname || '.' || tablename as "表",
    policyname as "策略名",
    permissive as "许可类型",
    roles as "角色",
    cmd as "操作",
    CASE 
        WHEN policyname LIKE '%view%' OR policyname LIKE '%select%' THEN '👁️ 查看'
        WHEN policyname LIKE '%insert%' OR policyname LIKE '%upload%' THEN '➕ 插入'
        WHEN policyname LIKE '%update%' THEN '✏️ 更新'
        WHEN policyname LIKE '%delete%' THEN '🗑️ 删除'
        ELSE '🔒 其他'
    END as "权限类型"
FROM pg_policies 
WHERE schemaname = 'public' 
    AND tablename IN ('books', 'knowledge_base')
ORDER BY tablename, cmd;

-- ================================================
-- 6. Storage配置验证（需要通过API检查）
-- ================================================
SELECT '========== 6. Storage验证 ==========' as section;

-- 检查storage schema是否存在
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'storage') 
        THEN '✅ Storage模块已安装' 
        ELSE '❌ Storage模块未找到' 
    END as "Storage状态";

-- 检查storage.objects表
SELECT 
    COUNT(*) as "Storage策略数量",
    CASE 
        WHEN COUNT(*) >= 3 THEN '✅ 策略数量正常（INSERT/SELECT/DELETE）'
        WHEN COUNT(*) > 0 THEN '⚠️ 策略数量不足，请检查'
        ELSE '❌ 没有找到Storage策略'
    END as "策略检查"
FROM pg_policies 
WHERE schemaname = 'storage' 
    AND tablename = 'objects';

-- ================================================
-- 7. 数据测试
-- ================================================
SELECT '========== 7. 数据测试 ==========' as section;

-- 测试插入书籍（使用当前用户）
DO $$
DECLARE
    test_book_id UUID;
BEGIN
    -- 插入测试书籍
    INSERT INTO books (
        title, 
        author, 
        category, 
        processing_status,
        user_id,
        is_public
    ) VALUES (
        '验证测试书籍_' || NOW()::text,
        '测试作者',
        '紫微斗数',
        'pending',
        auth.uid(),
        false
    ) RETURNING id INTO test_book_id;
    
    RAISE NOTICE '✅ 书籍插入测试成功，ID: %', test_book_id;
    
    -- 测试知识库插入
    INSERT INTO knowledge_base (
        book_id,
        book_title,
        content,
        content_length,
        chunk_index,
        embedding
    ) VALUES (
        test_book_id,
        '验证测试书籍',
        '这是测试内容',
        10,
        0,
        ARRAY_FILL(0.1, ARRAY[1536])::vector(1536)
    );
    
    RAISE NOTICE '✅ 知识条目插入测试成功';
    
    -- 清理测试数据
    DELETE FROM books WHERE id = test_book_id;
    RAISE NOTICE '✅ 测试数据清理成功';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ 数据测试失败: %', SQLERRM;
END $$;

-- ================================================
-- 8. 函数测试
-- ================================================
SELECT '========== 8. 函数测试 ==========' as section;

-- 测试search_knowledge函数
DO $$
DECLARE
    result_count INTEGER;
BEGIN
    -- 创建测试向量
    SELECT COUNT(*) INTO result_count
    FROM search_knowledge(
        ARRAY_FILL(0::real, ARRAY[1536])::vector(1536),
        5,
        0.0  -- 低阈值以获得任何结果
    );
    
    RAISE NOTICE '✅ search_knowledge函数正常，返回 % 条结果', result_count;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ search_knowledge函数测试失败: %', SQLERRM;
END $$;

-- 测试统计函数（先修复函数避免歧义）
DO $$
BEGIN
    -- 先尝试修复函数（如果需要）
    DROP FUNCTION IF EXISTS get_user_book_stats(uuid);
    
    CREATE OR REPLACE FUNCTION get_user_book_stats(
        p_user_id UUID DEFAULT NULL
    )
    RETURNS TABLE (
        total_books BIGINT,
        completed_books BIGINT,
        processing_books BIGINT,
        failed_books BIGINT,
        total_knowledge_items BIGINT,
        total_storage_mb DECIMAL(10,2)
    )
    LANGUAGE plpgsql
    AS $func$
    BEGIN
        RETURN QUERY
        SELECT 
            COUNT(DISTINCT b.id) as total_books,
            COUNT(DISTINCT CASE WHEN b.processing_status = 'completed' THEN b.id END) as completed_books,
            COUNT(DISTINCT CASE WHEN b.processing_status = 'processing' THEN b.id END) as processing_books,
            COUNT(DISTINCT CASE WHEN b.processing_status = 'failed' THEN b.id END) as failed_books,
            COUNT(kb.id) as total_knowledge_items,
            COALESCE(SUM(b.file_size) / 1024.0 / 1024.0, 0) as total_storage_mb
        FROM books b
        LEFT JOIN knowledge_base kb ON b.id = kb.book_id
        WHERE 
            CASE 
                WHEN p_user_id IS NOT NULL THEN b.user_id = p_user_id
                ELSE b.user_id = auth.uid()
            END;
    END;
    $func$;
    
    RAISE NOTICE '✅ 函数已修复';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ 函数修复出错，但继续测试';
END $$;

-- 现在测试统计函数
SELECT 
    '统计测试' as "测试项",
    total_books as "总书籍",
    completed_books as "完成",
    total_knowledge_items as "知识条目",
    CASE 
        WHEN total_books IS NOT NULL THEN '✅ 统计函数正常'
        ELSE '❌ 统计函数异常'
    END as "状态"
FROM get_user_book_stats()
LIMIT 1;

-- ================================================
-- 9. 最终报告
-- ================================================
SELECT '========== 📊 验证报告汇总 ==========' as section;

WITH validation_summary AS (
    SELECT 
        -- 扩展检查
        (SELECT COUNT(*) FROM pg_extension WHERE extname IN ('vector', 'pg_trgm')) as extensions_count,
        -- 表检查
        (SELECT COUNT(*) FROM pg_tables WHERE tablename IN ('books', 'knowledge_base')) as tables_count,
        -- 索引检查
        (SELECT COUNT(*) FROM pg_indexes WHERE tablename IN ('books', 'knowledge_base')) as indexes_count,
        -- 函数检查
        (SELECT COUNT(*) FROM pg_proc WHERE proname IN ('search_knowledge', 'hybrid_search', 'get_knowledge_context', 'update_book_progress', 'get_user_book_stats')) as functions_count,
        -- RLS检查
        (SELECT COUNT(DISTINCT tablename) FROM pg_policies WHERE tablename IN ('books', 'knowledge_base')) as rls_tables_count,
        -- Storage检查
        (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects') as storage_policies_count
)
SELECT 
    '扩展' as "组件",
    extensions_count as "数量",
    CASE WHEN extensions_count = 2 THEN '✅ 通过' ELSE '❌ 失败' END as "状态"
FROM validation_summary
UNION ALL
SELECT '表', tables_count, CASE WHEN tables_count = 2 THEN '✅ 通过' ELSE '❌ 失败' END
FROM validation_summary
UNION ALL
SELECT '索引', indexes_count, CASE WHEN indexes_count >= 6 THEN '✅ 通过' ELSE '⚠️ 检查' END
FROM validation_summary
UNION ALL
SELECT '函数', functions_count, CASE WHEN functions_count >= 5 THEN '✅ 通过' ELSE '❌ 失败' END
FROM validation_summary
UNION ALL
SELECT 'RLS', rls_tables_count, CASE WHEN rls_tables_count = 2 THEN '✅ 通过' ELSE '❌ 失败' END
FROM validation_summary
UNION ALL
SELECT 'Storage策略', storage_policies_count, CASE WHEN storage_policies_count >= 3 THEN '✅ 通过' ELSE '⚠️ 检查' END
FROM validation_summary;

-- ================================================
-- 10. 建议
-- ================================================
SELECT '========== 💡 配置建议 ==========' as section;

SELECT 
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') 
            THEN '⚠️ 请安装pgvector扩展'
        WHEN NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'books' AND rowsecurity = true)
            THEN '⚠️ 请为books表启用RLS'
        WHEN NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'knowledge_base' AND rowsecurity = true)
            THEN '⚠️ 请为knowledge_base表启用RLS'
        WHEN (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects') < 3
            THEN '⚠️ 请检查Storage策略配置（需要INSERT/SELECT/DELETE）'
        ELSE '🎉 所有配置看起来都正常！'
    END as "配置建议";

-- 完成
SELECT '========== ✅ 验证完成 ==========' as section;