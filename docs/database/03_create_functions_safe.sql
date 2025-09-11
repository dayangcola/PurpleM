-- ================================================
-- 03. 安全创建数据库函数（处理重复问题）
-- ================================================
-- 说明：先删除可能存在的旧函数，再创建新函数
-- 执行时间：约2秒
-- ================================================

-- 1. 清理可能存在的旧函数
-- 注意：CASCADE会删除依赖这些函数的对象
DROP FUNCTION IF EXISTS search_knowledge CASCADE;
DROP FUNCTION IF EXISTS hybrid_search CASCADE;
DROP FUNCTION IF EXISTS get_knowledge_context CASCADE;
DROP FUNCTION IF EXISTS update_book_progress CASCADE;
DROP FUNCTION IF EXISTS get_user_book_stats CASCADE;
DROP FUNCTION IF EXISTS generate_pdf_path CASCADE;
DROP FUNCTION IF EXISTS get_pdf_public_url CASCADE;

-- 查看当前存在的函数（用于调试）
DO $$
BEGIN
    RAISE NOTICE '清理完成，开始创建新函数...';
END $$;

-- 2. 创建向量相似度搜索函数
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

-- 3. 创建混合搜索函数（向量 + 全文搜索）
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

-- 4. 创建获取上下文函数
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

-- 5. 创建书籍处理进度更新函数
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

-- 6. 创建获取用户的书籍统计函数
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

-- 7. 创建PDF路径生成函数
CREATE OR REPLACE FUNCTION generate_pdf_path(
    user_id UUID,
    file_name TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    safe_filename TEXT;
    timestamp_str TEXT;
BEGIN
    -- 清理文件名（移除特殊字符）
    safe_filename := regexp_replace(file_name, '[^a-zA-Z0-9._-]', '_', 'g');
    
    -- 生成时间戳
    timestamp_str := to_char(NOW(), 'YYYYMMDD_HH24MISS');
    
    -- 返回路径：user_id/timestamp_filename
    RETURN user_id::text || '/' || timestamp_str || '_' || safe_filename;
END;
$$;

-- 8. 创建获取PDF公开URL函数
CREATE OR REPLACE FUNCTION get_pdf_public_url(
    book_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    book_record RECORD;
    public_url TEXT;
BEGIN
    -- 获取书籍信息
    SELECT file_url, is_public, user_id
    INTO book_record
    FROM books
    WHERE id = book_id;
    
    -- 检查权限
    IF NOT book_record.is_public AND book_record.user_id != auth.uid() THEN
        RETURN NULL;
    END IF;
    
    -- 返回存储路径
    RETURN book_record.file_url;
END;
$$;

-- 9. 验证函数创建
DO $$
DECLARE
    func_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO func_count
    FROM pg_proc
    WHERE proname IN (
        'search_knowledge',
        'hybrid_search',
        'get_knowledge_context',
        'update_book_progress',
        'get_user_book_stats',
        'generate_pdf_path',
        'get_pdf_public_url'
    );
    
    RAISE NOTICE '✅ 成功创建 % 个函数', func_count;
END $$;

-- 10. 添加函数注释
COMMENT ON FUNCTION search_knowledge IS '基于向量相似度搜索知识库';
COMMENT ON FUNCTION hybrid_search IS '混合搜索：结合向量相似度和全文搜索';
COMMENT ON FUNCTION get_knowledge_context IS '获取知识条目的上下文';
COMMENT ON FUNCTION update_book_progress IS '更新书籍处理进度';
COMMENT ON FUNCTION get_user_book_stats IS '获取用户的书籍统计信息';
COMMENT ON FUNCTION generate_pdf_path IS '生成PDF文件的存储路径';
COMMENT ON FUNCTION get_pdf_public_url IS '获取PDF文件的公开访问URL';