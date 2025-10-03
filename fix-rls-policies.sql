-- 修复 Row Level Security 策略
-- 允许用户访问自己的数据

-- 1. 确保RLS已启用
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE star_charts ENABLE ROW LEVEL SECURITY;

-- 2. 删除旧策略（如果存在）
DROP POLICY IF EXISTS "Users can view own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can create own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Users can update own sessions" ON chat_sessions;

DROP POLICY IF EXISTS "Users can view own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can create own messages" ON chat_messages;

DROP POLICY IF EXISTS "Users can view own preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Users can create own preferences" ON user_ai_preferences;
DROP POLICY IF EXISTS "Users can update own preferences" ON user_ai_preferences;

DROP POLICY IF EXISTS "Users can view own quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Users can create own quotas" ON user_ai_quotas;
DROP POLICY IF EXISTS "Users can update own quotas" ON user_ai_quotas;

DROP POLICY IF EXISTS "Users can view own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can create own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can update own charts" ON star_charts;

-- 3. 创建新的RLS策略 - 使用 anon key 也能访问（开发阶段）

-- chat_sessions 策略
CREATE POLICY "Enable all for anon" ON chat_sessions
    FOR ALL 
    USING (true)
    WITH CHECK (true);

-- chat_messages 策略
CREATE POLICY "Enable all for anon" ON chat_messages
    FOR ALL 
    USING (true)
    WITH CHECK (true);

-- user_ai_preferences 策略
CREATE POLICY "Enable all for anon" ON user_ai_preferences
    FOR ALL 
    USING (true)
    WITH CHECK (true);

-- user_ai_quotas 策略
CREATE POLICY "Enable all for anon" ON user_ai_quotas
    FOR ALL 
    USING (true)
    WITH CHECK (true);

-- star_charts 策略
CREATE POLICY "Enable all for anon" ON star_charts
    FOR ALL 
    USING (true)
    WITH CHECK (true);

-- 注意：这些策略仅用于开发阶段！
-- 生产环境应该使用更严格的策略，例如：
-- CREATE POLICY "Users can only see own data" ON chat_messages
--     FOR SELECT 
--     USING (auth.uid()::text = user_id);

-- 4. 确保所有表都有正确的权限
GRANT ALL ON chat_sessions TO anon, authenticated;
GRANT ALL ON chat_messages TO anon, authenticated;
GRANT ALL ON user_ai_preferences TO anon, authenticated;
GRANT ALL ON user_ai_quotas TO anon, authenticated;
GRANT ALL ON star_charts TO anon, authenticated;

-- 5. 确保序列权限
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

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
WHERE schemaname = 'public' 
    AND tablename IN ('chat_sessions', 'chat_messages', 'user_ai_preferences', 'user_ai_quotas', 'star_charts')
ORDER BY tablename, policyname;