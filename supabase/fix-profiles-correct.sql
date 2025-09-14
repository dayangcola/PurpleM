-- 修复脚本 - 使用正确的profiles表结构
-- profiles表使用id作为主键（同时也是auth.users的外键）

-- 1. 为所有Auth用户创建profile记录（如果不存在）
INSERT INTO profiles (id, username, email, created_at, updated_at)
SELECT 
    au.id,
    COALESCE(au.raw_user_meta_data->>'username', split_part(au.email, '@', 1)),
    au.email,
    au.created_at,
    NOW()
FROM auth.users au
WHERE NOT EXISTS (
    SELECT 1 FROM profiles p WHERE p.id = au.id
)
ON CONFLICT (id) DO NOTHING;

-- 2. 为所有profiles创建quota记录（如果不存在）
INSERT INTO user_ai_quotas (user_id, daily_limit, daily_used, created_at, updated_at)
SELECT 
    p.id,
    100,  -- 默认每日限额
    0,
    NOW(),
    NOW()
FROM profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM user_ai_quotas q WHERE q.user_id = p.id
)
ON CONFLICT (user_id) DO NOTHING;

-- 3. 为所有profiles创建preferences记录（如果不存在）
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
    p.id,
    'balanced',
    'medium',
    ARRAY['general'],
    true,
    NOW(),
    NOW()
FROM profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM user_ai_preferences pref WHERE pref.user_id = p.id
)
ON CONFLICT (user_id) DO NOTHING;

-- 4. 创建或更新触发器函数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
    -- 创建profile记录（使用id而不是user_id）
    INSERT INTO public.profiles (id, username, email, created_at, updated_at)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
        new.email,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;
    
    -- 创建quota记录
    INSERT INTO public.user_ai_quotas (user_id, daily_limit, daily_used, created_at, updated_at)
    VALUES (
        new.id,
        100,  -- 默认每日限额
        0,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO NOTHING;
    
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
    )
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. 删除旧触发器（如果存在）
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 6. 创建新触发器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 7. 验证修复结果
SELECT 
    'Auth Users' as category,
    COUNT(*) as total,
    COUNT(CASE WHEN p.id IS NOT NULL THEN 1 END) as has_profile,
    COUNT(CASE WHEN q.user_id IS NOT NULL THEN 1 END) as has_quota,
    COUNT(CASE WHEN pref.user_id IS NOT NULL THEN 1 END) as has_preferences
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
LEFT JOIN user_ai_quotas q ON au.id = q.user_id
LEFT JOIN user_ai_preferences pref ON au.id = pref.user_id;

-- 8. 显示所有用户的详细状态
SELECT 
    au.email,
    au.id,
    CASE WHEN p.id IS NOT NULL THEN '✅' ELSE '❌' END as profile,
    CASE WHEN q.user_id IS NOT NULL THEN '✅' ELSE '❌' END as quota,
    CASE WHEN pref.user_id IS NOT NULL THEN '✅' ELSE '❌' END as preferences
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
LEFT JOIN user_ai_quotas q ON au.id = q.user_id
LEFT JOIN user_ai_preferences pref ON au.id = pref.user_id
ORDER BY au.created_at DESC;