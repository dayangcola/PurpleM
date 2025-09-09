-- Supabase数据库架构
-- 用于Purple App的后端数据存储

-- 用户配置表
CREATE TABLE user_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name VARCHAR(100),
  gender VARCHAR(10),
  birth_date DATE,
  birth_time TIME,
  birth_location VARCHAR(200),
  is_lunar BOOLEAN DEFAULT false,
  has_chart BOOLEAN DEFAULT false,
  chart_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- 用户使用配额表
CREATE TABLE user_usage (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  daily_requests INTEGER DEFAULT 0,
  total_requests INTEGER DEFAULT 0,
  last_reset DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- 聊天历史表
CREATE TABLE chat_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  user_message TEXT NOT NULL,
  ai_response TEXT NOT NULL,
  tokens_used INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI人格配置表（可动态调整AI行为）
CREATE TABLE ai_personalities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  system_prompt TEXT NOT NULL,
  temperature DECIMAL(2,1) DEFAULT 0.8,
  max_tokens INTEGER DEFAULT 1000,
  model VARCHAR(50) DEFAULT 'gpt-4-turbo-preview',
  is_active BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 每日运势缓存表
CREATE TABLE daily_fortunes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  fortune_date DATE NOT NULL,
  fortune_data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, fortune_date)
);

-- 心情记录表
CREATE TABLE mood_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  mood_date DATE NOT NULL,
  mood_type VARCHAR(20) NOT NULL,
  mood_note TEXT,
  fortune_score INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, mood_date)
);

-- 创建索引
CREATE INDEX idx_chat_history_user_id ON chat_history(user_id);
CREATE INDEX idx_chat_history_created_at ON chat_history(created_at);
CREATE INDEX idx_user_usage_user_id ON user_usage(user_id);
CREATE INDEX idx_daily_fortunes_user_date ON daily_fortunes(user_id, fortune_date);
CREATE INDEX idx_mood_records_user_date ON mood_records(user_id, mood_date);

-- Row Level Security (RLS)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_fortunes ENABLE ROW LEVEL SECURITY;
ALTER TABLE mood_records ENABLE ROW LEVEL SECURITY;

-- RLS策略：用户只能访问自己的数据
CREATE POLICY "Users can view own profile" ON user_profiles
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own usage" ON user_usage
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own chat history" ON chat_history
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own fortunes" ON daily_fortunes
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own mood records" ON mood_records
  FOR ALL USING (auth.uid() = user_id);

-- 触发器：自动更新updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE
  ON user_profiles FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

CREATE TRIGGER update_ai_personalities_updated_at BEFORE UPDATE
  ON ai_personalities FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();