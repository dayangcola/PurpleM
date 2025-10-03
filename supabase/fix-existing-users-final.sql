-- ============================================
-- 修复现有用户的数据问题 - 最终版
-- 修正所有已知问题，包括session_type约束
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
  is_active,
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
  true,
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

-- 4. 修复user_ai_preferences
DELETE FROM user_ai_preferences 
WHERE user_id NOT IN (SELECT id FROM auth.users);

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

-- 5. 修复现有会话的session_type（将'chat'改为'general'）
UPDATE chat_sessions 
SET session_type = 'general' 
WHERE session_type = 'chat' OR session_type IS NULL;

-- 6. 清理孤立的会话和消息
DELETE FROM chat_messages
WHERE session_id NOT IN (SELECT id FROM chat_sessions);

DELETE FROM chat_messages
WHERE user_id NOT IN (SELECT id FROM profiles);

DELETE FROM chat_sessions
WHERE user_id NOT IN (SELECT id FROM profiles);

-- 7. 为每个用户确保至少有一个会话（使用正确的session_type）
INSERT INTO chat_sessions (
  id,
  user_id,
  title,
  session_type,  -- 使用正确的值
  created_at,
  updated_at
)
SELECT 
  gen_random_uuid(),
  p.id,
  '默认会话',
  'general',  -- 正确的session_type值
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
  invalid_session_types integer;
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
  
  SELECT COUNT(*) INTO invalid_session_types
  FROM chat_sessions
  WHERE session_type NOT IN ('general', 'chart_reading', 'fortune', 'consultation');
  
  RAISE NOTICE '========== 修复完成 ==========';
  RAISE NOTICE 'Auth用户总数: %', auth_count;
  RAISE NOTICE 'Profile记录总数: %', profile_count;
  RAISE NOTICE '孤立的Auth用户: %', orphaned_count;
  RAISE NOTICE '无Profile的会话: %', sessions_without_profile;
  RAISE NOTICE '无会话的消息: %', messages_without_session;
  RAISE NOTICE '无效的session_type: %', invalid_session_types;
  
  IF orphaned_count = 0 AND sessions_without_profile = 0 AND messages_without_session = 0 AND invalid_session_types = 0 THEN
    RAISE NOTICE '✅ 所有数据已完全修复！';
  ELSE
    RAISE NOTICE '⚠️ 仍有数据需要修复';
  END IF;
END;
$$;

-- 9. 显示所有用户的完整状态
SELECT 
  au.id as user_id,
  au.email,
  au.created_at as registered_at,
  CASE WHEN p.id IS NOT NULL THEN '✅' ELSE '❌' END as profile,
  CASE WHEN q.user_id IS NOT NULL THEN '✅' ELSE '❌' END as quota,
  CASE WHEN pref.user_id IS NOT NULL THEN '✅' ELSE '❌' END as preferences,
  COUNT(DISTINCT cs.id) as sessions,
  COUNT(DISTINCT cm.id) as messages,
  p.subscription_tier as tier
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
LEFT JOIN user_ai_quotas q ON au.id = q.user_id
LEFT JOIN user_ai_preferences pref ON au.id = pref.user_id
LEFT JOIN chat_sessions cs ON au.id = cs.user_id
LEFT JOIN chat_messages cm ON cs.id = cm.session_id
GROUP BY au.id, au.email, au.created_at, p.id, p.subscription_tier, q.user_id, pref.user_id
ORDER BY au.created_at DESC;

-- 10. 特别检查test@gmail.com用户（如果存在）
DO $$
DECLARE
  test_user_id uuid;
  test_profile_exists boolean;
  test_quota_exists boolean;
  test_pref_exists boolean;
  test_session_count integer;
BEGIN
  SELECT id INTO test_user_id FROM auth.users WHERE email = 'test@gmail.com';
  
  IF test_user_id IS NOT NULL THEN
    RAISE NOTICE '';
    RAISE NOTICE '========== test@gmail.com 用户详情 ==========';
    RAISE NOTICE '用户ID: %', test_user_id;
    
    SELECT EXISTS(SELECT 1 FROM profiles WHERE id = test_user_id) INTO test_profile_exists;
    SELECT EXISTS(SELECT 1 FROM user_ai_quotas WHERE user_id = test_user_id) INTO test_quota_exists;
    SELECT EXISTS(SELECT 1 FROM user_ai_preferences WHERE user_id = test_user_id) INTO test_pref_exists;
    SELECT COUNT(*) INTO test_session_count FROM chat_sessions WHERE user_id = test_user_id;
    
    IF test_profile_exists THEN
      RAISE NOTICE '✅ Profile记录: 存在';
    ELSE
      RAISE NOTICE '❌ Profile记录: 缺失 - 需要修复！';
    END IF;
    
    IF test_quota_exists THEN
      RAISE NOTICE '✅ 配额记录: 存在';
    ELSE
      RAISE NOTICE '❌ 配额记录: 缺失 - 需要修复！';
    END IF;
    
    IF test_pref_exists THEN
      RAISE NOTICE '✅ 偏好设置: 存在';
    ELSE
      RAISE NOTICE '❌ 偏好设置: 缺失 - 需要修复！';
    END IF;
    
    RAISE NOTICE '📊 会话数量: %', test_session_count;
    RAISE NOTICE '==============================================';
  ELSE
    RAISE NOTICE '⚠️ 未找到test@gmail.com用户在auth.users表中';
  END IF;
END;
$$;