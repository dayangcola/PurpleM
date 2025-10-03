-- 检查test12用户的所有相关数据
-- 在Supabase SQL编辑器中运行此查询

-- 1. 检查auth.users表中是否有test12
SELECT 
    'Auth Users' as table_name,
    id,
    email,
    created_at,
    raw_user_meta_data->>'username' as username
FROM auth.users
WHERE email LIKE '%test12%' 
   OR raw_user_meta_data->>'username' LIKE '%test12%'
ORDER BY created_at DESC;

-- 2. 检查profiles表
SELECT 
    'Profiles' as table_name,
    id,
    email,
    username,
    subscription_tier,
    created_at,
    updated_at
FROM profiles
WHERE email LIKE '%test12%' 
   OR username LIKE '%test12%'
ORDER BY created_at DESC;

-- 3. 检查star_charts表（星盘数据）
SELECT 
    'Star Charts' as table_name,
    sc.id as chart_id,
    sc.user_id,
    p.email,
    p.username,
    sc.is_primary,
    sc.created_at as chart_created,
    LENGTH(sc.chart_data::text) as data_size
FROM star_charts sc
LEFT JOIN profiles p ON sc.user_id = p.id
WHERE p.email LIKE '%test12%' 
   OR p.username LIKE '%test12%'
ORDER BY sc.created_at DESC;

-- 4. 如果找到用户ID，直接查询星盘
-- 请将下面的 'USER_ID_HERE' 替换为实际的用户ID
/*
SELECT 
    id,
    user_id,
    chart_data,
    is_primary,
    version,
    generated_at,
    created_at,
    updated_at
FROM star_charts
WHERE user_id = 'USER_ID_HERE';
*/

-- 5. 检查最近创建的所有星盘（最近24小时）
SELECT 
    'Recent Charts (24h)' as category,
    sc.id,
    sc.user_id,
    p.email,
    p.username,
    sc.created_at
FROM star_charts sc
LEFT JOIN profiles p ON sc.user_id = p.id
WHERE sc.created_at > NOW() - INTERVAL '24 hours'
ORDER BY sc.created_at DESC
LIMIT 10;

-- 6. 统计信息
SELECT 
    'Statistics' as info,
    (SELECT COUNT(*) FROM auth.users) as total_users,
    (SELECT COUNT(*) FROM profiles) as total_profiles,
    (SELECT COUNT(*) FROM star_charts) as total_charts,
    (SELECT COUNT(DISTINCT user_id) FROM star_charts) as users_with_charts;