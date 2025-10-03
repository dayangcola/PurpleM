-- ============================================
-- 补充缺失的表结构
-- 包含AI提示词模板和其他优化表
-- ============================================

-- AI提示词模板库
CREATE TABLE IF NOT EXISTS ai_prompt_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('system', 'chart_reading', 'fortune', 'personality', 'career', 'love', 'general')),
  description TEXT,
  template_content TEXT NOT NULL,
  variables JSONB,
  example_input TEXT,
  example_output TEXT,
  usage_count INTEGER DEFAULT 0,
  success_rate FLOAT,
  avg_user_rating FLOAT CHECK (avg_user_rating >= 0 AND avg_user_rating <= 5),
  is_public BOOLEAN DEFAULT FALSE,
  is_official BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES profiles(id),
  approved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI知识库表（紫微斗数专业知识）
CREATE TABLE IF NOT EXISTS ai_knowledge_base (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL CHECK (category IN ('基础概念', '十二宫位', '主星', '辅星', '四化', '格局', '其他')),
  subcategory TEXT,
  term TEXT NOT NULL,
  pinyin TEXT,
  traditional_name TEXT,
  definition TEXT NOT NULL,
  detailed_explanation TEXT,
  interpretations JSONB,
  combinations JSONB,
  examples JSONB,
  reference_sources TEXT[],
  confidence_score FLOAT DEFAULT 0.9 CHECK (confidence_score >= 0 AND confidence_score <= 1),
  review_status TEXT DEFAULT 'pending' CHECK (review_status IN ('pending', 'approved', 'rejected')),
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建全文搜索索引
CREATE INDEX IF NOT EXISTS idx_knowledge_search 
ON ai_knowledge_base USING gin(to_tsvector('simple', term || ' ' || COALESCE(definition, '') || ' ' || COALESCE(detailed_explanation, '')));

-- AI响应缓存表
CREATE TABLE IF NOT EXISTS ai_response_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  query_hash TEXT UNIQUE NOT NULL,
  query_text TEXT NOT NULL,
  context_hash TEXT,
  response_text TEXT NOT NULL,
  model_used TEXT,
  tokens_used INTEGER,
  hit_count INTEGER DEFAULT 0,
  last_hit_at TIMESTAMPTZ,
  cache_until TIMESTAMPTZ,
  is_permanent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建缓存过期索引
CREATE INDEX IF NOT EXISTS idx_cache_expiry 
ON ai_response_cache(cache_until) 
WHERE is_permanent = FALSE;

-- AI模型路由规则
CREATE TABLE IF NOT EXISTS ai_model_routing_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_name TEXT NOT NULL,
  description TEXT,
  priority INTEGER DEFAULT 100,
  condition_type TEXT NOT NULL CHECK (condition_type IN ('keyword', 'category', 'user_tier', 'time_range', 'token_count', 'default')),
  condition_value JSONB NOT NULL,
  primary_model TEXT NOT NULL,
  fallback_models TEXT[],
  max_tokens INTEGER DEFAULT 800,
  temperature FLOAT DEFAULT 0.8,
  timeout_ms INTEGER DEFAULT 8000,
  max_retries INTEGER DEFAULT 2,
  is_active BOOLEAN DEFAULT TRUE,
  valid_from TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 用户反馈与评价表
CREATE TABLE IF NOT EXISTS user_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  target_type TEXT NOT NULL CHECK (target_type IN ('message', 'fortune', 'interpretation', 'template')),
  target_id UUID NOT NULL,
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  feedback_text TEXT,
  feedback_tags TEXT[],
  is_public BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 系统配置表
CREATE TABLE IF NOT EXISTS system_configs (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- Row Level Security (RLS) 策略
-- ============================================

-- 启用RLS
ALTER TABLE ai_prompt_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_knowledge_base ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_response_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_model_routing_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_configs ENABLE ROW LEVEL SECURITY;

-- AI提示词模板策略
CREATE POLICY "Public templates are readable" ON ai_prompt_templates
  FOR SELECT USING (is_public = TRUE OR auth.uid() = created_by);

CREATE POLICY "Users can create own templates" ON ai_prompt_templates
  FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update own templates" ON ai_prompt_templates
  FOR UPDATE USING (auth.uid() = created_by);

CREATE POLICY "Users can delete own templates" ON ai_prompt_templates
  FOR DELETE USING (auth.uid() = created_by);

-- 知识库策略（已审核的公开可读）
CREATE POLICY "Approved knowledge is readable" ON ai_knowledge_base
  FOR SELECT USING (review_status = 'approved' OR auth.uid() = created_by);

CREATE POLICY "Users can suggest knowledge" ON ai_knowledge_base
  FOR INSERT WITH CHECK (auth.uid() = created_by);

-- 缓存策略（用户只能看自己的缓存）
CREATE POLICY "Users can view own cache" ON ai_response_cache
  FOR SELECT USING (TRUE); -- 缓存可以是共享的

-- 路由规则（只读）
CREATE POLICY "Routing rules are readable" ON ai_model_routing_rules
  FOR SELECT USING (is_active = TRUE);

-- 反馈策略
CREATE POLICY "Users can manage own feedback" ON user_feedback
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Public feedback is readable" ON user_feedback
  FOR SELECT USING (is_public = TRUE);

-- 系统配置（只读）
CREATE POLICY "System configs are readable" ON system_configs
  FOR SELECT USING (TRUE);

-- ============================================
-- 触发器
-- ============================================

-- 为新表添加updated_at触发器
CREATE TRIGGER update_ai_prompt_templates_updated_at 
  BEFORE UPDATE ON ai_prompt_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_ai_knowledge_base_updated_at 
  BEFORE UPDATE ON ai_knowledge_base
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_ai_model_routing_rules_updated_at 
  BEFORE UPDATE ON ai_model_routing_rules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_system_configs_updated_at 
  BEFORE UPDATE ON system_configs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- 辅助函数
-- ============================================

-- 搜索知识库的函数
CREATE OR REPLACE FUNCTION search_knowledge(query TEXT)
RETURNS TABLE (
  id UUID,
  term TEXT,
  definition TEXT,
  category TEXT,
  relevance FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    kb.id,
    kb.term,
    kb.definition,
    kb.category,
    ts_rank(
      to_tsvector('simple', kb.term || ' ' || COALESCE(kb.definition, '') || ' ' || COALESCE(kb.detailed_explanation, '')),
      plainto_tsquery('simple', query)
    ) AS relevance
  FROM ai_knowledge_base kb
  WHERE kb.review_status = 'approved'
    AND to_tsvector('simple', kb.term || ' ' || COALESCE(kb.definition, '') || ' ' || COALESCE(kb.detailed_explanation, ''))
        @@ plainto_tsquery('simple', query)
  ORDER BY relevance DESC
  LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- 获取用户今日使用量
CREATE OR REPLACE FUNCTION get_user_daily_usage(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_usage INTEGER;
BEGIN
  SELECT daily_used INTO v_usage
  FROM user_ai_quotas
  WHERE user_id = p_user_id
    AND daily_reset_at = CURRENT_DATE;
  
  RETURN COALESCE(v_usage, 0);
END;
$$ LANGUAGE plpgsql;

-- 增加配额使用量
CREATE OR REPLACE FUNCTION increment_quota_usage(p_user_id UUID, p_tokens INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
  v_quota RECORD;
BEGIN
  -- 获取用户配额
  SELECT * INTO v_quota
  FROM user_ai_quotas
  WHERE user_id = p_user_id
  FOR UPDATE;
  
  -- 检查是否需要重置
  IF v_quota.daily_reset_at < CURRENT_DATE THEN
    UPDATE user_ai_quotas
    SET daily_used = p_tokens,
        daily_reset_at = CURRENT_DATE
    WHERE user_id = p_user_id;
  ELSE
    -- 检查是否超出限制
    IF v_quota.subscription_tier != 'unlimited' 
       AND v_quota.daily_used + p_tokens > v_quota.daily_limit THEN
      RETURN FALSE;
    END IF;
    
    -- 更新使用量
    UPDATE user_ai_quotas
    SET daily_used = daily_used + p_tokens,
        total_tokens_used = total_tokens_used + p_tokens
    WHERE user_id = p_user_id;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 权限设置
-- ============================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- ============================================
-- 补充表结构创建完成！
-- ============================================