-- 修复Auth触发器，确保新用户注册时自动创建所有必需的记录
-- 在Supabase SQL编辑器中运行此脚本

-- 1. 先为新用户创建profile记录
INSERT INTO profiles (user_id, username, email, created_at, updated_at)
SELECT 
    id,
    COALESCE(raw_user_meta_data->>'username', split_part(email, '@', 1)),
    email,
    created_at,
    NOW()
FROM auth.users
WHERE NOT EXISTS (
    SELECT 1 FROM profiles WHERE profiles.user_id = auth.users.id
);

-- 2. 为所有没有quota的用户创建quota记录
INSERT INTO user_ai_quotas (user_id, daily_limit, daily_used, created_at, updated_at)
SELECT 
    p.user_id,
    100,  -- 默认每日限额
    0,
    NOW(),
    NOW()
FROM profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM user_ai_quotas q WHERE q.user_id = p.user_id
);

-- 3. 为所有没有preferences的用户创建preferences记录
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
    p.user_id,
    'balanced',
    'medium',
    ARRAY['general'],
    true,
    NOW(),
    NOW()
FROM profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM user_ai_preferences pref WHERE pref.user_id = p.user_id
);

-- 4. 创建或更新触发器函数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
    -- 创建profile记录
    INSERT INTO public.profiles (user_id, username, email, created_at, updated_at)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
        new.email,
        NOW(),
        NOW()
    );
    
    -- 创建quota记录
    INSERT INTO public.user_ai_quotas (user_id, daily_limit, daily_used, created_at, updated_at)
    VALUES (
        new.id,
        100,  -- 默认每日限额
        0,
        NOW(),
        NOW()
    );
    
    -- 创建preferences记录
    INSERT INTO public.user_ai_preferences (
        user_id,
        conversation_style,
        response_length,
        preferred_topics,
        enable_suggestions,
        created_at,
        updated_at
    )
    VALUES (
        new.id,
        'balanced',
        'medium',
        ARRAY['general'],
        true,
        NOW(),
        NOW()
    );
    
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. 删除旧触发器（如果存在）
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 6. 创建新触发器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 7. 验证所有用户都有完整的记录
SELECT 
    'Total Auth Users' as metric,
    COUNT(*) as count
FROM auth.users

UNION ALL

SELECT 
    'Profiles Created',
    COUNT(*)
FROM profiles

UNION ALL

SELECT 
    'Quotas Created',
    COUNT(*)
FROM user_ai_quotas

UNION ALL

SELECT 
    'Preferences Created',
    COUNT(*)
FROM user_ai_preferences

UNION ALL

-- 检查是否有用户缺少profile
SELECT 
    'Users Missing Profile',
    COUNT(*)
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM profiles p WHERE p.user_id = u.id
)

UNION ALL

-- 检查是否有profile缺少quota
SELECT 
    'Profiles Missing Quota',
    COUNT(*)
FROM profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM user_ai_quotas q WHERE q.user_id = p.user_id
)

UNION ALL

-- 检查是否有profile缺少preferences
SELECT 
    'Profiles Missing Preferences',
    COUNT(*)
FROM profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM user_ai_preferences pref WHERE pref.user_id = p.user_id
);

-- 8. 显示新用户的详细信息
SELECT 
    u.id,
    u.email,
    p.user_id as profile_user_id,
    q.daily_limit as quota_limit,
    pref.conversation_style as pref_style
FROM auth.users u
LEFT JOIN profiles p ON u.id = p.user_id
LEFT JOIN user_ai_quotas q ON u.id = q.user_id
LEFT JOIN user_ai_preferences pref ON u.id = pref.user_id
WHERE u.email = 'test9@gmail.com';