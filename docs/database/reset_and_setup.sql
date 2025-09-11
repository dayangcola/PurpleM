-- ================================================
-- 安全重置和设置脚本
-- ================================================
-- 说明：用于处理部分执行或需要重新设置的情况
-- 警告：此脚本会删除现有数据，请先备份！
-- ================================================

-- 1. 先检查当前状态
DO $$
BEGIN
    RAISE NOTICE '开始检查当前数据库状态...';
    
    -- 检查表是否存在
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'knowledge_base') THEN
        RAISE NOTICE '✓ knowledge_base表已存在';
    ELSE
        RAISE NOTICE '✗ knowledge_base表不存在';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'books') THEN
        RAISE NOTICE '✓ books表已存在';
    ELSE
        RAISE NOTICE '✗ books表不存在';
    END IF;
END $$;

-- 2. 可选：完全重置（取消注释以执行）
-- ================================================
-- 警告：以下命令会删除所有数据！
-- ================================================

/*
-- 删除表（会级联删除所有相关对象）
DROP TABLE IF EXISTS knowledge_base CASCADE;
DROP TABLE IF EXISTS books CASCADE;

-- 删除函数
DROP FUNCTION IF EXISTS search_knowledge CASCADE;
DROP FUNCTION IF EXISTS hybrid_search CASCADE;
DROP FUNCTION IF EXISTS get_knowledge_context CASCADE;
DROP FUNCTION IF EXISTS update_book_progress CASCADE;
DROP FUNCTION IF EXISTS get_user_book_stats CASCADE;
DROP FUNCTION IF EXISTS generate_pdf_path CASCADE;
DROP FUNCTION IF EXISTS get_pdf_public_url CASCADE;
DROP FUNCTION IF EXISTS update_updated_at CASCADE;
*/

-- 3. 安全创建表（如果不存在）
-- ================================================

-- 创建books表
CREATE TABLE IF NOT EXISTS books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    author TEXT,
    category TEXT DEFAULT '紫微斗数',
    description TEXT,
    file_url TEXT,
    file_size INTEGER,
    total_pages INTEGER,
    processing_status TEXT DEFAULT 'pending',
    processing_progress DECIMAL(5,2) DEFAULT 0,
    error_message TEXT,
    user_id UUID REFERENCES auth.users(id),
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT valid_status CHECK (
        processing_status IN ('pending', 'processing', 'completed', 'failed')
    ),
    CONSTRAINT valid_progress CHECK (
        processing_progress >= 0 AND processing_progress <= 100
    )
);

-- 创建knowledge_base表
CREATE TABLE IF NOT EXISTS knowledge_base (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    book_title TEXT NOT NULL,
    chapter TEXT,
    section TEXT,
    page_number INTEGER,
    content TEXT NOT NULL,
    content_length INTEGER,
    chunk_index INTEGER,
    embedding vector(1536),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('simple', coalesce(chapter, '')), 'A') ||
        setweight(to_tsvector('simple', coalesce(section, '')), 'B') ||
        setweight(to_tsvector('simple', content), 'C')
    ) STORED,
    
    CONSTRAINT valid_page CHECK (page_number > 0),
    CONSTRAINT valid_content_length CHECK (content_length > 0)
);

-- 4. 安全重建索引
-- ================================================

-- 使用DO块来安全创建索引
DO $$
BEGIN
    -- idx_knowledge_embedding
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_knowledge_embedding') THEN
        CREATE INDEX idx_knowledge_embedding ON knowledge_base 
        USING ivfflat (embedding vector_cosine_ops) 
        WITH (lists = 100);
        RAISE NOTICE '✓ 创建索引 idx_knowledge_embedding';
    ELSE
        RAISE NOTICE '✓ 索引 idx_knowledge_embedding 已存在';
    END IF;
    
    -- idx_knowledge_search
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_knowledge_search') THEN
        CREATE INDEX idx_knowledge_search ON knowledge_base 
        USING GIN (search_vector);
        RAISE NOTICE '✓ 创建索引 idx_knowledge_search';
    ELSE
        RAISE NOTICE '✓ 索引 idx_knowledge_search 已存在';
    END IF;
    
    -- idx_knowledge_book_id
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_knowledge_book_id') THEN
        CREATE INDEX idx_knowledge_book_id ON knowledge_base(book_id);
        RAISE NOTICE '✓ 创建索引 idx_knowledge_book_id';
    ELSE
        RAISE NOTICE '✓ 索引 idx_knowledge_book_id 已存在';
    END IF;
    
    -- idx_books_user_id
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_books_user_id') THEN
        CREATE INDEX idx_books_user_id ON books(user_id);
        RAISE NOTICE '✓ 创建索引 idx_books_user_id';
    ELSE
        RAISE NOTICE '✓ 索引 idx_books_user_id 已存在';
    END IF;
    
    -- idx_books_status
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_books_status') THEN
        CREATE INDEX idx_books_status ON books(processing_status);
        RAISE NOTICE '✓ 创建索引 idx_books_status';
    ELSE
        RAISE NOTICE '✓ 索引 idx_books_status 已存在';
    END IF;
    
    -- idx_books_public
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_books_public') THEN
        CREATE INDEX idx_books_public ON books(is_public);
        RAISE NOTICE '✓ 创建索引 idx_books_public';
    ELSE
        RAISE NOTICE '✓ 索引 idx_books_public 已存在';
    END IF;
END $$;

-- 5. 创建或替换触发器函数
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. 安全创建触发器
DROP TRIGGER IF EXISTS books_updated_at ON books;
CREATE TRIGGER books_updated_at
    BEFORE UPDATE ON books
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- 7. 最终验证
-- ================================================
SELECT 
    '表状态检查' as check_type,
    COUNT(*) as table_count,
    STRING_AGG(table_name, ', ') as tables
FROM information_schema.tables
WHERE table_schema = 'public' 
    AND table_name IN ('books', 'knowledge_base')

UNION ALL

SELECT 
    '索引状态检查' as check_type,
    COUNT(*) as index_count,
    STRING_AGG(indexname, ', ') as indexes
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename IN ('books', 'knowledge_base')

UNION ALL

SELECT 
    '扩展状态检查' as check_type,
    COUNT(*) as extension_count,
    STRING_AGG(extname, ', ') as extensions
FROM pg_extension
WHERE extname IN ('vector', 'pg_trgm');

-- 输出应该显示：
-- 表状态检查: 2个表
-- 索引状态检查: 6+个索引
-- 扩展状态检查: 2个扩展