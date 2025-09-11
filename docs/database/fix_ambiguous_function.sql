-- ================================================
-- 修复 get_user_book_stats 函数的歧义问题
-- ================================================
-- 问题：参数名 user_id 与表列名冲突
-- 解决：使用参数前缀 p_ 来区分
-- ================================================

-- 删除旧函数
DROP FUNCTION IF EXISTS get_user_book_stats(uuid);

-- 重新创建函数（修复歧义）
CREATE OR REPLACE FUNCTION get_user_book_stats(
    p_user_id UUID DEFAULT NULL  -- 添加 p_ 前缀避免歧义
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
AS $$
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
            WHEN p_user_id IS NOT NULL THEN b.user_id = p_user_id  -- 使用 p_user_id
            ELSE b.user_id = auth.uid()
        END;
END;
$$;

-- 添加注释
COMMENT ON FUNCTION get_user_book_stats IS '获取用户的书籍统计信息（修复了参数歧义）';

-- 验证修复
DO $$
BEGIN
    PERFORM * FROM get_user_book_stats();
    RAISE NOTICE '✅ 函数 get_user_book_stats 已修复并验证成功';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ 函数修复失败: %', SQLERRM;
END $$;

-- 测试函数
SELECT 
    '函数测试' as test_type,
    total_books,
    completed_books,
    total_knowledge_items,
    CASE 
        WHEN total_books IS NOT NULL THEN '✅ 函数正常工作'
        ELSE '❌ 函数返回NULL'
    END as status
FROM get_user_book_stats()
LIMIT 1;