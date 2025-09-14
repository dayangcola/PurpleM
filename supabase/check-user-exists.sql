-- 检查test@gmail.com用户是否存在于所有相关表中

-- 1. 检查auth.users表
SELECT 
    id,
    email,
    created_at
FROM auth.users 
WHERE id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1';

-- 2. 检查profiles表
SELECT 
    id,
    user_id,
    username,
    created_at
FROM profiles 
WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1';

-- 3. 如果不存在，创建profile
INSERT INTO profiles (user_id, username, email, created_at, updated_at)
SELECT 
    'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1',
    'test',
    'test@gmail.com',
    NOW(),
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
);

-- 4. 检查并修复user_ai_preferences重复问题
-- 先删除重复的记录，只保留最新的
DELETE FROM user_ai_preferences 
WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
AND id NOT IN (
    SELECT id FROM (
        SELECT id FROM user_ai_preferences 
        WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
        ORDER BY updated_at DESC 
        LIMIT 1
    ) AS latest
);

-- 5. 确保quotas存在
INSERT INTO user_ai_quotas (user_id, daily_limit, daily_used, created_at, updated_at)
SELECT 
    'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1',
    1000,
    0,
    NOW(),
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM user_ai_quotas 
    WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
);

-- 6. 显示最终状态
SELECT 
    'profiles' as table_name,
    COUNT(*) as count
FROM profiles 
WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
UNION ALL
SELECT 
    'user_ai_preferences',
    COUNT(*)
FROM user_ai_preferences 
WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
UNION ALL
SELECT 
    'user_ai_quotas',
    COUNT(*)
FROM user_ai_quotas 
WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1';