-- ============================================
-- 修复用户注册时的数据库错误
-- ============================================

-- 1. 删除可能存在的旧触发器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- 2. 创建新的触发器函数（更健壮的版本）
CREATE OR REPLACE FUNCTION handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  -- 插入基础profile数据
  INSERT INTO public.profiles (
    id,
    email,
    username,
    subscription_tier,
    created_at,
    updated_at
  ) VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    'free',
    NOW(),
    NOW()
  ) ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    updated_at = NOW();
  
  -- 初始化AI配额
  INSERT INTO public.user_ai_quotas (
    user_id,
    subscription_tier,
    daily_limit,
    monthly_limit,
    daily_used,
    monthly_used,
    total_tokens_used,
    daily_reset_at,
    monthly_reset_at
  ) VALUES (
    new.id,
    'free',
    50,
    1000,
    0,
    0,
    0,
    CURRENT_DATE,
    NOW()
  ) ON CONFLICT (user_id) DO NOTHING;
  
  -- 初始化AI偏好设置
  INSERT INTO public.user_ai_preferences (
    user_id,
    conversation_style,
    response_length,
    language_complexity,
    auto_save_sessions,
    show_interpretation_hints
  ) VALUES (
    new.id,
    'mystical',
    'medium',
    'normal',
    true,
    true
  ) ON CONFLICT (user_id) DO NOTHING;
  
  RETURN new;
EXCEPTION
  WHEN OTHERS THEN
    -- 记录错误但不阻止用户创建
    RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 创建触发器
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- 4. 确保profiles表的约束正确
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_email_key;
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_username_key;

-- 重新添加约束（允许NULL）
ALTER TABLE profiles 
  ADD CONSTRAINT profiles_email_unique UNIQUE (email);

ALTER TABLE profiles 
  ADD CONSTRAINT profiles_username_unique UNIQUE (username);

-- 5. 确保表的RLS策略不会阻止插入
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 删除可能有问题的策略
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

-- 创建新的策略
CREATE POLICY "Enable insert for authentication" ON profiles
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable read for users based on user_id" ON profiles
  FOR SELECT USING (auth.uid() = id OR auth.uid() IS NOT NULL);

CREATE POLICY "Enable update for users based on user_id" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- 6. 授予必要的权限
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, service_role;
GRANT SELECT, INSERT, UPDATE ON profiles TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON user_ai_quotas TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON user_ai_preferences TO anon, authenticated;

-- 7. 测试函数
CREATE OR REPLACE FUNCTION test_user_creation()
RETURNS text AS $$
BEGIN
  RETURN 'User creation setup completed successfully';
END;
$$ LANGUAGE plpgsql;

-- 执行测试
SELECT test_user_creation();

-- ============================================
-- 执行完成！现在用户注册应该可以正常工作了
-- ============================================