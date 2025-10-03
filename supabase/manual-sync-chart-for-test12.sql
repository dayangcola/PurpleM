-- 手动为test12用户创建星盘记录
-- 在Supabase SQL编辑器中运行此脚本

-- 1. 先查找test12用户的ID
DO $$
DECLARE
    v_user_id UUID;
    v_chart_exists BOOLEAN;
BEGIN
    -- 查找test12用户
    SELECT id INTO v_user_id
    FROM profiles
    WHERE email LIKE '%test12%' 
       OR username LIKE '%test12%'
    LIMIT 1;
    
    IF v_user_id IS NULL THEN
        RAISE NOTICE '未找到test12用户';
        RETURN;
    END IF;
    
    RAISE NOTICE '找到用户ID: %', v_user_id;
    
    -- 检查是否已有星盘
    SELECT EXISTS(
        SELECT 1 FROM star_charts WHERE user_id = v_user_id
    ) INTO v_chart_exists;
    
    IF v_chart_exists THEN
        RAISE NOTICE '用户已有星盘记录';
        
        -- 显示现有星盘
        PERFORM pg_sleep(0.1);
        RAISE NOTICE '现有星盘数据:';
        
    ELSE
        RAISE NOTICE '用户没有星盘，准备创建示例星盘...';
        
        -- 创建示例星盘数据
        INSERT INTO star_charts (
            id,
            user_id,
            chart_data,
            version,
            is_primary,
            generated_at,
            created_at,
            updated_at
        ) VALUES (
            gen_random_uuid(),
            v_user_id,
            jsonb_build_object(
                'jsonData', '{"palace":[{"name":"命宫","stars":["紫微","天机"]},{"name":"财帛宫","stars":["太阳","太阴"]}]}',
                'userInfo', jsonb_build_object(
                    'name', 'test12',
                    'gender', '男',
                    'birthDate', '2000-01-01T00:00:00Z',
                    'birthTime', '12:00:00',
                    'birthLocation', '北京',
                    'isLunarDate', false
                ),
                'generatedAt', NOW()
            ),
            '1.0',
            true,
            NOW(),
            NOW(),
            NOW()
        );
        
        RAISE NOTICE '✅ 成功创建星盘记录';
    END IF;
END $$;

-- 2. 查询test12用户的所有星盘
SELECT 
    'User Charts' as info,
    sc.id as chart_id,
    sc.user_id,
    p.email,
    p.username,
    sc.is_primary,
    sc.version,
    sc.created_at,
    LENGTH(sc.chart_data::text) as data_size
FROM star_charts sc
JOIN profiles p ON sc.user_id = p.id
WHERE p.email LIKE '%test12%' 
   OR p.username LIKE '%test12%'
ORDER BY sc.created_at DESC;

-- 3. 查看星盘详细数据（如果需要）
SELECT 
    p.username,
    sc.chart_data->'userInfo' as user_info,
    LEFT(sc.chart_data->>'jsonData', 200) as chart_data_preview
FROM star_charts sc
JOIN profiles p ON sc.user_id = p.id
WHERE p.email LIKE '%test12%' 
   OR p.username LIKE '%test12%'
LIMIT 1;