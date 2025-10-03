-- ============================================
-- 修复跨设备同步问题 - 完整RLS策略重置
-- 问题：换设备登录时Profile无法创建（401错误）
-- 日期：2025-09-13
-- ============================================

-- ============================================
-- 1. PROFILES表 - 最关键的修复
-- ============================================

-- 先删除所有旧策略
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Allow users to insert own profile" ON profiles;
DROP POLICY IF EXISTS "Allow users to view own profile" ON profiles;
DROP POLICY IF EXISTS "Allow users to update own profile" ON profiles;
DROP POLICY IF EXISTS "Service role has full access" ON profiles;

-- 临时禁用RLS以确保没有阻塞
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- 重新启用RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 创建新的、更宽松的策略
-- 1. 允许已认证用户创建或更新自己的profile（使用UPSERT友好的策略）
CREATE POLICY "Enable insert for authenticated users"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (
    -- 用户只能创建自己的profile
    auth.uid() = id
);

-- 2. 允许用户查看自己的profile
CREATE POLICY "Enable select for users"
ON profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- 3. 允许用户更新自己的profile
CREATE POLICY "Enable update for users"
ON profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 4. 允许用户删除自己的profile（如果需要）
CREATE POLICY "Enable delete for users"
ON profiles FOR DELETE
TO authenticated
USING (auth.uid() = id);

-- ============================================
-- 2. USER_AI_QUOTAS表
-- ============================================

DROP POLICY IF EXISTS "Users can manage own quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Users can insert own quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Users can view own quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Allow insert quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Allow view quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Allow update quotas" ON user_ai_quotas;

ALTER TABLE user_ai_quotas ENABLE ROW LEVEL SECURITY;

-- 允许插入
CREATE POLICY "Enable insert quotas"
ON user_ai_quotas FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 允许查看
CREATE POLICY "Enable select quotas"
ON user_ai_quotas FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 允许更新
CREATE POLICY "Enable update quotas"
ON user_ai_quotas FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 3. USER_AI_PREFERENCES表
-- ============================================

DROP POLICY IF EXISTS "Users can manage own preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Users can insert own preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Users can view own preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Allow insert preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Allow view preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Allow update preferences" ON user_ai_preferences;

ALTER TABLE user_ai_preferences ENABLE ROW LEVEL SECURITY;

-- 允许插入
CREATE POLICY "Enable insert preferences"
ON user_ai_preferences FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 允许查看
CREATE POLICY "Enable select preferences"
ON user_ai_preferences FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 允许更新
CREATE POLICY "Enable update preferences"
ON user_ai_preferences FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 4. STAR_CHARTS表
-- ============================================

DROP POLICY IF EXISTS "Users can manage own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can insert own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can view own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can update own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can delete own charts" ON star_charts;

ALTER TABLE star_charts ENABLE ROW LEVEL SECURITY;

-- 允许插入
CREATE POLICY "Enable insert charts"
ON star_charts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 允许查看
CREATE POLICY "Enable select charts"
ON star_charts FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 允许更新
CREATE POLICY "Enable update charts"
ON star_charts FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 允许删除
CREATE POLICY "Enable delete charts"
ON star_charts FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ============================================
-- 5. CHAT_SESSIONS表
-- ============================================

DROP POLICY IF EXISTS "Users can manage own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can insert own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can view own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can update own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can delete own sessions" ON chat_sessions;

ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable insert sessions"
ON chat_sessions FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable select sessions"
ON chat_sessions FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Enable update sessions"
ON chat_sessions FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable delete sessions"
ON chat_sessions FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ============================================
-- 6. CHAT_MESSAGES表
-- ============================================

DROP POLICY IF EXISTS "Users can manage own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can insert own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can view own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can update own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can delete own messages" ON chat_messages;

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable insert messages"
ON chat_messages FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable select messages"
ON chat_messages FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Enable update messages"
ON chat_messages FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable delete messages"
ON chat_messages FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ============================================
-- 7. 验证所有策略
-- ============================================

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE schemaname = 'public'
AND tablename IN ('profiles', 'user_ai_quotas', 'user_ai_preferences', 
                   'star_charts', 'chat_sessions', 'chat_messages')
ORDER BY tablename, policyname;

-- ============================================
-- 8. 测试查询（确保当前用户可以访问自己的数据）
-- ============================================

-- 测试profiles表访问
SELECT COUNT(*) as profile_count FROM profiles WHERE id = auth.uid();

-- 测试其他表
SELECT COUNT(*) as quota_count FROM user_ai_quotas WHERE user_id = auth.uid();
SELECT COUNT(*) as pref_count FROM user_ai_preferences WHERE user_id = auth.uid();
SELECT COUNT(*) as chart_count FROM star_charts WHERE user_id = auth.uid();