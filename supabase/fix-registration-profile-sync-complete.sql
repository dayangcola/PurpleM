-- ============================================
-- 完整修复用户注册Profile同步问题
-- 运行此脚本在Supabase SQL编辑器中
-- 作者：PurpleM Team
-- 日期：2025-09-13
-- ============================================

-- ============================================
-- 第一部分：修复现有孤立用户数据
-- ============================================

-- 1.1 为所有auth.users中存在但profiles中不存在的用户创建profile
INSERT INTO public.profiles (
    id,
    email,
    username,
    subscription_tier,
    quota_limit,
    quota_used,
    created_at,
    updated_at
)
SELECT 
    au.id,
    au.email,
    COALESCE(
        au.raw_user_meta_data->>'username',
        au.raw_user_meta_data->>'name',
        split_part(au.email, '@', 1)
    ) as username,
    'free' as subscription_tier,
    100 as quota_limit,
    0 as quota_used,
    COALESCE(au.created_at, NOW()) as created_at,
    NOW() as updated_at
FROM auth.users au
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = au.id
);

-- 1.2 为所有有profile但缺少user_ai_quotas的用户创建配额记录
INSERT INTO public.user_ai_quotas (
    user_id,
    subscription_tier,
    daily_limit,
    daily_used,
    monthly_limit,
    monthly_used,
    total_tokens_used,
    daily_reset_at,
    monthly_reset_at,
    created_at,
    updated_at
)
SELECT 
    p.id,
    COALESCE(p.subscription_tier, 'free'),
    100,
    0,
    3000,
    0,
    0,
    CURRENT_DATE,
    DATE_TRUNC('month', CURRENT_DATE),
    NOW(),
    NOW()
FROM public.profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_ai_quotas q WHERE q.user_id = p.id
)
ON CONFLICT (user_id) DO NOTHING;

-- 1.3 为所有有profile但缺少user_ai_preferences的用户创建偏好设置
INSERT INTO public.user_ai_preferences (
    user_id,
    conversation_style,
    response_length,
    enable_suggestions,
    created_at,
    updated_at
)
SELECT 
    p.id,
    'balanced',
    'medium',
    true,
    NOW(),
    NOW()
FROM public.profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_ai_preferences pref WHERE pref.user_id = p.id
)
ON CONFLICT (user_id) DO NOTHING;

-- ============================================
-- 第二部分：重建触发器函数（更健壮的版本）
-- ============================================

-- 2.1 删除旧的触发器和函数
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- 2.2 创建新的触发器函数（带完整错误处理）
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    default_username text;
    default_subscription text := 'free';
    default_quota_limit integer := 100;
BEGIN
    -- 生成默认用户名
    default_username := COALESCE(
        new.raw_user_meta_data->>'username',
        new.raw_user_meta_data->>'name',
        split_part(new.email, '@', 1),
        'user_' || substr(new.id::text, 1, 8)
    );

    -- 创建或更新profile记录
    INSERT INTO public.profiles (
        id,
        email,
        username,
        subscription_tier,
        quota_limit,
        quota_used,
        created_at,
        updated_at
    ) VALUES (
        new.id,
        new.email,
        default_username,
        default_subscription,
        default_quota_limit,
        0,
        NOW(),
        NOW()
    ) 
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        username = COALESCE(profiles.username, EXCLUDED.username),
        updated_at = NOW()
    WHERE profiles.username IS NULL;

    -- 创建配额记录
    INSERT INTO public.user_ai_quotas (
        user_id,
        subscription_tier,
        daily_limit,
        daily_used,
        monthly_limit,
        monthly_used,
        total_tokens_used,
        daily_reset_at,
        monthly_reset_at,
        created_at,
        updated_at
    ) VALUES (
        new.id,
        default_subscription,
        default_quota_limit,
        0,
        3000,
        0,
        0,
        CURRENT_DATE,
        DATE_TRUNC('month', CURRENT_DATE),
        NOW(),
        NOW()
    ) ON CONFLICT (user_id) DO NOTHING;

    -- 创建偏好设置记录
    INSERT INTO public.user_ai_preferences (
        user_id,
        conversation_style,
        response_length,
        enable_suggestions,
        created_at,
        updated_at
    ) VALUES (
        new.id,
        'balanced',
        'medium',
        true,
        NOW(),
        NOW()
    ) ON CONFLICT (user_id) DO NOTHING;

    -- 创建默认聊天会话
    INSERT INTO public.chat_sessions (
        id,
        user_id,
        title,
        session_type,
        is_archived,
        created_at,
        updated_at
    )
    SELECT 
        gen_random_uuid(),
        new.id,
        '欢迎使用PurpleM',
        'general',
        false,
        NOW(),
        NOW()
    WHERE NOT EXISTS (
        SELECT 1 FROM public.chat_sessions WHERE user_id = new.id
    );

    -- 记录成功日志
    RAISE LOG 'Successfully created profile for user %', new.id;
    
    RETURN new;

EXCEPTION
    WHEN unique_violation THEN
        -- 唯一约束冲突，记录但不抛出错误
        RAISE LOG 'Profile already exists for user %', new.id;
        RETURN new;
    WHEN OTHERS THEN
        -- 记录错误但不阻止用户创建
        RAISE LOG 'Error in handle_new_user for user %: %', new.id, SQLERRM;
        
        -- 尝试至少创建最基本的profile记录
        BEGIN
            INSERT INTO public.profiles (id, email, username, subscription_tier, created_at, updated_at)
            VALUES (new.id, new.email, split_part(new.email, '@', 1), 'free', NOW(), NOW())
            ON CONFLICT (id) DO NOTHING;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE LOG 'Failed to create basic profile for user %: %', new.id, SQLERRM;
        END;
        
        RETURN new;
END;
$$;

-- 2.3 创建新的触发器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 第三部分：验证和统计
-- ============================================

-- 3.1 显示修复前后的统计信息
WITH stats AS (
    SELECT 
        'Total Auth Users' as metric,
        COUNT(*) as count
    FROM auth.users
    
    UNION ALL
    
    SELECT 
        'Profiles Created',
        COUNT(*)
    FROM public.profiles
    
    UNION ALL
    
    SELECT 
        'AI Quotas Created',
        COUNT(*)
    FROM public.user_ai_quotas
    
    UNION ALL
    
    SELECT 
        'AI Preferences Created',
        COUNT(*)
    FROM public.user_ai_preferences
    
    UNION ALL
    
    SELECT 
        'Chat Sessions Created',
        COUNT(*)
    FROM public.chat_sessions
    
    UNION ALL
    
    SELECT 
        'Users Missing Profile',
        COUNT(*)
    FROM auth.users u
    WHERE NOT EXISTS (
        SELECT 1 FROM public.profiles p WHERE p.id = u.id
    )
    
    UNION ALL
    
    SELECT 
        'Profiles Missing Quota',
        COUNT(*)
    FROM public.profiles p
    WHERE NOT EXISTS (
        SELECT 1 FROM public.user_ai_quotas q WHERE q.user_id = p.id
    )
    
    UNION ALL
    
    SELECT 
        'Profiles Missing Preferences',
        COUNT(*)
    FROM public.profiles p
    WHERE NOT EXISTS (
        SELECT 1 FROM public.user_ai_preferences pref WHERE pref.user_id = p.id
    )
)
SELECT * FROM stats ORDER BY metric;

-- 3.2 列出最近创建的用户及其Profile状态
SELECT 
    u.id,
    u.email,
    u.created_at as user_created,
    p.id as profile_id,
    p.username,
    p.subscription_tier,
    q.daily_limit as quota_limit,
    pref.conversation_style,
    CASE 
        WHEN p.id IS NULL THEN '❌ Missing Profile'
        WHEN q.user_id IS NULL THEN '⚠️ Missing Quota'
        WHEN pref.user_id IS NULL THEN '⚠️ Missing Preferences'
        ELSE '✅ Complete'
    END as status
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.user_ai_quotas q ON u.id = q.user_id
LEFT JOIN public.user_ai_preferences pref ON u.id = pref.user_id
ORDER BY u.created_at DESC
LIMIT 10;

-- ============================================
-- 第四部分：测试触发器（可选）
-- ============================================

-- 4.1 如果需要测试触发器，可以取消下面的注释并运行
-- 注意：这会创建一个测试用户
/*
-- 创建测试用户
INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    raw_user_meta_data
) VALUES (
    gen_random_uuid(),
    'trigger_test_' || extract(epoch from now())::text || '@test.com',
    crypt('TestPassword123!', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    jsonb_build_object('username', 'trigger_test_user')
);

-- 验证触发器是否工作
SELECT 
    u.email,
    p.username,
    q.daily_limit,
    pref.conversation_style
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.user_ai_quotas q ON u.id = q.user_id
LEFT JOIN public.user_ai_preferences pref ON u.id = pref.user_id
WHERE u.email LIKE 'trigger_test_%'
ORDER BY u.created_at DESC
LIMIT 1;
*/

-- ============================================
-- 完成！
-- 请在Supabase SQL编辑器中运行此脚本
-- 运行后检查统计信息确认修复成功
-- ============================================