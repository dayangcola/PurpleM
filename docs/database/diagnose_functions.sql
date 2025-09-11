-- ================================================
-- 函数诊断和清理脚本
-- ================================================
-- 用于诊断和解决函数重复问题
-- ================================================

-- 1. 查看所有同名函数及其参数
SELECT 
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    p.pronargs as arg_count,
    p.oid as function_oid
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND p.proname IN (
        'search_knowledge',
        'hybrid_search',
        'get_knowledge_context',
        'update_book_progress',
        'get_user_book_stats',
        'generate_pdf_path',
        'get_pdf_public_url'
    )
ORDER BY p.proname, p.pronargs;

-- 2. 如果看到重复函数，使用以下命令删除特定版本
-- 示例：删除特定参数签名的函数
/*
-- 查看search_knowledge的所有版本
SELECT 
    'DROP FUNCTION ' || proname || '(' || pg_get_function_identity_arguments(oid) || ');' as drop_command
FROM pg_proc
WHERE proname = 'search_knowledge';

-- 复制上面查询的结果并执行需要删除的版本
*/

-- 3. 一键清理所有版本（谨慎使用）
DO $$
DECLARE
    func_record RECORD;
    drop_count INTEGER := 0;
BEGIN
    -- 遍历所有目标函数
    FOR func_record IN 
        SELECT 
            p.proname,
            pg_get_function_identity_arguments(p.oid) as args,
            p.oid
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
            AND p.proname IN (
                'search_knowledge',
                'hybrid_search',
                'get_knowledge_context',
                'update_book_progress',
                'get_user_book_stats',
                'generate_pdf_path',
                'get_pdf_public_url'
            )
    LOOP
        -- 构建并执行DROP命令
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_record.proname || '(' || func_record.args || ') CASCADE';
        drop_count := drop_count + 1;
        RAISE NOTICE '删除函数: % (%)', func_record.proname, func_record.args;
    END LOOP;
    
    RAISE NOTICE '✅ 总共删除了 % 个函数', drop_count;
END $$;

-- 4. 验证清理结果
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ 所有旧函数已清理'
        ELSE '⚠️ 还有 ' || COUNT(*) || ' 个函数存在'
    END as status,
    STRING_AGG(DISTINCT proname, ', ') as remaining_functions
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND p.proname IN (
        'search_knowledge',
        'hybrid_search',
        'get_knowledge_context',
        'update_book_progress',
        'get_user_book_stats',
        'generate_pdf_path',
        'get_pdf_public_url'
    );

-- 5. 清理后，执行03_create_functions_safe.sql创建新函数