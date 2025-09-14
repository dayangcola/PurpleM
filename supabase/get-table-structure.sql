-- ============================================
-- 获取所有表的完整结构
-- 运行此SQL可以查看所有表的字段名和类型
-- ============================================

-- 获取profiles表结构
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 获取star_charts表结构
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'star_charts'
ORDER BY ordinal_position;

-- 获取user_ai_quotas表结构
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'user_ai_quotas'
ORDER BY ordinal_position;

-- 获取user_ai_preferences表结构
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'user_ai_preferences'
ORDER BY ordinal_position;

-- 获取chat_sessions表结构
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'chat_sessions'
ORDER BY ordinal_position;

-- 获取chat_messages表结构
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'chat_messages'
ORDER BY ordinal_position;

-- 或者，使用一个查询获取所有表的结构
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name IN ('profiles', 'star_charts', 'user_ai_quotas', 
                   'user_ai_preferences', 'chat_sessions', 'chat_messages')
ORDER BY table_name, ordinal_position;