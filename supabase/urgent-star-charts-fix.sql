-- ============================================
-- 紧急修复：star_charts表RLS策略
-- 这是最小化的修复脚本，只处理最关键的问题
-- ============================================

-- 1. 启用RLS（如果已启用会提示，忽略即可）
ALTER TABLE star_charts ENABLE ROW LEVEL SECURITY;

-- 2. 删除所有旧策略（避免冲突）
DROP POLICY IF EXISTS "Enable insert for users based on user_id" ON star_charts;
DROP POLICY IF EXISTS "Enable read access for all users" ON star_charts;
DROP POLICY IF EXISTS "Users can manage own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can view own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can insert own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can update own charts" ON star_charts;
DROP POLICY IF EXISTS "Users can delete own charts" ON star_charts;

-- 3. 创建一个宽松的策略（先让功能工作）
-- 允许认证用户插入自己的数据
CREATE POLICY "Allow users to insert own charts" ON star_charts
    FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- 允许认证用户查看自己的数据
CREATE POLICY "Allow users to view own charts" ON star_charts
    FOR SELECT 
    TO authenticated
    USING (auth.uid() = user_id);

-- 允许认证用户更新自己的数据
CREATE POLICY "Allow users to update own charts" ON star_charts
    FOR UPDATE 
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 允许认证用户删除自己的数据
CREATE POLICY "Allow users to delete own charts" ON star_charts
    FOR DELETE 
    TO authenticated
    USING (auth.uid() = user_id);

-- 4. 验证策略是否创建成功
SELECT 
    policyname,
    cmd as operation,
    roles
FROM pg_policies
WHERE schemaname = 'public' 
AND tablename = 'star_charts'
ORDER BY policyname;

-- 5. 测试：查看star_charts表的数据
SELECT 
    COUNT(*) as total_charts,
    COUNT(CASE WHEN generated_at > NOW() - INTERVAL '24 hours' THEN 1 END) as recent_charts
FROM star_charts;

-- ============================================
-- 如果上面的脚本执行成功，star_charts表应该可以正常工作了
-- 测试方法：
-- 1. 创建新用户
-- 2. 生成星盘
-- 3. 检查star_charts表是否有新数据
-- ============================================