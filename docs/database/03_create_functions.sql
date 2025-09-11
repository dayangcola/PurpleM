-- ================================================
-- 03. 创建数据库函数
-- ================================================
-- 说明：创建知识库搜索和管理函数
-- 执行时间：约1秒
-- ================================================

-- 1. 向量相似度搜索函数
-- 使用余弦相似度搜索最相关的知识
CREATE OR REPLACE FUNCTION search_knowledge(
    query_embedding vector(1536),
    match_count INT DEFAULT 5,
    similarity_threshold FLOAT DEFAULT 0.7
)
RETURNS TABLE (
    id UUID,
    book_title TEXT,
    chapter TEXT,
    section TEXT,
    page_number INTEGER,
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
        kb.section,
        kb.page_number,
        kb.content,
        1 - (kb.embedding <=> query_embedding) as similarity
    FROM knowledge_base kb
    JOIN books b ON kb.book_id = b.id
    WHERE 
        1 - (kb.embedding <=> query_embedding) > similarity_threshold
        AND (b.is_public = true OR b.user_id = auth.uid())
    ORDER BY kb.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 2. 混合搜索函数（向量 + 全文搜索）
-- 结合语义相似度和关键词匹配
CREATE OR REPLACE FUNCTION hybrid_search(
    query_text TEXT,
    query_embedding vector(1536),
    match_count INT DEFAULT 5,
    vector_weight FLOAT DEFAULT 0.7
)
RETURNS TABLE (
    id UUID,
    book_title TEXT,
    chapter TEXT,
    section TEXT,
    page_number INTEGER,
    content TEXT,
    vector_similarity FLOAT,
    text_similarity FLOAT,
    combined_score FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH vector_search AS (
        -- 向量搜索结果
        SELECT 
            kb.id,
            kb.book_title,
            kb.chapter,
            kb.section,
            kb.page_number,
            kb.content,
            1 - (kb.embedding <=> query_embedding) as similarity
        FROM knowledge_base kb
        JOIN books b ON kb.book_id = b.id
        WHERE 
            b.is_public = true OR b.user_id = auth.uid()
        ORDER BY kb.embedding <=> query_embedding
        LIMIT match_count * 2  -- 获取更多候选结果
    ),
    text_search AS (
        -- 全文搜索结果
        SELECT 
            kb.id,
            ts_rank(kb.search_vector, plainto_tsquery('simple', query_text)) as rank
        FROM knowledge_base kb
        JOIN books b ON kb.book_id = b.id
        WHERE 
            kb.search_vector @@ plainto_tsquery('simple', query_text)
            AND (b.is_public = true OR b.user_id = auth.uid())
        ORDER BY rank DESC
        LIMIT match_count * 2
    )
    -- 合并结果
    SELECT DISTINCT
        vs.id,
        vs.book_title,
        vs.chapter,
        vs.section,
        vs.page_number,
        vs.content,
        vs.similarity as vector_similarity,
        COALESCE(ts.rank, 0) as text_similarity,
        (vs.similarity * vector_weight + COALESCE(ts.rank, 0) * (1 - vector_weight)) as combined_score
    FROM vector_search vs
    LEFT JOIN text_search ts ON vs.id = ts.id
    ORDER BY combined_score DESC
    LIMIT match_count;
END;
$$;

-- 3. 获取上下文函数
-- 获取指定知识条目的前后文
CREATE OR REPLACE FUNCTION get_knowledge_context(
    knowledge_id UUID,
    context_size INT DEFAULT 1
)
RETURNS TABLE (
    id UUID,
    book_title TEXT,
    chapter TEXT,
    section TEXT,
    page_number INTEGER,
    content TEXT,
    chunk_index INTEGER,
    is_target BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    target_book_id UUID;
    target_page INTEGER;
    target_chunk INTEGER;
BEGIN
    -- 获取目标条目信息
    SELECT book_id, page_number, chunk_index 
    INTO target_book_id, target_page, target_chunk
    FROM knowledge_base
    WHERE id = knowledge_id;
    
    -- 返回前后文
    RETURN QUERY
    SELECT 
        kb.id,
        kb.book_title,
        kb.chapter,
        kb.section,
        kb.page_number,
        kb.content,
        kb.chunk_index,
        (kb.id = knowledge_id) as is_target
    FROM knowledge_base kb
    WHERE 
        kb.book_id = target_book_id
        AND kb.page_number BETWEEN target_page - context_size AND target_page + context_size
    ORDER BY kb.page_number, kb.chunk_index;
END;
$$;

-- 4. 书籍处理进度更新函数
CREATE OR REPLACE FUNCTION update_book_progress(
    book_id UUID,
    progress DECIMAL(5,2),
    status TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE books 
    SET 
        processing_progress = progress,
        processing_status = COALESCE(status, processing_status),
        updated_at = NOW()
    WHERE id = book_id;
END;
$$;

-- 5. 获取用户的书籍统计
CREATE OR REPLACE FUNCTION get_user_book_stats(
    user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    total_books BIGINT,
    completed_books BIGINT,
    processing_books BIGINT,
    failed_books BIGINT,
    total_knowledge_items BIGINT,
    total_storage_mb DECIMAL(10,2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT b.id) as total_books,
        COUNT(DISTINCT CASE WHEN b.processing_status = 'completed' THEN b.id END) as completed_books,
        COUNT(DISTINCT CASE WHEN b.processing_status = 'processing' THEN b.id END) as processing_books,
        COUNT(DISTINCT CASE WHEN b.processing_status = 'failed' THEN b.id END) as failed_books,
        COUNT(kb.id) as total_knowledge_items,
        COALESCE(SUM(b.file_size) / 1024.0 / 1024.0, 0) as total_storage_mb
    FROM books b
    LEFT JOIN knowledge_base kb ON b.id = kb.book_id
    WHERE 
        CASE 
            WHEN user_id IS NOT NULL THEN b.user_id = user_id
            ELSE b.user_id = auth.uid()
        END;
END;
$$;

-- 6. 添加函数注释
COMMENT ON FUNCTION search_knowledge IS '基于向量相似度搜索知识库';
COMMENT ON FUNCTION hybrid_search IS '混合搜索：结合向量相似度和全文搜索';
COMMENT ON FUNCTION get_knowledge_context IS '获取知识条目的上下文';
COMMENT ON FUNCTION update_book_progress IS '更新书籍处理进度';
COMMENT ON FUNCTION get_user_book_stats IS '获取用户的书籍统计信息';