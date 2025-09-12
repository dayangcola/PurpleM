-- ================================================
-- 正确的知识库迁移脚本
-- 基于实际的knowledge_base_simple表结构
-- ================================================

-- 1. 启用必要扩展
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. 创建或确认books表存在
CREATE TABLE IF NOT EXISTS books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    author TEXT,
    category TEXT DEFAULT '紫微斗数',
    description TEXT,
    file_url TEXT,
    file_size INTEGER,
    total_pages INTEGER,
    processing_status TEXT DEFAULT 'completed',
    upload_by UUID,
    is_public BOOLEAN DEFAULT true,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 插入或更新默认书籍记录
INSERT INTO books (
    id, 
    title, 
    author, 
    category, 
    description, 
    processing_status, 
    is_public
)
VALUES (
    'ddffb427-d8cd-4f17-9a15-39ccbefd2a8c'::UUID,
    '紫微斗数知识库',
    '古籍汇编',
    '紫微斗数',
    '包含紫微斗数基础理论、古籍原文、实用口诀等104条知识',
    'completed',
    true
)
ON CONFLICT (id) DO UPDATE 
SET 
    updated_at = NOW(),
    is_public = true;  -- 确保是公开的

-- 4. 创建标准knowledge_base表
CREATE TABLE IF NOT EXISTS knowledge_base (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID REFERENCES books(id) ON DELETE CASCADE,
    book_title TEXT NOT NULL,
    chapter TEXT,
    section TEXT,
    page_number INTEGER,
    content TEXT NOT NULL,
    content_length INTEGER,
    embedding vector(1536),
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 全文搜索向量
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('simple', coalesce(chapter, '')), 'A') ||
        setweight(to_tsvector('simple', coalesce(section, '')), 'B') ||
        setweight(to_tsvector('simple', content), 'C')
    ) STORED
);

-- 5. 创建索引
CREATE INDEX IF NOT EXISTS idx_knowledge_embedding 
ON knowledge_base USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_knowledge_search 
ON knowledge_base USING GIN (search_vector);

CREATE INDEX IF NOT EXISTS idx_knowledge_book 
ON knowledge_base(book_id);

-- 6. 迁移数据（基于实际的knowledge_base_simple结构）
-- 先清理可能存在的重复数据
TRUNCATE knowledge_base;

-- 执行迁移
INSERT INTO knowledge_base (
    id,  -- 保留原始ID以便追踪
    book_id,
    book_title,
    chapter,
    content,
    content_length,
    metadata,
    created_at
)
SELECT 
    kbs.id,  -- 保留原始ID
    kbs.book_id,
    '紫微斗数知识库' as book_title,
    -- 从内容中智能提取章节分类
    CASE 
        WHEN kbs.content LIKE '%【紫微斗数古籍·卷一%' THEN '古籍卷一'
        WHEN kbs.content LIKE '%【紫微斗数古籍·卷二%' THEN '古籍卷二'
        WHEN kbs.content LIKE '%【紫微斗数古籍·卷三%' THEN '古籍卷三'
        WHEN kbs.content LIKE '%【紫微斗数古籍·口诀%' THEN '实用口诀'
        WHEN kbs.content LIKE '%卷一%' THEN '古籍卷一'
        WHEN kbs.content LIKE '%卷二%' THEN '古籍卷二'
        WHEN kbs.content LIKE '%卷三%' THEN '古籍卷三'
        WHEN kbs.content LIKE '%口诀%' THEN '实用口诀'
        WHEN kbs.content LIKE '%紫微斗数概述%' THEN '基础理论'
        WHEN kbs.content LIKE '%十二宫位%' THEN '十二宫位'
        WHEN kbs.content LIKE '%十四主星%' THEN '十四主星'
        WHEN kbs.content LIKE '%四化%' THEN '四化理论'
        WHEN kbs.content LIKE '%排盘%' THEN '排盘方法'
        WHEN kbs.content LIKE '%星曜组合%' THEN '星曜组合'
        WHEN kbs.content LIKE '%实际应用%' THEN '实际应用'
        WHEN kbs.content LIKE '%学习建议%' THEN '学习指南'
        ELSE '紫微斗数知识'
    END as chapter,
    kbs.content,
    length(kbs.content) as content_length,
    jsonb_build_object(
        'source', 'knowledge_base_simple',
        'migrated_at', NOW()::TEXT,
        'original_id', kbs.id::TEXT
    ) as metadata,
    kbs.created_at
FROM knowledge_base_simple kbs
WHERE kbs.book_id = 'ddffb427-d8cd-4f17-9a15-39ccbefd2a8c'::UUID
ON CONFLICT (id) DO NOTHING;  -- 避免重复

-- 7. 创建搜索函数集合

-- 7.1 简单文本搜索（立即可用，不需要向量）
CREATE OR REPLACE FUNCTION text_search(
    query_text TEXT,
    result_limit INT DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    book_title TEXT,
    chapter TEXT,
    content TEXT,
    relevance FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        kb.id,
        kb.book_title,
        kb.chapter,
        kb.content,
        ts_rank(kb.search_vector, plainto_tsquery('simple', query_text))::FLOAT AS relevance
    FROM knowledge_base kb
    WHERE kb.search_vector @@ plainto_tsquery('simple', query_text)
    ORDER BY relevance DESC
    LIMIT result_limit;
END;
$$;

-- 7.2 向量搜索（需要先生成embedding）
CREATE OR REPLACE FUNCTION vector_search(
    query_embedding vector(1536),
    similarity_threshold FLOAT DEFAULT 0.7,
    result_limit INT DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    book_title TEXT,
    chapter TEXT,
    content TEXT,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        kb.id,
        kb.book_title,
        kb.chapter,
        kb.content,
        1 - (kb.embedding <=> query_embedding) AS similarity
    FROM knowledge_base kb
    WHERE 
        kb.embedding IS NOT NULL
        AND 1 - (kb.embedding <=> query_embedding) > similarity_threshold
    ORDER BY kb.embedding <=> query_embedding
    LIMIT result_limit;
END;
$$;

-- 7.3 混合搜索（自动判断是否有向量）
CREATE OR REPLACE FUNCTION smart_search(
    query_text TEXT,
    query_embedding vector(1536) DEFAULT NULL,
    result_limit INT DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    book_title TEXT,
    chapter TEXT,
    content TEXT,
    score FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF query_embedding IS NOT NULL THEN
        -- 有向量：混合搜索
        RETURN QUERY
        WITH vector_results AS (
            SELECT
                kb.id,
                kb.book_title,
                kb.chapter,
                kb.content,
                1 - (kb.embedding <=> query_embedding) AS v_score
            FROM knowledge_base kb
            WHERE kb.embedding IS NOT NULL
            ORDER BY kb.embedding <=> query_embedding
            LIMIT result_limit * 2
        ),
        text_results AS (
            SELECT
                kb.id,
                ts_rank(kb.search_vector, plainto_tsquery('simple', query_text)) AS t_score
            FROM knowledge_base kb
            WHERE kb.search_vector @@ plainto_tsquery('simple', query_text)
        )
        SELECT DISTINCT
            vr.id,
            vr.book_title,
            vr.chapter,
            vr.content,
            (COALESCE(vr.v_score, 0) * 0.7 + COALESCE(tr.t_score, 0) * 0.3)::FLOAT AS score
        FROM vector_results vr
        LEFT JOIN text_results tr ON vr.id = tr.id
        ORDER BY score DESC
        LIMIT result_limit;
    ELSE
        -- 无向量：纯文本搜索
        RETURN QUERY
        SELECT
            kb.id,
            kb.book_title,
            kb.chapter,
            kb.content,
            ts_rank(kb.search_vector, plainto_tsquery('simple', query_text))::FLOAT AS score
        FROM knowledge_base kb
        WHERE kb.search_vector @@ plainto_tsquery('simple', query_text)
        ORDER BY score DESC
        LIMIT result_limit;
    END IF;
END;
$$;

-- 8. 授权
GRANT SELECT ON books TO anon, authenticated;
GRANT SELECT ON knowledge_base TO anon, authenticated;
GRANT EXECUTE ON FUNCTION text_search TO anon, authenticated;
GRANT EXECUTE ON FUNCTION vector_search TO anon, authenticated;
GRANT EXECUTE ON FUNCTION smart_search TO anon, authenticated;

-- 9. 验证迁移结果
DO $$
DECLARE
    source_count INTEGER;
    target_count INTEGER;
    chapter_info TEXT;
BEGIN
    SELECT COUNT(*) INTO source_count 
    FROM knowledge_base_simple 
    WHERE book_id = 'ddffb427-d8cd-4f17-9a15-39ccbefd2a8c'::UUID;
    
    SELECT COUNT(*) INTO target_count 
    FROM knowledge_base 
    WHERE book_id = 'ddffb427-d8cd-4f17-9a15-39ccbefd2a8c'::UUID;
    
    SELECT string_agg(chapter || ': ' || cnt::TEXT, ', ') INTO chapter_info
    FROM (
        SELECT chapter, COUNT(*) as cnt
        FROM knowledge_base
        WHERE book_id = 'ddffb427-d8cd-4f17-9a15-39ccbefd2a8c'::UUID
        GROUP BY chapter
        ORDER BY COUNT(*) DESC
        LIMIT 5
    ) t;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ 数据迁移完成';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 迁移统计：';
    RAISE NOTICE '  原始记录: % 条', source_count;
    RAISE NOTICE '  迁移记录: % 条', target_count;
    RAISE NOTICE '';
    RAISE NOTICE '📚 章节分布（前5）：';
    RAISE NOTICE '  %', chapter_info;
    RAISE NOTICE '';
    RAISE NOTICE '🔍 可用搜索函数：';
    RAISE NOTICE '  • text_search() - 纯文本搜索（立即可用）';
    RAISE NOTICE '  • vector_search() - 向量搜索（需要embedding）';
    RAISE NOTICE '  • smart_search() - 智能搜索（自动选择）';
    RAISE NOTICE '========================================';
    RAISE NOTICE '下一步：';
    RAISE NOTICE '1. 测试搜索: SELECT * FROM text_search(''紫微星'', 3);';
    RAISE NOTICE '2. 生成向量: python3 generate-embeddings-enhanced.py';
    RAISE NOTICE '========================================';
END $$;

-- 10. 测试搜索功能
SELECT 
    chapter,
    substring(content, 1, 100) as preview
FROM text_search('紫微星', 3);