-- 检查chat_sessions表的结构和约束
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM 
    information_schema.columns
WHERE 
    table_schema = 'public' 
    AND table_name = 'chat_sessions'
ORDER BY 
    ordinal_position;

-- 检查chat_sessions表的外键约束
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name as local_column,
    ccu.table_name AS foreign_table,
    ccu.column_name AS foreign_column
FROM 
    information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    LEFT JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE 
    tc.table_schema = 'public'
    AND tc.table_name = 'chat_sessions'
    AND tc.constraint_type = 'FOREIGN KEY';

-- 检查RLS策略
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename IN ('profiles', 'chat_sessions');

-- 测试：尝试用已存在的用户创建会话
-- 使用test9@gmail.com的ID
INSERT INTO chat_sessions (
    user_id,
    session_type,
    title,
    created_at,
    updated_at
)
VALUES (
    '6619aba9-2b7d-4664-8806-0dcc4a0caf5e',  -- test9@gmail.com的ID
    'general',
    'Test Session',
    NOW(),
    NOW()
)
RETURNING *;