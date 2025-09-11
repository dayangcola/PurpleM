-- ================================================
-- 04. 创建行级安全策略（RLS）
-- ================================================
-- 说明：配置数据访问权限，确保数据安全
-- 执行时间：约1秒
-- ================================================

-- 1. 启用RLS
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge_base ENABLE ROW LEVEL SECURITY;

-- 2. Books表策略
-- 允许用户查看自己的书籍和公开书籍
CREATE POLICY "Users can view own and public books" ON books
    FOR SELECT
    USING (
        auth.uid() = user_id 
        OR is_public = true
    );

-- 允许用户插入自己的书籍
CREATE POLICY "Users can insert own books" ON books
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 允许用户更新自己的书籍
CREATE POLICY "Users can update own books" ON books
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 允许用户删除自己的书籍
CREATE POLICY "Users can delete own books" ON books
    FOR DELETE
    USING (auth.uid() = user_id);

-- 3. Knowledge_base表策略
-- 允许查看关联到可见书籍的知识
CREATE POLICY "Users can view knowledge from visible books" ON knowledge_base
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM books b
            WHERE b.id = knowledge_base.book_id
            AND (b.user_id = auth.uid() OR b.is_public = true)
        )
    );

-- 允许用户为自己的书籍插入知识
CREATE POLICY "Users can insert knowledge for own books" ON knowledge_base
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM books b
            WHERE b.id = knowledge_base.book_id
            AND b.user_id = auth.uid()
        )
    );

-- 允许用户更新自己书籍的知识
CREATE POLICY "Users can update knowledge for own books" ON knowledge_base
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM books b
            WHERE b.id = knowledge_base.book_id
            AND b.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM books b
            WHERE b.id = knowledge_base.book_id
            AND b.user_id = auth.uid()
        )
    );

-- 允许用户删除自己书籍的知识
CREATE POLICY "Users can delete knowledge for own books" ON knowledge_base
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM books b
            WHERE b.id = knowledge_base.book_id
            AND b.user_id = auth.uid()
        )
    );

-- 4. 创建服务角色策略（用于后端处理）
-- 服务角色可以访问所有数据
CREATE POLICY "Service role has full access to books" ON books
    FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access to knowledge" ON knowledge_base
    FOR ALL
    USING (auth.role() = 'service_role');

-- 5. 添加策略注释
COMMENT ON POLICY "Users can view own and public books" ON books IS 
    '用户可以查看自己上传的书籍和所有公开书籍';
COMMENT ON POLICY "Users can view knowledge from visible books" ON knowledge_base IS 
    '用户可以查看来自可见书籍（自己的或公开的）的知识内容';