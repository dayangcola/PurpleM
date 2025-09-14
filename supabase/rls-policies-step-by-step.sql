-- ============================================
-- RLS策略修复 - 分步执行版本
-- 请按顺序逐段执行，确保每段成功后再执行下一段
-- 日期：2025-09-13
-- ============================================

-- ============================================
-- 步骤1：启用所有表的RLS（如果已启用会显示提示，可以忽略）
-- ============================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE star_charts ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_fortunes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_birth_info ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 步骤2：删除star_charts表的旧策略（忽略不存在的错误）
-- ============================================
DROP POLICY IF EXISTS "Users can manage own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can view own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can insert own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can update own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can delete own charts" ON star_charts;

-- ============================================
-- 步骤3：创建star_charts表的新策略（最关键的部分）
-- ============================================

-- 允许用户插入自己的星盘
CREATE POLICY "Users can insert own charts" ON star_charts
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

-- 允许用户查看自己的星盘
CREATE POLICY "Users can view own charts" ON star_charts
  FOR SELECT 
  USING (auth.uid() = user_id);

-- 允许用户更新自己的星盘
CREATE POLICY "Users can update own charts" ON star_charts
  FOR UPDATE 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 允许用户删除自己的星盘
CREATE POLICY "Users can delete own charts" ON star_charts
  FOR DELETE 
  USING (auth.uid() = user_id);

-- ============================================
-- 步骤4：profiles表策略（如果存在会报错，可以忽略）
-- ============================================

-- 先尝试删除旧策略
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- 创建新策略
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT 
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- ============================================
-- 步骤5：chat_sessions表策略
-- ============================================

DROP POLICY IF EXISTS "Users can insert own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can view own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can update own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can delete own sessions" ON chat_sessions;

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
-- 步骤6：chat_messages表策略
-- ============================================

DROP POLICY IF EXISTS "Users can insert own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can view own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can update own messages" ON chat_messages;

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
-- 步骤7：验证RLS状态（只读查询，安全执行）
-- ============================================
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN rowsecurity = true THEN '✅ 已启用'
        ELSE '❌ 未启用'
    END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('profiles', 'star_charts', 'chat_sessions', 'chat_messages', 
                  'user_ai_quotas', 'user_ai_preferences', 'daily_fortunes', 'user_birth_info')
ORDER BY tablename;

-- ============================================
-- 步骤8：查看创建的策略（只读查询，安全执行）
-- ============================================
SELECT 
    tablename,
    policyname,
    CASE cmd
        WHEN 'SELECT' THEN '查询'
        WHEN 'INSERT' THEN '插入'
        WHEN 'UPDATE' THEN '更新'
        WHEN 'DELETE' THEN '删除'
        ELSE cmd
    END as operation,
    permissive as is_permissive
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('profiles', 'star_charts', 'chat_sessions', 'chat_messages')
ORDER BY tablename, cmd;

-- ============================================
-- 步骤9：测试查询 - 检查数据统计（使用正确的字段名）
-- ============================================
SELECT 
    'profiles' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN created_at > NOW() - INTERVAL '24 hours' THEN 1 END) as recent_24h
FROM profiles

UNION ALL

SELECT 
    'star_charts',
    COUNT(*),
    COUNT(CASE WHEN generated_at > NOW() - INTERVAL '24 hours' THEN 1 END)  -- 注意：使用generated_at
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
-- 
-- 执行顺序建议：
-- 1. 先执行步骤1-3（最重要的star_charts表策略）
-- 2. 测试应用是否能保存星盘
-- 3. 如果成功，继续执行步骤4-6
-- 4. 执行步骤7-9验证结果
-- ============================================