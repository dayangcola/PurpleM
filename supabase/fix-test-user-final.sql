-- 终极修复脚本 - 确保test@gmail.com用户的所有数据完整性
-- 请在Supabase SQL编辑器中运行此脚本

-- 1. 首先检查auth.users表中是否存在该用户
DO $$
DECLARE
    user_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM auth.users 
        WHERE id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
    ) INTO user_exists;
    
    IF NOT user_exists THEN
        RAISE NOTICE '用户不存在于auth.users表中，请先登录创建用户';
    ELSE
        RAISE NOTICE '用户存在于auth.users表中，继续修复';
    END IF;
END $$;

-- 2. 强制创建profile记录（如果不存在）
INSERT INTO profiles (user_id, username, email, created_at, updated_at)
VALUES (
    'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1',
    'test',
    'test@gmail.com',
    NOW(),
    NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
    updated_at = NOW();

-- 3. 创建或更新配额记录
INSERT INTO user_ai_quotas (user_id, daily_limit, daily_used, created_at, updated_at)
VALUES (
    'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1',
    1000,
    0,
    NOW(),
    NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
    daily_used = 0,
    updated_at = NOW();

-- 4. 删除重复的preferences记录（如果有）
DELETE FROM user_ai_preferences 
WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
AND id NOT IN (
    SELECT id FROM (
        SELECT id FROM user_ai_preferences 
        WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
        ORDER BY created_at DESC 
        LIMIT 1
    ) AS latest
);

-- 5. 确保有一条preferences记录
INSERT INTO user_ai_preferences (
    user_id,
    conversation_style,
    response_length,
    preferred_topics,
    enable_suggestions,
    created_at,
    updated_at
)
SELECT 
    'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1',
    'balanced',
    'medium',
    ARRAY['general'],
    true,
    NOW(),
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM user_ai_preferences 
    WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
);

-- 6. 验证修复结果
SELECT 
    'Auth User' as table_name,
    COUNT(*) as count,
    string_agg(email, ', ') as details
FROM auth.users 
WHERE id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
GROUP BY 1

UNION ALL

SELECT 
    'Profile' as table_name,
    COUNT(*) as count,
    string_agg(email, ', ') as details
FROM profiles 
WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
GROUP BY 1

UNION ALL

SELECT 
    'Quota' as table_name,
    COUNT(*) as count,
    'Daily limit: ' || MAX(daily_limit)::text as details
FROM user_ai_quotas 
WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
GROUP BY 1

UNION ALL

SELECT 
    'Preferences' as table_name,
    COUNT(*) as count,
    'Style: ' || MAX(conversation_style) as details
FROM user_ai_preferences 
WHERE user_id = 'b6e6ea91-9e1a-453f-8007-ea67a35bd5d1'
GROUP BY 1

ORDER BY 1;