-- ============================================
-- 紧急修复：Profile RLS策略问题
-- 问题：新用户注册后无法创建profile（401错误）
-- ============================================

-- 1. 先禁用RLS暂时解决问题（测试用）
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- 2. 重新启用RLS并创建正确的策略
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 删除所有旧策略
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "System can insert profiles" ON profiles;

-- 创建新的策略（更宽松，允许创建）
-- 允许任何已认证用户创建自己的profile
CREATE POLICY "Allow users to insert own profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 允许用户查看自己的profile
CREATE POLICY "Allow users to view own profile"
ON profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- 允许用户更新自己的profile
CREATE POLICY "Allow users to update own profile"
ON profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 允许服务端角色（service_role）完全访问
CREATE POLICY "Service role has full access"
ON profiles
TO service_role
USING (true)
WITH CHECK (true);

-- 验证策略
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
WHERE tablename = 'profiles';

-- 同样修复其他相关表
-- user_ai_quotas表
ALTER TABLE user_ai_quotas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Users can insert own quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Users can view own quotas" ON user_ai_quotas;

CREATE POLICY "Allow insert quotas"
ON user_ai_quotas FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow view quotas"
ON user_ai_quotas FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Allow update quotas"
ON user_ai_quotas FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- user_ai_preferences表
ALTER TABLE user_ai_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Users can insert own preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Users can view own preferences" ON user_ai_preferences;

CREATE POLICY "Allow insert preferences"
ON user_ai_preferences FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow view preferences"
ON user_ai_preferences FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Allow update preferences"
ON user_ai_preferences FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);