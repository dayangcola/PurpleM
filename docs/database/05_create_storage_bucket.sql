-- ================================================
-- 05. 创建存储桶配置
-- ================================================
-- 说明：配置Supabase Storage用于存储PDF文件
-- 注意：这部分需要在Supabase控制台的Storage页面执行
-- ================================================

-- 这些命令需要通过Supabase Dashboard执行，而不是SQL编辑器
-- 以下是SQL等效命令，仅供参考

-- 1. 创建存储桶（需要在Storage页面创建）
-- 桶名称：pdf-books
-- 访问类型：Private（私有）
-- 文件大小限制：50MB
-- 允许的MIME类型：application/pdf

-- 2. 存储策略（在创建桶后设置）
-- 以下是策略的SQL表示（实际需要在控制台配置）

/*
-- 允许认证用户上传PDF
CREATE POLICY "Authenticated users can upload PDFs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'pdf-books' 
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND LOWER(storage.extension(name)) = 'pdf'
);

-- 允许用户查看自己的PDF
CREATE POLICY "Users can view own PDFs"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'pdf-books'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 允许用户删除自己的PDF
CREATE POLICY "Users can delete own PDFs"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'pdf-books'
    AND auth.uid()::text = (storage.foldername(name))[1]
);
*/

-- 3. 创建辅助函数：生成PDF存储路径
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

-- 4. 创建辅助函数：获取PDF公开URL（如果书籍是公开的）
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
    
    -- 生成公开URL（有效期1小时）
    -- 注意：实际URL生成需要使用Supabase客户端SDK
    -- 这里返回存储路径，客户端负责生成签名URL
    RETURN book_record.file_url;
END;
$$;

-- 5. 添加函数注释
COMMENT ON FUNCTION generate_pdf_path IS '生成PDF文件的存储路径';
COMMENT ON FUNCTION get_pdf_public_url IS '获取PDF文件的公开访问URL（需要权限）';