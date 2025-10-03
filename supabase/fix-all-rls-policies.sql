-- ============================================
-- 修复所有表的RLS策略问题
-- 确保所有数据都能正确写入和读取
-- 日期：2025-09-13
-- ============================================

-- ============================================
-- 1. star_charts表 - 星盘数据（最关键）
-- ============================================

-- 启用RLS
ALTER TABLE star_charts ENABLE ROW LEVEL SECURITY;

-- 删除旧策略（如果存在）
DROP POLICY IF EXISTS "Users can manage own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can view own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can insert own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can update own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can delete own charts" ON star_charts;

-- 创建新策略
CREATE POLICY "Users can insert own charts" ON star_charts
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own charts" ON star_charts
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own charts" ON star_charts
  FOR UPDATE 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own charts" ON star_charts
  FOR DELETE 
  USING (auth.uid() = user_id);

-- ============================================
-- 2. profiles表 - 用户资料
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "System can insert profiles" ON profiles;

-- 创建新策略
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT 
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 允许用户插入自己的profile（注册时需要）
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- ============================================
-- 3. chat_sessions表 - 聊天会话
-- ============================================

ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "Users can manage own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can insert own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can view own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can update own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can delete own sessions" ON chat_sessions;

-- 创建新策略
CREATE POLICY "Users can insert own sessions" ON chat_sessions
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own sessions" ON chat_sessions
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions" ON chat_sessions
  FOR UPDATE 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own sessions" ON chat_sessions
  FOR DELETE 
  USING (auth.uid() = user_id);

-- ============================================
-- 4. chat_messages表 - 聊天消息
-- ============================================

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "Users can manage own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can insert own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can view own messages" ON chat_messages;

-- 创建新策略
CREATE POLICY "Users can insert own messages" ON chat_messages
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own messages" ON chat_messages
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own messages" ON chat_messages
  FOR UPDATE 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 5. user_ai_quotas表 - AI配额
-- ============================================

ALTER TABLE user_ai_quotas ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "Users can view own quota" ON user_ai_quotas;
DROP POLICY IF EXISTS "Users can view own quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Users can insert own quota" ON user_ai_quotas;
DROP POLICY IF EXISTS "System can insert quotas" ON user_ai_quotas;

-- 创建新策略
CREATE POLICY "Users can view own quota" ON user_ai_quotas
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own quota" ON user_ai_quotas
  FOR UPDATE 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 允许系统插入（触发器需要）
CREATE POLICY "Users can insert own quota" ON user_ai_quotas
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 6. user_ai_preferences表 - AI偏好设置
-- ============================================

ALTER TABLE user_ai_preferences ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "Users can view own preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Users can manage own preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "System can insert preferences" ON user_ai_preferences;

-- 创建新策略
CREATE POLICY "Users can insert own preferences" ON user_ai_preferences
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own preferences" ON user_ai_preferences
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences" ON user_ai_preferences
  FOR UPDATE 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 7. daily_fortunes表 - 每日运势
-- ============================================

ALTER TABLE daily_fortunes ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "Users can manage own fortunes" ON daily_fortunes;

-- 创建新策略
CREATE POLICY "Users can insert own fortunes" ON daily_fortunes
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own fortunes" ON daily_fortunes
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own fortunes" ON daily_fortunes
  FOR UPDATE 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 8. user_birth_info表 - 出生信息
-- ============================================

ALTER TABLE user_birth_info ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "Users can manage own birth info" ON user_birth_info;

-- 创建新策略
CREATE POLICY "Users can insert own birth info" ON user_birth_info
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own birth info" ON user_birth_info
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own birth info" ON user_birth_info
  FOR UPDATE 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own birth info" ON user_birth_info
  FOR DELETE 
  USING (auth.uid() = user_id);

-- ============================================
-- 9. 验证RLS策略
-- ============================================

-- 查看所有表的RLS状态
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN rowsecurity = true THEN '✅ 已启用'
        ELSE '❌ 未启用'
    END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 查看所有策略
SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    CASE cmd
        WHEN 'SELECT' THEN '查询'
        WHEN 'INSERT' THEN '插入'
        WHEN 'UPDATE' THEN '更新'
        WHEN 'DELETE' THEN '删除'
        ELSE cmd
    END as operation
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd;

-- ============================================
-- 10. 测试新用户数据写入
-- ============================================

-- 测试查询：检查最近的数据写入
SELECT 
    'profiles' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN created_at > NOW() - INTERVAL '24 hours' THEN 1 END) as recent_records
FROM profiles
UNION ALL
SELECT 
    'star_charts',
    COUNT(*),
    COUNT(CASE WHEN generated_at > NOW() - INTERVAL '24 hours' THEN 1 END)
FROM star_charts
UNION ALL
SELECT 
    'chat_sessions',
    COUNT(*),
    COUNT(CASE WHEN created_at > NOW() - INTERVAL '24 hours' THEN 1 END)
FROM chat_sessions
UNION ALL
SELECT 
    'chat_messages',
    COUNT(*),
    COUNT(CASE WHEN created_at > NOW() - INTERVAL '24 hours' THEN 1 END)
FROM chat_messages;

-- ============================================
-- 完成！
-- 请在Supabase SQL编辑器中运行此脚本
-- ============================================