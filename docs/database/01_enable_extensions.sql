-- ================================================
-- 01. 启用必要的扩展
-- ================================================
-- 说明：为知识库系统启用必要的PostgreSQL扩展
-- 执行时间：约1秒
-- ================================================

-- 启用pgvector扩展（用于向量相似度搜索）
CREATE EXTENSION IF NOT EXISTS vector;

-- 启用pg_trgm扩展（用于文本相似度搜索）
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 验证扩展安装
SELECT 
    extname as extension_name,
    extversion as version,
    extnamespace::regnamespace as schema
FROM pg_extension 
WHERE extname IN ('vector', 'pg_trgm');

-- 预期结果：
-- extension_name | version | schema
-- ---------------+---------+--------
-- vector         | 0.5.1   | public
-- pg_trgm        | 1.6     | public