-- 创建向量搜索函数
-- 在Supabase SQL Editor中运行

-- 1. 确保pgvector扩展已安装
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. 创建向量搜索函数
CREATE OR REPLACE FUNCTION search_knowledge_by_embedding(
  query_embedding vector(1536),
  match_threshold float DEFAULT 0.7,
  match_count int DEFAULT 5
)
RETURNS TABLE (
  id uuid,
  content text,
  category text,
  keywords text[],
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    kb.id,
    kb.content,
    kb.category,
    kb.keywords,
    1 - (kb.embedding <=> query_embedding) AS similarity
  FROM knowledge_base_simple kb
  WHERE kb.embedding IS NOT NULL
    AND 1 - (kb.embedding <=> query_embedding) > match_threshold
  ORDER BY kb.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- 3. 创建文本搜索函数（支持中文）
CREATE OR REPLACE FUNCTION search_knowledge_by_text(
  search_query text,
  match_count int DEFAULT 5
)
RETURNS TABLE (
  id uuid,
  content text,
  category text,
  keywords text[],
  rank float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    kb.id,
    kb.content,
    kb.category,
    kb.keywords,
    ts_rank(
      to_tsvector('simple', kb.content),
      plainto_tsquery('simple', search_query)
    ) AS rank
  FROM knowledge_base_simple kb
  WHERE to_tsvector('simple', kb.content) @@ plainto_tsquery('simple', search_query)
  ORDER BY rank DESC
  LIMIT match_count;
END;
$$;

-- 4. 创建混合搜索函数（结合向量和文本）
CREATE OR REPLACE FUNCTION hybrid_search_knowledge(
  search_query text,
  query_embedding vector(1536) DEFAULT NULL,
  match_count int DEFAULT 5
)
RETURNS TABLE (
  id uuid,
  content text,
  category text,
  keywords text[],
  score float
)
LANGUAGE plpgsql
AS $$
BEGIN
  IF query_embedding IS NOT NULL THEN
    -- 混合搜索：结合向量相似度和文本匹配
    RETURN QUERY
    WITH vector_search AS (
      SELECT
        kb.id,
        kb.content,
        kb.category,
        kb.keywords,
        1 - (kb.embedding <=> query_embedding) AS vector_similarity
      FROM knowledge_base_simple kb
      WHERE kb.embedding IS NOT NULL
      ORDER BY kb.embedding <=> query_embedding
      LIMIT match_count * 2
    ),
    text_search AS (
      SELECT
        kb.id,
        ts_rank(
          to_tsvector('simple', kb.content),
          plainto_tsquery('simple', search_query)
        ) AS text_rank
      FROM knowledge_base_simple kb
      WHERE to_tsvector('simple', kb.content) @@ plainto_tsquery('simple', search_query)
    )
    SELECT DISTINCT
      vs.id,
      vs.content,
      vs.category,
      vs.keywords,
      (COALESCE(vs.vector_similarity, 0) * 0.7 + COALESCE(ts.text_rank, 0) * 0.3) AS score
    FROM vector_search vs
    LEFT JOIN text_search ts ON vs.id = ts.id
    ORDER BY score DESC
    LIMIT match_count;
  ELSE
    -- 仅文本搜索
    RETURN QUERY
    SELECT
      kb.id,
      kb.content,
      kb.category,
      kb.keywords,
      ts_rank(
        to_tsvector('simple', kb.content),
        plainto_tsquery('simple', search_query)
      )::float AS score
    FROM knowledge_base_simple kb
    WHERE to_tsvector('simple', kb.content) @@ plainto_tsquery('simple', search_query)
    ORDER BY score DESC
    LIMIT match_count;
  END IF;
END;
$$;

-- 5. 创建分类浏览函数
CREATE OR REPLACE FUNCTION get_knowledge_by_category(
  target_category text,
  page_size int DEFAULT 10,
  page_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  content text,
  category text,
  keywords text[],
  created_at timestamp
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    kb.id,
    kb.content,
    kb.category,
    kb.keywords,
    kb.created_at
  FROM knowledge_base_simple kb
  WHERE kb.category = target_category
  ORDER BY kb.created_at DESC
  LIMIT page_size
  OFFSET page_offset;
END;
$$;

-- 6. 创建关键词搜索函数
CREATE OR REPLACE FUNCTION search_by_keywords(
  search_keywords text[],
  match_count int DEFAULT 5
)
RETURNS TABLE (
  id uuid,
  content text,
  category text,
  keywords text[],
  matched_count int
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    kb.id,
    kb.content,
    kb.category,
    kb.keywords,
    cardinality(kb.keywords && search_keywords) AS matched_count
  FROM knowledge_base_simple kb
  WHERE kb.keywords && search_keywords
  ORDER BY matched_count DESC
  LIMIT match_count;
END;
$$;

-- 7. 创建索引优化查询性能
CREATE INDEX IF NOT EXISTS idx_knowledge_embedding 
  ON knowledge_base_simple 
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_knowledge_content_gin 
  ON knowledge_base_simple 
  USING gin(to_tsvector('simple', content));

CREATE INDEX IF NOT EXISTS idx_knowledge_category 
  ON knowledge_base_simple(category);

CREATE INDEX IF NOT EXISTS idx_knowledge_keywords 
  ON knowledge_base_simple 
  USING gin(keywords);

-- 8. 授权函数访问权限
GRANT EXECUTE ON FUNCTION search_knowledge_by_embedding TO anon, authenticated;
GRANT EXECUTE ON FUNCTION search_knowledge_by_text TO anon, authenticated;
GRANT EXECUTE ON FUNCTION hybrid_search_knowledge TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_knowledge_by_category TO anon, authenticated;
GRANT EXECUTE ON FUNCTION search_by_keywords TO anon, authenticated;