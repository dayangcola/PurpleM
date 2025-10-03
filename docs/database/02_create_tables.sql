-- ================================================
-- 02. 创建知识库相关表
-- ================================================
-- 说明：创建书籍元数据表和知识内容表
-- 执行时间：约2秒
-- ================================================

-- 1. 书籍元数据表
-- 存储PDF书籍的基本信息和处理状态
CREATE TABLE IF NOT EXISTS books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,                      -- 书名
    author TEXT,                              -- 作者
    category TEXT DEFAULT '紫微斗数',          -- 分类
    description TEXT,                         -- 简介
    file_url TEXT,                           -- 原始PDF存储URL
    file_size INTEGER,                       -- 文件大小（字节）
    total_pages INTEGER,                     -- 总页数
    processing_status TEXT DEFAULT 'pending', -- 处理状态：pending/processing/completed/failed
    processing_progress DECIMAL(5,2) DEFAULT 0, -- 处理进度（0-100）
    error_message TEXT,                      -- 错误信息（如果处理失败）
    user_id UUID REFERENCES auth.users(id),  -- 上传用户
    is_public BOOLEAN DEFAULT false,         -- 是否公开
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 约束
    CONSTRAINT valid_status CHECK (
        processing_status IN ('pending', 'processing', 'completed', 'failed')
    ),
    CONSTRAINT valid_progress CHECK (
        processing_progress >= 0 AND processing_progress <= 100
    )
);

-- 2. 知识库内容表
-- 存储分块后的文本内容和向量
CREATE TABLE IF NOT EXISTS knowledge_base (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    book_title TEXT NOT NULL,                -- 冗余存储书名（优化查询）
    chapter TEXT,                            -- 章节标题
    section TEXT,                            -- 小节标题
    page_number INTEGER,                     -- 页码
    content TEXT NOT NULL,                   -- 文本内容
    content_length INTEGER,                  -- 内容长度（字符数）
    chunk_index INTEGER,                     -- 块序号（同一页可能有多块）
    embedding vector(1536),                  -- OpenAI embedding向量
    metadata JSONB DEFAULT '{}',             -- 额外元数据
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 全文搜索向量（自动生成）
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('simple', coalesce(chapter, '')), 'A') ||
        setweight(to_tsvector('simple', coalesce(section, '')), 'B') ||
        setweight(to_tsvector('simple', content), 'C')
    ) STORED,
    
    -- 约束
    CONSTRAINT valid_page CHECK (page_number > 0),
    CONSTRAINT valid_content_length CHECK (content_length > 0)
);

-- 3. 创建索引（安全创建，避免重复）
-- 先删除可能存在的旧索引
DROP INDEX IF EXISTS idx_knowledge_embedding;
DROP INDEX IF EXISTS idx_knowledge_search;
DROP INDEX IF EXISTS idx_knowledge_book_id;
DROP INDEX IF EXISTS idx_books_user_id;
DROP INDEX IF EXISTS idx_books_status;
DROP INDEX IF EXISTS idx_books_public;

-- 向量相似度搜索索引（IVFFlat）
CREATE INDEX idx_knowledge_embedding ON knowledge_base 
USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);

-- 全文搜索索引
CREATE INDEX idx_knowledge_search ON knowledge_base 
USING GIN (search_vector);

-- 常规查询索引
CREATE INDEX idx_knowledge_book_id ON knowledge_base(book_id);
CREATE INDEX idx_books_user_id ON books(user_id);
CREATE INDEX idx_books_status ON books(processing_status);
CREATE INDEX idx_books_public ON books(is_public);

-- 4. 创建更新时间触发器
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER books_updated_at
    BEFORE UPDATE ON books
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- 5. 添加表注释
COMMENT ON TABLE books IS '紫微斗数PDF书籍元数据表';
COMMENT ON TABLE knowledge_base IS '知识库内容表，存储分块文本和向量';
COMMENT ON COLUMN books.processing_status IS '处理状态：pending(待处理), processing(处理中), completed(已完成), failed(失败)';
COMMENT ON COLUMN knowledge_base.embedding IS 'OpenAI text-embedding-ada-002生成的1536维向量';
COMMENT ON COLUMN knowledge_base.search_vector IS '全文搜索向量，自动生成，用于中文分词搜索';