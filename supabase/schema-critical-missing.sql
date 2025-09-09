-- ============================================
-- 关键缺失表 - 资深架构师深度分析后补充
-- 这些表对系统的完整性、可扩展性和运营至关重要
-- ============================================

-- ============================================
-- 1. 用户行为与分析系统
-- ============================================

-- 用户行为事件表（必须有！用于数据分析和个性化推荐）
CREATE TABLE IF NOT EXISTS user_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  session_id UUID,
  event_type TEXT NOT NULL, -- login/logout/view_chart/chat/fortune/share/purchase等
  event_category TEXT, -- auth/chart/ai/payment/social
  event_data JSONB, -- 灵活存储事件详情
  device_info JSONB, -- 设备、浏览器、APP版本等
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- 索引优化
  INDEX idx_user_events_user (user_id, created_at DESC),
  INDEX idx_user_events_type (event_type, created_at DESC),
  INDEX idx_user_events_session (session_id)
);

-- 用户会话表（追踪用户登录会话）
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  token_hash TEXT UNIQUE NOT NULL, -- 会话token的hash
  device_id TEXT,
  device_name TEXT,
  device_type TEXT, -- ios/android/web
  app_version TEXT,
  ip_address INET,
  location JSONB, -- {country, city, region}
  started_at TIMESTAMPTZ DEFAULT NOW(),
  last_activity_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE,
  
  INDEX idx_sessions_user (user_id, is_active),
  INDEX idx_sessions_token (token_hash)
);

-- 功能使用统计汇总表（预计算，提高查询性能）
CREATE TABLE IF NOT EXISTS feature_usage_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  feature_name TEXT NOT NULL, -- chart_generation/ai_chat/fortune_check等
  usage_date DATE NOT NULL,
  usage_count INTEGER DEFAULT 0,
  total_duration_seconds INTEGER DEFAULT 0,
  last_used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, feature_name, usage_date),
  INDEX idx_usage_stats (user_id, usage_date DESC)
);

-- ============================================
-- 2. 支付与订阅管理系统（核心商业功能）
-- ============================================

-- 订阅历史表（记录所有订阅变更）
CREATE TABLE IF NOT EXISTS subscription_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  subscription_id TEXT, -- 外部订阅ID（如Stripe）
  tier_from TEXT,
  tier_to TEXT NOT NULL,
  change_type TEXT NOT NULL, -- upgrade/downgrade/cancel/resume/new
  price_amount DECIMAL(10,2),
  currency TEXT DEFAULT 'CNY',
  billing_cycle TEXT, -- monthly/yearly
  started_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ,
  canceled_at TIMESTAMPTZ,
  cancel_reason TEXT,
  metadata JSONB, -- 存储外部平台数据
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_subscription_user (user_id, started_at DESC)
);

-- 支付记录表（所有支付流水）
CREATE TABLE IF NOT EXISTS payment_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  transaction_id TEXT UNIQUE NOT NULL, -- 外部交易ID
  payment_method TEXT NOT NULL, -- alipay/wechat/card/apple_pay
  payment_type TEXT NOT NULL, -- subscription/one_time/refund
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'CNY',
  status TEXT NOT NULL, -- pending/success/failed/refunded
  description TEXT,
  invoice_id UUID,
  metadata JSONB, -- 支付平台返回的数据
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_payment_user (user_id, created_at DESC),
  INDEX idx_payment_status (status, created_at DESC)
);

-- 优惠券/促销码表
CREATE TABLE IF NOT EXISTS coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  description TEXT,
  discount_type TEXT NOT NULL, -- percentage/fixed
  discount_value DECIMAL(10,2) NOT NULL,
  min_amount DECIMAL(10,2), -- 最低消费金额
  applicable_tiers TEXT[], -- 适用的订阅等级
  usage_limit INTEGER, -- 总使用次数限制
  usage_count INTEGER DEFAULT 0,
  user_limit INTEGER DEFAULT 1, -- 每用户使用次数
  valid_from TIMESTAMPTZ NOT NULL,
  valid_until TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_coupon_code (code),
  INDEX idx_coupon_valid (is_active, valid_from, valid_until)
);

-- 优惠券使用记录
CREATE TABLE IF NOT EXISTS coupon_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id UUID REFERENCES coupons(id),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  payment_id UUID REFERENCES payment_records(id),
  discount_amount DECIMAL(10,2),
  used_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(coupon_id, user_id, payment_id)
);

-- ============================================
-- 3. 通知与消息系统
-- ============================================

-- 通知模板表
CREATE TABLE IF NOT EXISTS notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  category TEXT NOT NULL, -- email/push/sms/in_app
  trigger_event TEXT NOT NULL, -- 触发事件
  subject TEXT, -- 邮件主题或推送标题
  content TEXT NOT NULL, -- 支持变量替换
  variables JSONB, -- 可用变量说明
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 通知发送记录表
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  template_id UUID REFERENCES notification_templates(id),
  channel TEXT NOT NULL, -- email/push/sms/in_app
  status TEXT NOT NULL, -- pending/sent/delivered/failed/read
  subject TEXT,
  content TEXT,
  metadata JSONB, -- 发送相关的元数据
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_notification_user (user_id, created_at DESC),
  INDEX idx_notification_status (status, scheduled_at)
);

-- 用户设备表（用于推送通知）
CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  device_token TEXT, -- FCM/APNS token
  device_type TEXT NOT NULL, -- ios/android/web
  device_name TEXT,
  device_model TEXT,
  app_version TEXT,
  os_version TEXT,
  push_enabled BOOLEAN DEFAULT TRUE,
  last_active_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, device_id),
  INDEX idx_device_user (user_id, last_active_at DESC)
);

-- ============================================
-- 4. 内容管理系统
-- ============================================

-- 文章/教程内容表
CREATE TABLE IF NOT EXISTS articles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL, -- URL友好的标识
  title TEXT NOT NULL,
  subtitle TEXT,
  content TEXT NOT NULL, -- Markdown格式
  category TEXT NOT NULL, -- tutorial/news/guide/knowledge
  tags TEXT[],
  author_id UUID REFERENCES profiles(id),
  cover_image_url TEXT,
  reading_time_minutes INTEGER,
  view_count INTEGER DEFAULT 0,
  like_count INTEGER DEFAULT 0,
  is_featured BOOLEAN DEFAULT FALSE,
  is_published BOOLEAN DEFAULT FALSE,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_article_slug (slug),
  INDEX idx_article_published (is_published, published_at DESC),
  INDEX idx_article_category (category, is_published)
);

-- 用户收藏表
CREATE TABLE IF NOT EXISTS user_favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  target_type TEXT NOT NULL, -- article/chart/message/fortune
  target_id UUID NOT NULL,
  notes TEXT, -- 用户备注
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, target_type, target_id),
  INDEX idx_favorite_user (user_id, created_at DESC)
);

-- ============================================
-- 5. 社交与分享系统
-- ============================================

-- 分享记录表
CREATE TABLE IF NOT EXISTS share_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  share_type TEXT NOT NULL, -- chart/fortune/article
  share_content_id UUID,
  share_channel TEXT NOT NULL, -- wechat/weibo/link/qr
  share_url TEXT,
  view_count INTEGER DEFAULT 0,
  click_count INTEGER DEFAULT 0,
  expires_at TIMESTAMPTZ, -- 分享链接过期时间
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_share_user (user_id, created_at DESC),
  INDEX idx_share_url (share_url)
);

-- 邀请记录表（用户增长）
CREATE TABLE IF NOT EXISTS invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  invitee_email TEXT,
  invitee_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  invitation_code TEXT UNIQUE NOT NULL,
  status TEXT DEFAULT 'pending', -- pending/accepted/expired
  reward_type TEXT, -- 奖励类型
  reward_value JSONB, -- 奖励内容
  accepted_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_invitation_code (invitation_code),
  INDEX idx_invitation_inviter (inviter_id)
);

-- ============================================
-- 6. 审计与合规系统（重要！）
-- ============================================

-- 审计日志表（记录所有重要操作）
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL, -- create/update/delete/login/export等
  entity_type TEXT NOT NULL, -- 操作的实体类型
  entity_id TEXT, -- 操作的实体ID
  old_values JSONB, -- 修改前的值
  new_values JSONB, -- 修改后的值
  ip_address INET,
  user_agent TEXT,
  request_id TEXT, -- 请求追踪ID
  metadata JSONB, -- 额外信息
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_audit_user (user_id, created_at DESC),
  INDEX idx_audit_entity (entity_type, entity_id),
  INDEX idx_audit_action (action, created_at DESC)
);

-- 用户同意记录表（GDPR/隐私合规）
CREATE TABLE IF NOT EXISTS user_consents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL, -- privacy_policy/terms/marketing/analytics
  consent_version TEXT NOT NULL, -- 条款版本
  is_granted BOOLEAN NOT NULL,
  granted_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, consent_type, consent_version),
  INDEX idx_consent_user (user_id, consent_type)
);

-- 数据删除请求表（GDPR Article 17）
CREATE TABLE IF NOT EXISTS data_deletion_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  request_type TEXT NOT NULL, -- delete_account/delete_data/anonymize
  reason TEXT,
  status TEXT DEFAULT 'pending', -- pending/processing/completed/rejected
  scheduled_at TIMESTAMPTZ,
  processed_at TIMESTAMPTZ,
  processed_by UUID REFERENCES profiles(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_deletion_status (status, scheduled_at)
);

-- ============================================
-- 7. 性能优化与监控系统
-- ============================================

-- API调用日志表（监控和限流）
CREATE TABLE IF NOT EXISTS api_call_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  endpoint TEXT NOT NULL,
  method TEXT NOT NULL,
  status_code INTEGER,
  response_time_ms INTEGER,
  request_size_bytes INTEGER,
  response_size_bytes INTEGER,
  error_message TEXT,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- 分区表按天
  INDEX idx_api_user_time (user_id, created_at DESC),
  INDEX idx_api_endpoint_time (endpoint, created_at DESC)
) PARTITION BY RANGE (created_at);

-- 异步任务队列表
CREATE TABLE IF NOT EXISTS job_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_type TEXT NOT NULL, -- email/push/chart_generation/export等
  priority INTEGER DEFAULT 5, -- 1-10，1最高
  status TEXT DEFAULT 'pending', -- pending/processing/completed/failed/canceled
  payload JSONB NOT NULL,
  result JSONB,
  attempts INTEGER DEFAULT 0,
  max_attempts INTEGER DEFAULT 3,
  scheduled_at TIMESTAMPTZ DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_job_status_priority (status, priority DESC, scheduled_at),
  INDEX idx_job_type (job_type, status)
);

-- 系统健康检查表
CREATE TABLE IF NOT EXISTS health_checks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_name TEXT NOT NULL, -- database/redis/ai_api/payment等
  status TEXT NOT NULL, -- healthy/degraded/unhealthy
  response_time_ms INTEGER,
  details JSONB,
  checked_at TIMESTAMPTZ DEFAULT NOW(),
  
  INDEX idx_health_service (service_name, checked_at DESC)
);

-- ============================================
-- 8. A/B测试与实验系统
-- ============================================

-- 实验配置表
CREATE TABLE IF NOT EXISTS experiments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  hypothesis TEXT, -- 实验假设
  metrics JSONB, -- 关注的指标
  variants JSONB NOT NULL, -- [{name: 'control', weight: 50}, {name: 'variant_a', weight: 50}]
  targeting_rules JSONB, -- 用户定向规则
  status TEXT DEFAULT 'draft', -- draft/running/paused/completed
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 用户实验分配表
CREATE TABLE IF NOT EXISTS experiment_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_id UUID REFERENCES experiments(id),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  variant TEXT NOT NULL,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(experiment_id, user_id),
  INDEX idx_assignment_user (user_id)
);

-- ============================================
-- Row Level Security 策略
-- ============================================

-- 为所有新表启用RLS
ALTER TABLE user_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_usage_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE share_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_call_logs ENABLE ROW LEVEL SECURITY;

-- 用户只能看自己的数据
CREATE POLICY "Users view own events" ON user_events FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users view own sessions" ON user_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users view own stats" ON feature_usage_stats FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users view own subscriptions" ON subscription_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users view own payments" ON payment_records FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users view own notifications" ON notifications FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own devices" ON user_devices FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own favorites" ON user_favorites FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users view own shares" ON share_records FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users manage own consents" ON user_consents FOR ALL USING (auth.uid() = user_id);

-- 公开内容
CREATE POLICY "Published articles are public" ON articles 
  FOR SELECT USING (is_published = TRUE);

CREATE POLICY "Authors can edit own articles" ON articles 
  FOR ALL USING (auth.uid() = author_id);

-- ============================================
-- 关键缺失表补充完成！
-- ============================================