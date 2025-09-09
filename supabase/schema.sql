-- ============================================
-- Purple App Database Schema v2.0
-- Supabase PostgreSQL Database
-- ============================================

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- 1. 用户核心表
-- ============================================

-- 用户资料表
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  phone TEXT,
  subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'pro', 'unlimited')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 用户详细信息表（紫微斗数相关）
CREATE TABLE IF NOT EXISTS user_birth_info (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  name TEXT NOT NULL,
  gender TEXT CHECK (gender IN ('男', '女', '其他')),
  birth_date DATE NOT NULL,
  birth_time TIME NOT NULL,
  birth_location TEXT,
  birth_location_coords POINT,
  is_lunar BOOLEAN DEFAULT FALSE,
  timezone TEXT DEFAULT 'Asia/Shanghai',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. 星盘数据表
-- ============================================

-- 星盘数据表
CREATE TABLE IF NOT EXISTS star_charts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  chart_data JSONB NOT NULL,
  chart_image_url TEXT,
  interpretation_summary TEXT,
  version TEXT DEFAULT '1.0',
  is_primary BOOLEAN DEFAULT FALSE,
  generated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 添加唯一约束：每个用户只能有一个主星盘
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_primary_chart 
ON star_charts(user_id, is_primary) 
WHERE is_primary = TRUE;

-- 星盘解读缓存表
CREATE TABLE IF NOT EXISTS chart_interpretations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chart_id UUID REFERENCES star_charts(id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('性格', '事业', '爱情', '财富', '健康')),
  interpretation TEXT NOT NULL,
  confidence_score FLOAT DEFAULT 0.8 CHECK (confidence_score >= 0 AND confidence_score <= 1),
  generated_by TEXT DEFAULT 'AI',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 3. AI系统核心表
-- ============================================

-- AI会话管理表
CREATE TABLE IF NOT EXISTS chat_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT,
  context_summary TEXT,
  star_chart_id UUID REFERENCES star_charts(id),
  session_type TEXT DEFAULT 'general' CHECK (session_type IN ('general', 'chart_reading', 'fortune', 'consultation')),
  tokens_used INTEGER DEFAULT 0,
  model_preferences JSONB,
  quality_score FLOAT CHECK (quality_score >= 0 AND quality_score <= 5),
  is_archived BOOLEAN DEFAULT FALSE,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI消息表
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  content_type TEXT DEFAULT 'text' CHECK (content_type IN ('text', 'image', 'card')),
  tokens_count INTEGER,
  model_used TEXT,
  service_used TEXT,
  response_time_ms INTEGER,
  cost_credits FLOAT,
  is_starred BOOLEAN DEFAULT FALSE,
  is_hidden BOOLEAN DEFAULT FALSE,
  feedback TEXT CHECK (feedback IN ('good', 'bad', 'neutral')),
  feedback_text TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_session_created 
ON chat_messages(session_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_starred 
ON chat_messages(user_id, is_starred) 
WHERE is_starred = TRUE;

-- ============================================
-- 4. AI配置与优化表
-- ============================================

-- 用户AI偏好设置
CREATE TABLE IF NOT EXISTS user_ai_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  conversation_style TEXT DEFAULT 'balanced' CHECK (conversation_style IN ('professional', 'friendly', 'mystical', 'balanced')),
  response_length TEXT DEFAULT 'medium' CHECK (response_length IN ('brief', 'medium', 'detailed')),
  language_complexity TEXT DEFAULT 'normal' CHECK (language_complexity IN ('simple', 'normal', 'advanced')),
  use_terminology BOOLEAN DEFAULT TRUE,
  custom_personality TEXT,
  auto_include_chart BOOLEAN DEFAULT TRUE,
  preferred_topics TEXT[],
  avoided_topics TEXT[],
  enable_suggestions BOOLEAN DEFAULT TRUE,
  enable_voice_input BOOLEAN DEFAULT FALSE,
  enable_markdown BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI使用配额管理
CREATE TABLE IF NOT EXISTS user_ai_quotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  subscription_tier TEXT DEFAULT 'free',
  daily_limit INTEGER DEFAULT 50,
  monthly_limit INTEGER DEFAULT 1000,
  daily_used INTEGER DEFAULT 0,
  monthly_used INTEGER DEFAULT 0,
  total_tokens_used BIGINT DEFAULT 0,
  total_cost_credits FLOAT DEFAULT 0,
  daily_reset_at DATE DEFAULT CURRENT_DATE,
  monthly_reset_at DATE DEFAULT DATE_TRUNC('month', CURRENT_DATE),
  bonus_credits FLOAT DEFAULT 0,
  bonus_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 5. 运势与分析表
-- ============================================

-- 每日运势缓存
CREATE TABLE IF NOT EXISTS daily_fortunes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  fortune_date DATE NOT NULL,
  overall_score INTEGER CHECK (overall_score BETWEEN 0 AND 100),
  career_score INTEGER CHECK (career_score BETWEEN 0 AND 100),
  love_score INTEGER CHECK (love_score BETWEEN 0 AND 100),
  wealth_score INTEGER CHECK (wealth_score BETWEEN 0 AND 100),
  health_score INTEGER CHECK (health_score BETWEEN 0 AND 100),
  fortune_details JSONB,
  ai_interpretation TEXT,
  special_reminder TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, fortune_date)
);

-- ============================================
-- 6. Row Level Security (RLS) 策略
-- ============================================

-- 启用RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_birth_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE star_charts ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_fortunes ENABLE ROW LEVEL SECURITY;

-- 创建策略：用户只能访问自己的数据
CREATE POLICY "Users can view own profile" ON profiles
  FOR ALL USING (auth.uid() = id);

CREATE POLICY "Users can manage own birth info" ON user_birth_info
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own charts" ON star_charts
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own chat sessions" ON chat_sessions
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own messages" ON chat_messages
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own AI preferences" ON user_ai_preferences
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own quota" ON user_ai_quotas
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own fortunes" ON daily_fortunes
  FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- 7. 函数与触发器
-- ============================================

-- 自动更新updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为所有需要的表创建触发器
CREATE TRIGGER update_profiles_updated_at 
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_user_birth_info_updated_at 
  BEFORE UPDATE ON user_birth_info
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_star_charts_updated_at 
  BEFORE UPDATE ON star_charts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_chat_sessions_updated_at 
  BEFORE UPDATE ON chat_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_user_ai_preferences_updated_at 
  BEFORE UPDATE ON user_ai_preferences
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_user_ai_quotas_updated_at 
  BEFORE UPDATE ON user_ai_quotas
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 自动创建用户profile的函数
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  
  -- 创建默认的AI配额
  INSERT INTO user_ai_quotas (user_id, subscription_tier)
  VALUES (NEW.id, 'free')
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 当有新用户注册时自动创建profile
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 重置每日配额的函数
CREATE OR REPLACE FUNCTION reset_daily_quota()
RETURNS void AS $$
BEGIN
  UPDATE user_ai_quotas
  SET daily_used = 0, daily_reset_at = CURRENT_DATE
  WHERE daily_reset_at < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- 重置月度配额的函数
CREATE OR REPLACE FUNCTION reset_monthly_quota()
RETURNS void AS $$
BEGIN
  UPDATE user_ai_quotas
  SET monthly_used = 0, monthly_reset_at = DATE_TRUNC('month', CURRENT_DATE)
  WHERE monthly_reset_at < DATE_TRUNC('month', CURRENT_DATE);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 8. 初始数据（可选）
-- ============================================

-- 插入系统配置（如果有系统配置表）
-- INSERT INTO system_configs ...

-- ============================================
-- 9. 权限设置
-- ============================================

-- 确保anon和authenticated角色有适当的权限
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- ============================================
-- Schema创建完成！
-- ============================================