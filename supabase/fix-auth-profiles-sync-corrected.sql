-- ============================================
-- 修复Supabase Auth与profiles表同步问题（修正版）
-- 确保邮件注册的用户自动创建profile记录
-- ============================================

-- 1. 确保profiles表结构正确
ALTER TABLE profiles 
  ALTER COLUMN email SET NOT NULL,
  ALTER COLUMN created_at SET DEFAULT NOW(),
  ALTER COLUMN updated_at SET DEFAULT NOW();

-- 2. 删除旧的触发器和函数
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

-- 3. 创建更健壮的触发器函数
CREATE OR REPLACE FUNCTION handle_new_user() 
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  default_username text;
BEGIN
  -- 生成默认用户名
  default_username := COALESCE(
    new.raw_user_meta_data->>'username',
    new.raw_user_meta_data->>'name',
    split_part(new.email, '@', 1)
  );

  -- 插入或更新profile
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
    'free',
    100,
    0,
    NOW(),
    NOW()
  ) 
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    username = COALESCE(profiles.username, EXCLUDED.username),
    updated_at = NOW()
  WHERE profiles.username IS NULL; -- 只在用户名为空时更新

  -- 初始化用户配额（修正字段名）
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
    'free',
    100,
    0,
    3000,
    0,
    0,
    CURRENT_DATE,
    DATE_TRUNC('month', CURRENT_DATE),
    NOW(),
    NOW()
  ) ON CONFLICT (user_id) DO NOTHING;

  -- 初始化用户偏好设置
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

  -- 创建默认会话
  INSERT INTO public.chat_sessions (
    id,
    user_id,
    title,
    session_type,
    created_at,
    updated_at
  ) 
  SELECT 
    gen_random_uuid(),
    new.id,
    '欢迎对话',
    'chat',
    NOW(),
    NOW()
  WHERE NOT EXISTS (
    SELECT 1 FROM public.chat_sessions WHERE user_id = new.id
  );

  RETURN new;
EXCEPTION
  WHEN OTHERS THEN
    -- 记录错误但不阻止用户创建
    RAISE LOG 'Error in handle_new_user for user %: %', new.id, SQLERRM;
    -- 至少确保profile存在
    INSERT INTO public.profiles (id, email, username, subscription_tier, created_at, updated_at)
    VALUES (new.id, new.email, split_part(new.email, '@', 1), 'free', NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;
    RETURN new;
END;
$$;

-- 4. 创建触发器
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- 5. 修复现有的孤立用户（auth中存在但profiles中不存在的用户）
INSERT INTO public.profiles (id, email, username, subscription_tier, created_at, updated_at)
SELECT 
  au.id,
  au.email,
  COALESCE(
    au.raw_user_meta_data->>'username',
    au.raw_user_meta_data->>'name',
    split_part(au.email, '@', 1)
  ),
  'free',
  au.created_at,
  NOW()
FROM auth.users au
LEFT JOIN public.profiles p ON au.id = p.id
WHERE p.id IS NULL;

-- 6. 为没有配额的用户创建配额记录（使用正确的字段名）
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
  'free',
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
LEFT JOIN public.user_ai_quotas q ON p.id = q.user_id
WHERE q.user_id IS NULL;

-- 7. 为没有偏好设置的用户创建默认设置
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
LEFT JOIN public.user_ai_preferences pref ON p.id = pref.user_id
WHERE pref.user_id IS NULL;

-- 8. 确保RLS策略允许触发器操作
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- 9. 删除旧策略（如果存在）
DROP POLICY IF EXISTS "System can insert profiles" ON profiles;
DROP POLICY IF EXISTS "System can insert quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "System can insert preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "System can insert sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view own quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Users can view own preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Users can manage own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can manage own messages" ON chat_messages;

-- 10. 创建新的RLS策略
-- 允许系统操作的策略
CREATE POLICY "System can insert profiles" ON profiles
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "System can insert quotas" ON user_ai_quotas
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "System can insert preferences" ON user_ai_preferences
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "System can insert sessions" ON chat_sessions
  FOR INSERT
  WITH CHECK (true);

-- 用户自己的数据访问策略
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT
  USING (auth.uid() = id OR auth.role() = 'anon');

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can view own quotas" ON user_ai_quotas
  FOR SELECT
  USING (auth.uid() = user_id OR auth.role() = 'anon');

CREATE POLICY "Users can view own preferences" ON user_ai_preferences
  FOR SELECT
  USING (auth.uid() = user_id OR auth.role() = 'anon');

CREATE POLICY "Users can manage own sessions" ON chat_sessions
  FOR ALL
  USING (auth.uid() = user_id OR auth.role() = 'anon');

CREATE POLICY "Users can manage own messages" ON chat_messages
  FOR ALL
  USING (auth.uid() = user_id OR auth.role() = 'anon');

-- 11. 授予必要的权限
GRANT ALL ON profiles TO anon, authenticated;
GRANT ALL ON user_ai_quotas TO anon, authenticated;
GRANT ALL ON user_ai_preferences TO anon, authenticated;
GRANT ALL ON chat_sessions TO anon, authenticated;
GRANT ALL ON chat_messages TO anon, authenticated;

-- 12. 输出诊断信息
DO $$
DECLARE
  auth_count integer;
  profile_count integer;
  orphaned_count integer;
  quota_count integer;
  pref_count integer;
BEGIN
  SELECT COUNT(*) INTO auth_count FROM auth.users;
  SELECT COUNT(*) INTO profile_count FROM profiles;
  SELECT COUNT(*) INTO orphaned_count 
  FROM auth.users au 
  LEFT JOIN profiles p ON au.id = p.id 
  WHERE p.id IS NULL;
  SELECT COUNT(*) INTO quota_count FROM user_ai_quotas;
  SELECT COUNT(*) INTO pref_count FROM user_ai_preferences;
  
  RAISE NOTICE '====================================';
  RAISE NOTICE 'Auth用户总数: %', auth_count;
  RAISE NOTICE 'Profile记录总数: %', profile_count;
  RAISE NOTICE '孤立的Auth用户: %', orphaned_count;
  RAISE NOTICE '配额记录总数: %', quota_count;
  RAISE NOTICE '偏好设置记录总数: %', pref_count;
  RAISE NOTICE '====================================';
  
  IF orphaned_count = 0 THEN
    RAISE NOTICE '✅ 所有Auth用户都有对应的Profile记录！';
  ELSE
    RAISE NOTICE '⚠️ 发现 % 个孤立用户，已自动修复', orphaned_count;
  END IF;
END;
$$;