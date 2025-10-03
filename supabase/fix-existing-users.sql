-- ============================================
-- 修复现有用户的数据问题
-- 专门处理老账户的外键约束和数据不一致
-- ============================================

-- 1. 首先查看有问题的用户
DO $$
BEGIN
  RAISE NOTICE '========== 开始诊断 ==========';
  RAISE NOTICE '查找所有Auth用户但没有Profile的记录...';
END;
$$;

-- 显示孤立用户
SELECT 
  au.id,
  au.email,
  au.created_at,
  '缺少Profile记录' as issue
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
WHERE p.id IS NULL;

-- 2. 修复所有缺失的profile记录
INSERT INTO profiles (
  id,
  email,
  username,
  subscription_tier,
  quota_limit,
  quota_used,
  created_at,
  updated_at
)
SELECT 
  au.id,
  au.email,
  COALESCE(
    au.raw_user_meta_data->>'username',
    au.raw_user_meta_data->>'name',
    split_part(au.email, '@', 1),
    'user_' || substring(au.id::text, 1, 8)
  ),
  'free',
  100,
  0,
  COALESCE(au.created_at, NOW()),
  NOW()
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
WHERE p.id IS NULL
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  updated_at = NOW();

-- 3. 确保所有profile都有对应的配额记录
INSERT INTO user_ai_quotas (
  user_id,
  subscription_tier,
  daily_limit,
  monthly_limit,
  daily_used,
  monthly_used,
  total_tokens_used,
  daily_reset_at,
  monthly_reset_at,
  created_at,
  updated_at
)
SELECT 
  p.id,
  COALESCE(p.subscription_tier, 'free'),
  100,
  3000,
  0,
  0,
  0,
  CURRENT_DATE,
  DATE_TRUNC('month', CURRENT_DATE),
  NOW(),
  NOW()
FROM profiles p
LEFT JOIN user_ai_quotas q ON p.id = q.user_id
WHERE q.user_id IS NULL
ON CONFLICT (user_id) DO NOTHING;

-- 4. 修复user_ai_preferences（删除旧的，重新创建）
-- 先删除有问题的记录
DELETE FROM user_ai_preferences 
WHERE user_id IN (
  SELECT p.id 
  FROM profiles p 
  WHERE NOT EXISTS (
    SELECT 1 FROM auth.users au WHERE au.id = p.id
  )
);

-- 重新创建偏好设置
INSERT INTO user_ai_preferences (
  user_id,
  conversation_style,
  response_length,
  enable_suggestions,
  created_at,
  updated_at
)
SELECT 
  p.id,
  'balanced',
  'medium',
  true,
  NOW(),
  NOW()
FROM profiles p
LEFT JOIN user_ai_preferences pref ON p.id = pref.user_id
WHERE pref.user_id IS NULL
ON CONFLICT (user_id) DO UPDATE SET
  updated_at = NOW();

-- 5. 清理孤立的会话（没有对应profile的会话）
DELETE FROM chat_sessions
WHERE user_id NOT IN (SELECT id FROM profiles);

-- 6. 清理孤立的消息（没有对应会话的消息）
DELETE FROM chat_messages
WHERE session_id NOT IN (SELECT id FROM chat_sessions);

-- 7. 为每个用户确保至少有一个会话
INSERT INTO chat_sessions (
  id,
  user_id,
  title,
  session_type,
  created_at,
  updated_at
)
SELECT 
  gen_random_uuid(),
  p.id,
  '默认会话',
  'chat',
  NOW(),
  NOW()
FROM profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM chat_sessions cs WHERE cs.user_id = p.id
);

-- 8. 验证修复结果
DO $$
DECLARE
  auth_count integer;
  profile_count integer;
  orphaned_count integer;
  sessions_without_profile integer;
  messages_without_session integer;
BEGIN
  SELECT COUNT(*) INTO auth_count FROM auth.users;
  SELECT COUNT(*) INTO profile_count FROM profiles;
  
  SELECT COUNT(*) INTO orphaned_count 
  FROM auth.users au 
  LEFT JOIN profiles p ON au.id = p.id 
  WHERE p.id IS NULL;
  
  SELECT COUNT(*) INTO sessions_without_profile
  FROM chat_sessions cs
  WHERE cs.user_id NOT IN (SELECT id FROM profiles);
  
  SELECT COUNT(*) INTO messages_without_session
  FROM chat_messages cm
  WHERE cm.session_id NOT IN (SELECT id FROM chat_sessions);
  
  RAISE NOTICE '========== 修复完成 ==========';
  RAISE NOTICE 'Auth用户总数: %', auth_count;
  RAISE NOTICE 'Profile记录总数: %', profile_count;
  RAISE NOTICE '孤立的Auth用户: %', orphaned_count;
  RAISE NOTICE '无Profile的会话: %', sessions_without_profile;
  RAISE NOTICE '无会话的消息: %', messages_without_session;
  
  IF orphaned_count = 0 AND sessions_without_profile = 0 AND messages_without_session = 0 THEN
    RAISE NOTICE '✅ 所有数据已修复！';
  ELSE
    RAISE NOTICE '⚠️ 仍有数据需要修复';
  END IF;
END;
$$;

-- 9. 显示所有用户的当前状态
SELECT 
  au.email,
  CASE WHEN p.id IS NOT NULL THEN '✅' ELSE '❌' END as has_profile,
  CASE WHEN q.user_id IS NOT NULL THEN '✅' ELSE '❌' END as has_quota,
  CASE WHEN pref.user_id IS NOT NULL THEN '✅' ELSE '❌' END as has_preferences,
  COUNT(DISTINCT cs.id) as session_count,
  COUNT(DISTINCT cm.id) as message_count
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
LEFT JOIN user_ai_quotas q ON au.id = q.user_id
LEFT JOIN user_ai_preferences pref ON au.id = pref.user_id
LEFT JOIN chat_sessions cs ON au.id = cs.user_id
LEFT JOIN chat_messages cm ON cs.id = cm.session_id
GROUP BY au.id, au.email, p.id, q.user_id, pref.user_id
ORDER BY au.created_at DESC;