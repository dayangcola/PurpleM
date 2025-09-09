# 🚀 Purple App + Supabase 完整集成方案 v2.0

## 目录
1. [系统架构总览](#一系统架构总览)
2. [完整数据库设计](#二完整数据库设计)
3. [iOS端集成方案](#三ios端集成方案)
4. [实施计划](#四实施计划5个阶段)
5. [关键技术细节](#五关键技术细节)
6. [预期成果](#六预期成果)
7. [风险控制](#七风险控制)
8. [执行检查清单](#八执行检查清单)

---

## 一、系统架构总览

```
┌─────────────────────────────────────────┐
│            iOS App (Swift)               │
│  ┌─────────────────────────────────────┐│
│  │   Supabase Swift SDK                ││
│  │   - Auth / Database / Storage       ││
│  └─────────────────────────────────────┘│
└────────────┬────────────────────────────┘
             │ HTTPS + JWT
┌────────────▼────────────────────────────┐
│         Supabase Cloud                  │
│  ┌──────────────────────────────────┐   │
│  │  Auth Service (用户认证)          │   │
│  │  - Email/Password                │   │
│  │  - Social Login (可选)           │   │
│  └──────────────────────────────────┘   │
│  ┌──────────────────────────────────┐   │
│  │  PostgreSQL Database             │   │
│  │  - User Data + AI System         │   │
│  │  - Row Level Security (RLS)      │   │
│  └──────────────────────────────────┘   │
│  ┌──────────────────────────────────┐   │
│  │  Edge Functions                  │   │
│  │  - AI Gateway Proxy              │   │
│  │  - Data Processing               │   │
│  └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────┐
│      External Services                  │
│  - Vercel AI Gateway                    │
│  - OpenAI API (Backup)                  │
└──────────────────────────────────────────┘
```

## 二、完整数据库设计

### 2.1 用户核心表

```sql
-- ============================================
-- 1. 用户核心表
-- ============================================

-- 用户资料表
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  phone TEXT,
  subscription_tier TEXT DEFAULT 'free', -- free/pro/unlimited
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 用户详细信息表（紫微斗数相关）
CREATE TABLE user_birth_info (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  name TEXT NOT NULL,
  gender TEXT CHECK (gender IN ('男', '女', '其他')),
  birth_date DATE NOT NULL,
  birth_time TIME NOT NULL,
  birth_location TEXT,
  birth_location_coords POINT, -- PostgreSQL地理坐标
  is_lunar BOOLEAN DEFAULT FALSE,
  timezone TEXT DEFAULT 'Asia/Shanghai',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 2.2 星盘数据表

```sql
-- ============================================
-- 2. 星盘数据表
-- ============================================

-- 星盘数据表
CREATE TABLE star_charts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  chart_data JSONB NOT NULL, -- 完整的iztro计算结果
  chart_image_url TEXT, -- 星盘图片URL（如果生成）
  interpretation_summary TEXT, -- AI生成的简要解读
  version TEXT DEFAULT '1.0', -- 算法版本
  is_primary BOOLEAN DEFAULT FALSE, -- 是否为主星盘
  generated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, is_primary) -- 每个用户只有一个主星盘
);

-- 星盘解读缓存表
CREATE TABLE chart_interpretations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chart_id UUID REFERENCES star_charts(id) ON DELETE CASCADE,
  category TEXT NOT NULL, -- 性格/事业/爱情/财富/健康
  interpretation TEXT NOT NULL,
  confidence_score FLOAT DEFAULT 0.8,
  generated_by TEXT DEFAULT 'AI', -- AI/Expert/System
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 2.3 AI系统核心表

```sql
-- ============================================
-- 3. AI系统核心表
-- ============================================

-- AI会话管理表
CREATE TABLE chat_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT,
  context_summary TEXT, -- AI生成的上下文摘要
  star_chart_id UUID REFERENCES star_charts(id), -- 关联的星盘
  session_type TEXT DEFAULT 'general', -- general/chart_reading/fortune/consultation
  tokens_used INTEGER DEFAULT 0,
  model_preferences JSONB, -- 本会话的模型偏好设置
  quality_score FLOAT,
  is_archived BOOLEAN DEFAULT FALSE,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI消息表（优化版）
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  content_type TEXT DEFAULT 'text', -- text/image/card
  tokens_count INTEGER,
  model_used TEXT,
  service_used TEXT, -- AI Gateway/OpenAI/Fallback
  response_time_ms INTEGER,
  cost_credits FLOAT, -- 消耗的积分
  is_starred BOOLEAN DEFAULT FALSE,
  is_hidden BOOLEAN DEFAULT FALSE, -- 用户可以隐藏某些消息
  feedback TEXT CHECK (feedback IN ('good', 'bad', 'neutral')),
  feedback_text TEXT,
  metadata JSONB, -- 额外元数据
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- 索引优化
  INDEX idx_session_created (session_id, created_at DESC),
  INDEX idx_user_starred (user_id, is_starred) WHERE is_starred = TRUE
);

-- AI知识库表（紫微斗数专业知识）
CREATE TABLE ai_knowledge_base (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL, -- 基础概念/十二宫位/主星/辅星/四化/格局
  subcategory TEXT,
  term TEXT NOT NULL, -- 术语
  pinyin TEXT, -- 拼音
  traditional_name TEXT, -- 繁体名称
  definition TEXT NOT NULL,
  detailed_explanation TEXT,
  interpretations JSONB, -- 不同情况下的解释
  combinations JSONB, -- 与其他星曜的组合
  examples JSONB,
  references TEXT[], -- 参考文献
  confidence_score FLOAT DEFAULT 0.9,
  review_status TEXT DEFAULT 'pending', -- pending/approved/rejected
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- 全文搜索索引
  search_vector tsvector GENERATED ALWAYS AS (
    to_tsvector('chinese', term || ' ' || COALESCE(definition, '') || ' ' || COALESCE(detailed_explanation, ''))
  ) STORED,
  INDEX idx_search_vector (search_vector) USING gin
);
```

### 2.4 AI配置与优化表

```sql
-- ============================================
-- 4. AI配置与优化表
-- ============================================

-- 用户AI偏好设置
CREATE TABLE user_ai_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  -- 对话风格
  conversation_style TEXT DEFAULT 'balanced', -- professional/friendly/mystical/balanced
  response_length TEXT DEFAULT 'medium', -- brief/medium/detailed
  language_complexity TEXT DEFAULT 'normal', -- simple/normal/advanced
  use_terminology BOOLEAN DEFAULT TRUE, -- 是否使用专业术语
  
  -- 个性化设置
  custom_personality TEXT, -- 用户自定义AI人格
  auto_include_chart BOOLEAN DEFAULT TRUE, -- 自动包含星盘上下文
  preferred_topics TEXT[], -- 偏好话题
  avoided_topics TEXT[], -- 避免话题
  
  -- 功能设置
  enable_suggestions BOOLEAN DEFAULT TRUE, -- 启用建议问题
  enable_voice_input BOOLEAN DEFAULT FALSE, -- 语音输入
  enable_markdown BOOLEAN DEFAULT TRUE, -- Markdown格式
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI使用配额管理
CREATE TABLE user_ai_quotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  subscription_tier TEXT DEFAULT 'free',
  
  -- 配额限制
  daily_limit INTEGER DEFAULT 50,
  monthly_limit INTEGER DEFAULT 1000,
  
  -- 当前使用量
  daily_used INTEGER DEFAULT 0,
  monthly_used INTEGER DEFAULT 0,
  total_tokens_used BIGINT DEFAULT 0,
  total_cost_credits FLOAT DEFAULT 0,
  
  -- 重置时间
  daily_reset_at DATE DEFAULT CURRENT_DATE,
  monthly_reset_at DATE DEFAULT DATE_TRUNC('month', CURRENT_DATE),
  
  -- 额外配额
  bonus_credits FLOAT DEFAULT 0,
  bonus_expires_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI提示词模板库
CREATE TABLE ai_prompt_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL, -- system/chart_reading/fortune/personality/career/love
  description TEXT,
  template_content TEXT NOT NULL, -- 支持变量如 {{user_name}}, {{chart_data}}
  variables JSONB, -- 变量说明
  example_input TEXT,
  example_output TEXT,
  
  -- 使用统计
  usage_count INTEGER DEFAULT 0,
  success_rate FLOAT,
  avg_user_rating FLOAT,
  
  -- 权限控制
  is_public BOOLEAN DEFAULT FALSE,
  is_official BOOLEAN DEFAULT FALSE, -- 官方模板
  created_by UUID REFERENCES profiles(id),
  approved_by UUID REFERENCES profiles(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI响应缓存表
CREATE TABLE ai_response_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  query_hash TEXT UNIQUE NOT NULL, -- SHA256(query + context)
  query_text TEXT NOT NULL,
  context_hash TEXT,
  response_text TEXT NOT NULL,
  model_used TEXT,
  tokens_used INTEGER,
  
  -- 缓存管理
  hit_count INTEGER DEFAULT 0,
  last_hit_at TIMESTAMPTZ,
  cache_until TIMESTAMPTZ, -- 缓存过期时间
  is_permanent BOOLEAN DEFAULT FALSE, -- 永久缓存（如通用问题）
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- 自动清理过期缓存
  INDEX idx_cache_expiry (cache_until) WHERE is_permanent = FALSE
);

-- AI模型路由规则
CREATE TABLE ai_model_routing_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_name TEXT NOT NULL,
  description TEXT,
  priority INTEGER DEFAULT 100, -- 优先级，数字越小优先级越高
  
  -- 匹配条件
  condition_type TEXT NOT NULL, -- keyword/category/user_tier/time_range/token_count
  condition_value JSONB NOT NULL,
  
  -- 路由目标
  primary_model TEXT NOT NULL,
  fallback_models TEXT[],
  
  -- 配置参数
  max_tokens INTEGER DEFAULT 800,
  temperature FLOAT DEFAULT 0.8,
  timeout_ms INTEGER DEFAULT 8000,
  max_retries INTEGER DEFAULT 2,
  
  -- 状态
  is_active BOOLEAN DEFAULT TRUE,
  valid_from TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 2.5 运势与分析表

```sql
-- ============================================
-- 5. 运势与分析表
-- ============================================

-- 每日运势缓存
CREATE TABLE daily_fortunes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  fortune_date DATE NOT NULL,
  
  -- 运势数据
  overall_score INTEGER CHECK (overall_score BETWEEN 0 AND 100),
  career_score INTEGER CHECK (career_score BETWEEN 0 AND 100),
  love_score INTEGER CHECK (love_score BETWEEN 0 AND 100),
  wealth_score INTEGER CHECK (wealth_score BETWEEN 0 AND 100),
  health_score INTEGER CHECK (health_score BETWEEN 0 AND 100),
  
  -- 详细内容
  fortune_details JSONB, -- 包含幸运色、数字、方位等
  ai_interpretation TEXT, -- AI生成的运势解读
  special_reminder TEXT, -- 特别提醒
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, fortune_date)
);

-- 用户反馈与评价
CREATE TABLE user_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  target_type TEXT NOT NULL, -- message/fortune/interpretation
  target_id UUID NOT NULL,
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  feedback_text TEXT,
  feedback_tags TEXT[], -- 准确/有帮助/模糊/不准确
  is_public BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 2.6 系统配置表

```sql
-- ============================================
-- 6. 系统配置表
-- ============================================

-- 系统配置表
CREATE TABLE system_configs (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 插入默认配置
INSERT INTO system_configs (key, value, description) VALUES
  ('ai_models', '{"default": "gpt-3.5-turbo", "premium": "gpt-4", "fallback": ["claude-3-haiku", "mixtral-8x7b"]}', 'AI模型配置'),
  ('subscription_tiers', '{"free": {"daily_limit": 50, "features": ["basic_chat", "daily_fortune"]}, "pro": {"daily_limit": 500, "features": ["all"]}}', '订阅等级配置'),
  ('cache_ttl', '{"general": 3600, "fortune": 86400, "chart": 604800}', '缓存过期时间（秒）');
```

### 2.7 Row Level Security (RLS) 策略

```sql
-- ============================================
-- 7. Row Level Security (RLS) 策略
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

-- 用户只能访问自己的数据
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

-- 公开的知识库所有人可读
CREATE POLICY "Public knowledge is readable" ON ai_knowledge_base
  FOR SELECT USING (review_status = 'approved');
```

### 2.8 函数与触发器

```sql
-- ============================================
-- 8. 函数与触发器
-- ============================================

-- 自动更新updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 应用到所有表
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  
CREATE TRIGGER update_user_birth_info_updated_at BEFORE UPDATE ON user_birth_info
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  
CREATE TRIGGER update_star_charts_updated_at BEFORE UPDATE ON star_charts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  
CREATE TRIGGER update_chat_sessions_updated_at BEFORE UPDATE ON chat_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  
CREATE TRIGGER update_user_ai_preferences_updated_at BEFORE UPDATE ON user_ai_preferences
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  
CREATE TRIGGER update_user_ai_quotas_updated_at BEFORE UPDATE ON user_ai_quotas
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 自动重置每日配额
CREATE OR REPLACE FUNCTION reset_daily_quota()
RETURNS void AS $$
BEGIN
  UPDATE user_ai_quotas
  SET daily_used = 0, daily_reset_at = CURRENT_DATE
  WHERE daily_reset_at < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- 自动重置月度配额
CREATE OR REPLACE FUNCTION reset_monthly_quota()
RETURNS void AS $$
BEGIN
  UPDATE user_ai_quotas
  SET monthly_used = 0, monthly_reset_at = DATE_TRUNC('month', CURRENT_DATE)
  WHERE monthly_reset_at < DATE_TRUNC('month', CURRENT_DATE);
END;
$$ LANGUAGE plpgsql;

-- 计算并缓存运势
CREATE OR REPLACE FUNCTION calculate_daily_fortune(p_user_id UUID, p_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_chart JSONB;
  v_fortune JSONB;
BEGIN
  -- 获取用户星盘
  SELECT chart_data INTO v_chart
  FROM star_charts
  WHERE user_id = p_user_id AND is_primary = TRUE;
  
  -- 这里调用运势计算逻辑
  -- 实际实现会更复杂，这里是示例
  v_fortune := jsonb_build_object(
    'overall', floor(random() * 100),
    'career', floor(random() * 100),
    'love', floor(random() * 100),
    'wealth', floor(random() * 100),
    'health', floor(random() * 100),
    'lucky_color', ARRAY['红色', '紫色', '金色'][floor(random() * 3) + 1],
    'lucky_number', floor(random() * 9) + 1,
    'lucky_direction', ARRAY['东', '南', '西', '北'][floor(random() * 4) + 1]
  );
  
  RETURN v_fortune;
END;
$$ LANGUAGE plpgsql;

-- 清理过期缓存
CREATE OR REPLACE FUNCTION cleanup_expired_cache()
RETURNS void AS $$
BEGIN
  DELETE FROM ai_response_cache
  WHERE cache_until < NOW() AND is_permanent = FALSE;
END;
$$ LANGUAGE plpgsql;

-- 创建定时任务（需要pg_cron扩展）
-- SELECT cron.schedule('reset-daily-quota', '0 0 * * *', 'SELECT reset_daily_quota()');
-- SELECT cron.schedule('reset-monthly-quota', '0 0 1 * *', 'SELECT reset_monthly_quota()');
-- SELECT cron.schedule('cleanup-cache', '0 * * * *', 'SELECT cleanup_expired_cache()');
```

## 三、iOS端集成方案

### 3.1 依赖配置

```swift
// Package.swift
import PackageDescription

let package = Package(
    name: "PurpleM",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "3.0.0"),
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "PurpleM",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "Alamofire", package: "Alamofire")
            ]
        )
    ]
)
```

### 3.2 核心服务类设计

#### SupabaseManager.swift
```swift
import Foundation
import Supabase
import KeychainAccess

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    @Published var session: Session?
    @Published var profile: UserProfile?
    @Published var isAuthenticated = false
    
    private let keychain = Keychain(service: "com.purple.app")
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
        
        setupAuthListener()
        restoreSession()
    }
    
    private func setupAuthListener() {
        client.auth.onAuthStateChange { [weak self] event, session in
            DispatchQueue.main.async {
                self?.session = session
                self?.isAuthenticated = session != nil
                
                if let session = session {
                    self?.saveSession(session)
                    Task {
                        await self?.loadUserProfile()
                    }
                } else {
                    self?.clearSession()
                }
            }
        }
    }
    
    private func saveSession(_ session: Session) {
        try? keychain.set(session.accessToken, key: "access_token")
        try? keychain.set(session.refreshToken ?? "", key: "refresh_token")
    }
    
    private func clearSession() {
        try? keychain.remove("access_token")
        try? keychain.remove("refresh_token")
        profile = nil
    }
    
    private func restoreSession() {
        guard let accessToken = try? keychain.getString("access_token"),
              let refreshToken = try? keychain.getString("refresh_token") else {
            return
        }
        
        Task {
            try? await client.auth.setSession(
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        }
    }
    
    func loadUserProfile() async {
        guard let userId = session?.user.id else { return }
        
        do {
            let response = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
            
            if let profileData = response.data {
                let profile = try JSONDecoder().decode(UserProfile.self, from: profileData)
                
                DispatchQueue.main.async {
                    self.profile = profile
                }
            }
        } catch {
            print("Failed to load profile: \(error)")
        }
    }
}
```

#### AuthService.swift
```swift
import Foundation
import Supabase

class AuthService: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    
    private let supabase = SupabaseManager.shared.client
    
    // 注册
    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["name": name]
            )
            
            if let user = response.user {
                // 创建用户profile
                try await createProfile(userId: user.id, email: email, name: name)
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // 登录
    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil
        
        do {
            try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // 登出
    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
    }
    
    // 重置密码
    func resetPassword(email: String) async {
        isLoading = true
        error = nil
        
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func createProfile(userId: UUID, email: String, name: String) async throws {
        let profile = [
            "id": userId.uuidString,
            "email": email,
            "full_name": name,
            "subscription_tier": "free"
        ]
        
        try await supabase
            .from("profiles")
            .insert(profile)
            .execute()
        
        // 创建AI配额记录
        let quota = [
            "user_id": userId.uuidString,
            "subscription_tier": "free"
        ]
        
        try await supabase
            .from("user_ai_quotas")
            .insert(quota)
            .execute()
    }
}
```

#### DataSyncService.swift
```swift
import Foundation
import Supabase

class DataSyncService {
    private let supabase = SupabaseManager.shared.client
    private let userDataManager = UserDataManager.shared
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed(Error)
    }
    
    @Published var syncStatus: SyncStatus = .idle
    
    // 同步本地数据到云端
    func syncLocalToCloud() async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        
        syncStatus = .syncing
        
        do {
            // 1. 同步用户出生信息
            if let userInfo = userDataManager.currentUser {
                let birthInfo = [
                    "user_id": userId.uuidString,
                    "name": userInfo.name,
                    "gender": userInfo.gender,
                    "birth_date": ISO8601DateFormatter().string(from: userInfo.birthDate),
                    "birth_time": formatTime(userInfo.birthTime),
                    "birth_location": userInfo.birthLocation,
                    "is_lunar": userInfo.isLunar
                ]
                
                try await supabase
                    .from("user_birth_info")
                    .upsert(birthInfo)
                    .execute()
            }
            
            // 2. 同步星盘数据
            if let chartData = userDataManager.currentChart {
                let chart = [
                    "user_id": userId.uuidString,
                    "chart_data": chartData.toJSON(),
                    "is_primary": true
                ]
                
                try await supabase
                    .from("star_charts")
                    .upsert(chart)
                    .execute()
            }
            
            syncStatus = .success
            
        } catch {
            syncStatus = .failed(error)
        }
    }
    
    // 从云端同步到本地
    func syncCloudToLocal() async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        
        syncStatus = .syncing
        
        do {
            // 1. 获取用户出生信息
            let birthInfoResponse = try await supabase
                .from("user_birth_info")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            if let data = birthInfoResponse.data {
                let birthInfo = try JSONDecoder().decode(CloudBirthInfo.self, from: data)
                userDataManager.updateFromCloud(birthInfo)
            }
            
            // 2. 获取星盘数据
            let chartResponse = try await supabase
                .from("star_charts")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_primary", value: true)
                .single()
                .execute()
            
            if let data = chartResponse.data {
                let chart = try JSONDecoder().decode(CloudChart.self, from: data)
                userDataManager.updateChartFromCloud(chart)
            }
            
            syncStatus = .success
            
        } catch {
            syncStatus = .failed(error)
        }
    }
    
    // 解决冲突
    func resolveConflicts() async {
        // 实现冲突解决策略
        // 例如：最新优先、云端优先、本地优先等
        
        let localModified = userDataManager.lastModified
        
        // 获取云端最后修改时间
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        
        do {
            let response = try await supabase
                .from("user_birth_info")
                .select("updated_at")
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            // 比较时间戳并决定同步方向
            // ...实现具体逻辑
            
        } catch {
            print("Conflict resolution failed: \(error)")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
```

#### AIService增强版.swift
```swift
import Foundation
import Supabase

class AIService: ObservableObject {
    @Published var currentSession: ChatSession?
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var quota: UserQuota?
    
    private let supabase = SupabaseManager.shared.client
    
    // 创建新会话
    func createSession(type: SessionType = .general) async -> ChatSession? {
        guard let userId = SupabaseManager.shared.session?.user.id else { return nil }
        
        let sessionData = [
            "user_id": userId.uuidString,
            "session_type": type.rawValue,
            "title": generateSessionTitle(type: type)
        ]
        
        do {
            let response = try await supabase
                .from("chat_sessions")
                .insert(sessionData)
                .select()
                .single()
                .execute()
            
            if let data = response.data {
                let session = try JSONDecoder().decode(ChatSession.self, from: data)
                
                DispatchQueue.main.async {
                    self.currentSession = session
                }
                
                return session
            }
        } catch {
            print("Failed to create session: \(error)")
        }
        
        return nil
    }
    
    // 发送消息（增强版）
    func sendMessage(content: String, session: ChatSession? = nil) async {
        isLoading = true
        error = nil
        
        // 确保有会话
        var activeSession = session ?? currentSession
        if activeSession == nil {
            activeSession = await createSession()
        }
        
        guard let sessionId = activeSession?.id,
              let userId = SupabaseManager.shared.session?.user.id else {
            error = "无法创建会话"
            isLoading = false
            return
        }
        
        // 检查配额
        if let quota = await checkQuota(), quota.isExhausted {
            error = "今日配额已用完"
            isLoading = false
            return
        }
        
        // 保存用户消息
        let userMessage = [
            "session_id": sessionId.uuidString,
            "user_id": userId.uuidString,
            "role": "user",
            "content": content
        ]
        
        do {
            try await supabase
                .from("chat_messages")
                .insert(userMessage)
                .execute()
            
            // 构建智能上下文
            let context = await buildSmartContext(for: content, session: activeSession!)
            
            // 调用AI API
            let response = await callAIWithContext(
                message: content,
                context: context
            )
            
            // 保存AI响应
            let aiMessage = [
                "session_id": sessionId.uuidString,
                "user_id": userId.uuidString,
                "role": "assistant",
                "content": response.content,
                "model_used": response.model,
                "service_used": response.service,
                "tokens_count": response.tokens,
                "response_time_ms": response.responseTime
            ]
            
            try await supabase
                .from("chat_messages")
                .insert(aiMessage)
                .execute()
            
            // 更新本地消息列表
            await loadMessages(for: activeSession!)
            
            // 更新配额
            await updateQuotaUsage(tokens: response.tokens)
            
            isLoading = false
            
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // 构建智能上下文
    private func buildSmartContext(for message: String, session: ChatSession) async -> AIContext {
        guard let userId = SupabaseManager.shared.session?.user.id else {
            return AIContext()
        }
        
        var context = AIContext()
        
        // 1. 获取最近的相关消息
        do {
            let recentMessages = try await supabase
                .from("chat_messages")
                .select()
                .eq("session_id", value: session.id.uuidString)
                .order("created_at", ascending: false)
                .limit(10)
                .execute()
            
            if let data = recentMessages.data {
                context.recentMessages = try JSONDecoder().decode([ChatMessage].self, from: data)
            }
        } catch {
            print("Failed to load recent messages: \(error)")
        }
        
        // 2. 获取标记的重要消息
        do {
            let starredMessages = try await supabase
                .from("chat_messages")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_starred", value: true)
                .limit(5)
                .execute()
            
            if let data = starredMessages.data {
                context.starredMessages = try JSONDecoder().decode([ChatMessage].self, from: data)
            }
        } catch {
            print("Failed to load starred messages: \(error)")
        }
        
        // 3. 获取用户星盘摘要
        if let chartId = session.starChartId {
            do {
                let chartResponse = try await supabase
                    .from("star_charts")
                    .select("interpretation_summary")
                    .eq("id", value: chartId.uuidString)
                    .single()
                    .execute()
                
                if let data = chartResponse.data {
                    let chart = try JSONDecoder().decode(ChartSummary.self, from: data)
                    context.chartSummary = chart.interpretationSummary
                }
            } catch {
                print("Failed to load chart summary: \(error)")
            }
        }
        
        // 4. 搜索知识库
        context.relevantKnowledge = await searchKnowledgeBase(for: message)
        
        // 5. 获取用户偏好
        context.userPreferences = await loadUserPreferences()
        
        return context
    }
    
    // 搜索知识库
    private func searchKnowledgeBase(for query: String) async -> [KnowledgeItem] {
        do {
            let response = try await supabase
                .rpc("search_knowledge", params: ["query": query])
                .execute()
            
            if let data = response.data {
                return try JSONDecoder().decode([KnowledgeItem].self, from: data)
            }
        } catch {
            print("Knowledge search failed: \(error)")
        }
        
        return []
    }
    
    // 加载用户偏好
    private func loadUserPreferences() async -> AIPreferences? {
        guard let userId = SupabaseManager.shared.session?.user.id else { return nil }
        
        do {
            let response = try await supabase
                .from("user_ai_preferences")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            if let data = response.data {
                return try JSONDecoder().decode(AIPreferences.self, from: data)
            }
        } catch {
            print("Failed to load preferences: \(error)")
        }
        
        return nil
    }
    
    // 检查配额
    private func checkQuota() async -> UserQuota? {
        guard let userId = SupabaseManager.shared.session?.user.id else { return nil }
        
        do {
            let response = try await supabase
                .from("user_ai_quotas")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            if let data = response.data {
                let quota = try JSONDecoder().decode(UserQuota.self, from: data)
                
                DispatchQueue.main.async {
                    self.quota = quota
                }
                
                return quota
            }
        } catch {
            print("Failed to check quota: \(error)")
        }
        
        return nil
    }
    
    // 更新配额使用
    private func updateQuotaUsage(tokens: Int) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }
        
        do {
            try await supabase
                .rpc("increment_quota_usage", params: [
                    "p_user_id": userId.uuidString,
                    "p_tokens": tokens
                ])
                .execute()
        } catch {
            print("Failed to update quota: \(error)")
        }
    }
    
    // 加载历史消息
    func loadMessages(for session: ChatSession) async {
        do {
            let response = try await supabase
                .from("chat_messages")
                .select()
                .eq("session_id", value: session.id.uuidString)
                .order("created_at", ascending: true)
                .execute()
            
            if let data = response.data {
                let messages = try JSONDecoder().decode([ChatMessage].self, from: data)
                
                DispatchQueue.main.async {
                    self.messages = messages
                }
            }
        } catch {
            print("Failed to load messages: \(error)")
        }
    }
    
    // 生成会话标题
    private func generateSessionTitle(type: SessionType) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        let dateString = formatter.string(from: Date())
        
        switch type {
        case .general:
            return "对话 - \(dateString)"
        case .chartReading:
            return "星盘解读 - \(dateString)"
        case .fortune:
            return "运势咨询 - \(dateString)"
        case .consultation:
            return "专业咨询 - \(dateString)"
        }
    }
    
    // 调用AI API（支持多模型路由）
    private func callAIWithContext(message: String, context: AIContext) async -> AIResponse {
        // 实际实现会调用后端API
        // 这里是示例结构
        
        let requestBody: [String: Any] = [
            "message": message,
            "context": context.toDictionary(),
            "preferences": context.userPreferences?.toDictionary() ?? [:]
        ]
        
        // 调用后端API...
        
        return AIResponse(
            content: "AI响应内容",
            model: "gpt-3.5-turbo",
            service: "AI Gateway",
            tokens: 150,
            responseTime: 1200
        )
    }
}
```

## 四、实施计划（5个阶段）

### Phase 1: 基础设施搭建（Day 1-2）

#### Day 1: Supabase项目初始化
- [ ] 创建Supabase项目
- [ ] 配置项目基本信息
- [ ] 获取API密钥和URL
- [ ] 创建数据库schema（执行SQL脚本）
- [ ] 配置RLS策略
- [ ] 测试数据库连接

#### Day 2: iOS SDK集成
- [ ] 添加Supabase Swift SDK依赖
- [ ] 配置项目环境变量
- [ ] 实现SupabaseManager
- [ ] 创建认证UI界面
- [ ] 实现登录/注册功能
- [ ] 测试认证流程

### Phase 2: 数据迁移系统（Day 3-4）

#### Day 3: 迁移适配器开发
- [ ] 创建本地数据模型映射
- [ ] 实现数据读取适配器
- [ ] 实现数据写入适配器
- [ ] 开发冲突检测机制
- [ ] 实现冲突解决策略

#### Day 4: 同步机制实现
- [ ] 实现双向同步逻辑
- [ ] 添加离线模式支持
- [ ] 创建同步状态UI
- [ ] 实现后台同步任务
- [ ] 测试数据同步功能

### Phase 3: AI系统升级（Day 5-7）

#### Day 5: 会话管理系统
- [ ] 实现会话创建/管理
- [ ] 开发会话列表UI
- [ ] 实现会话切换功能
- [ ] 添加会话归档功能
- [ ] 测试会话管理

#### Day 6: 智能上下文系统
- [ ] 实现上下文构建器
- [ ] 集成知识库搜索
- [ ] 实现消息历史加载
- [ ] 添加重要消息标记
- [ ] 优化上下文选择算法

#### Day 7: 配额和缓存系统
- [ ] 实现配额检查机制
- [ ] 开发配额显示UI
- [ ] 实现响应缓存逻辑
- [ ] 添加缓存命中统计
- [ ] 测试配额控制

### Phase 4: 高级功能（Day 8-9）

#### Day 8: 个性化设置
- [ ] 创建AI偏好设置界面
- [ ] 实现偏好保存/加载
- [ ] 开发提示词模板系统
- [ ] 添加模板选择UI
- [ ] 测试个性化功能

#### Day 9: 优化和增强
- [ ] 实现运势缓存机制
- [ ] 添加反馈系统UI
- [ ] 优化数据加载性能
- [ ] 实现批量操作
- [ ] 添加数据导出功能

### Phase 5: 测试与优化（Day 10）

#### 测试清单
- [ ] 单元测试编写
- [ ] 集成测试执行
- [ ] 性能测试和优化
- [ ] 安全性审查
- [ ] 用户体验测试

#### 优化任务
- [ ] 数据库查询优化
- [ ] 网络请求优化
- [ ] UI响应优化
- [ ] 内存使用优化
- [ ] 电池使用优化

#### 文档编写
- [ ] API文档更新
- [ ] 用户使用指南
- [ ] 部署文档
- [ ] 故障排查指南
- [ ] 版本更新日志

## 五、关键技术细节

### 5.1 智能迁移策略

```swift
// 增量迁移，保持向后兼容
class MigrationManager {
    enum MigrationStrategy {
        case cloudFirst    // 云端优先
        case localFirst    // 本地优先
        case newest       // 最新优先
        case merge        // 智能合并
    }
    
    func migrateUserData(strategy: MigrationStrategy = .newest) async {
        // 检查登录状态
        guard SupabaseManager.shared.isAuthenticated else {
            print("用户未登录，继续使用本地存储")
            return
        }
        
        // 获取云端和本地数据
        let cloudData = await fetchCloudData()
        let localData = loadLocalData()
        
        // 根据策略执行迁移
        switch strategy {
        case .cloudFirst:
            if let cloud = cloudData {
                await applyCloudData(cloud)
            } else {
                await uploadLocalData(localData)
            }
            
        case .localFirst:
            if localData.isEmpty {
                if let cloud = cloudData {
                    await applyCloudData(cloud)
                }
            } else {
                await uploadLocalData(localData)
            }
            
        case .newest:
            let merged = await mergeByTimestamp(
                local: localData,
                cloud: cloudData
            )
            await syncMergedData(merged)
            
        case .merge:
            let merged = await intelligentMerge(
                local: localData,
                cloud: cloudData
            )
            await syncMergedData(merged)
        }
    }
    
    private func intelligentMerge(local: UserData?, cloud: UserData?) async -> UserData {
        // 实现智能合并逻辑
        // 1. 比较时间戳
        // 2. 检测冲突字段
        // 3. 应用合并规则
        // 4. 生成最终数据
        
        var merged = UserData()
        
        // 基本信息：取最新的
        if let localTime = local?.updatedAt,
           let cloudTime = cloud?.updatedAt {
            merged = localTime > cloudTime ? local! : cloud!
        }
        
        // 星盘数据：保留两份（如果不同）
        if local?.chartData != cloud?.chartData {
            merged.alternativeCharts = [local?.chartData, cloud?.chartData]
                .compactMap { $0 }
        }
        
        return merged
    }
}
```

### 5.2 AI上下文智能管理

```swift
struct AIContextBuilder {
    // 构建智能上下文
    static func buildContext(
        for message: String,
        session: ChatSession,
        userId: UUID
    ) async -> AIContext {
        
        var context = AIContext()
        
        // 1. 语义相关性分析
        context.semanticMessages = await findSemanticallySimilar(
            query: message,
            from: session.messages,
            threshold: 0.7
        )
        
        // 2. 时间相关性（最近的对话）
        context.recentMessages = session.messages
            .suffix(5)
            .map { $0 }
        
        // 3. 重要性过滤（标星的消息）
        context.importantMessages = session.messages
            .filter { $0.isStarred }
        
        // 4. 知识库增强
        context.knowledge = await searchRelevantKnowledge(
            query: message,
            categories: detectCategories(message)
        )
        
        // 5. 用户个性化
        if let preferences = await loadUserPreferences(userId) {
            context.applyPreferences(preferences)
        }
        
        // 6. 星盘上下文（如果相关）
        if isAstrologyRelated(message) {
            context.chartContext = await loadChartContext(userId)
        }
        
        return context
    }
    
    // 语义相似度计算
    static func findSemanticallySimilar(
        query: String,
        from messages: [ChatMessage],
        threshold: Double
    ) async -> [ChatMessage] {
        
        // 使用向量化和余弦相似度
        let queryVector = await vectorize(query)
        
        return messages.compactMap { message in
            let messageVector = await vectorize(message.content)
            let similarity = cosineSimilarity(queryVector, messageVector)
            
            return similarity > threshold ? message : nil
        }
    }
    
    // 检测问题类别
    static func detectCategories(_ message: String) -> [String] {
        var categories: [String] = []
        
        let categoryKeywords = [
            "性格": ["性格", "特点", "个性", "特质"],
            "事业": ["事业", "工作", "职业", "升职"],
            "爱情": ["爱情", "感情", "恋爱", "婚姻"],
            "财运": ["财运", "金钱", "财富", "投资"],
            "健康": ["健康", "身体", "疾病", "养生"]
        ]
        
        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { message.contains($0) }) {
                categories.append(category)
            }
        }
        
        return categories.isEmpty ? ["general"] : categories
    }
}
```

### 5.3 配额管理与降级策略

```swift
class QuotaManager {
    enum ModelTier {
        case premium(model: String)    // GPT-4
        case standard(model: String)   // GPT-3.5
        case economic(model: String)   // Claude Haiku
        case fallback                  // 本地回复
    }
    
    // 智能路由决策
    static func selectModel(
        for user: UserProfile,
        message: String,
        currentUsage: UserQuota
    ) async -> ModelTier {
        
        // 1. 检查订阅等级
        guard user.subscriptionTier != "unlimited" else {
            return .premium(model: "gpt-4")
        }
        
        // 2. 检查配额使用情况
        let usagePercent = Double(currentUsage.dailyUsed) / Double(currentUsage.dailyLimit)
        
        // 3. 分析问题复杂度
        let complexity = analyzeComplexity(message)
        
        // 4. 智能决策
        switch (usagePercent, complexity) {
        case (0..<0.5, .high):
            // 配额充足，复杂问题 -> 使用最好的模型
            return .premium(model: "gpt-4")
            
        case (0..<0.7, .medium), (0.5..<0.8, .high):
            // 配额适中 -> 使用标准模型
            return .standard(model: "gpt-3.5-turbo")
            
        case (0.7..<0.9, _), (_, .low):
            // 配额紧张或简单问题 -> 使用经济模型
            return .economic(model: "claude-3-haiku")
            
        case (0.9..., _):
            // 配额即将耗尽 -> 使用本地回复
            return .fallback
            
        default:
            return .standard(model: "gpt-3.5-turbo")
        }
    }
    
    // 分析问题复杂度
    static func analyzeComplexity(_ message: String) -> ComplexityLevel {
        // 基于多个因素判断
        let factors = [
            message.count > 100,                    // 长问题
            message.contains("详细"),               // 需要详细回答
            message.contains("分析"),               // 需要深度分析
            message.contains("为什么"),             // 解释性问题
            message.components(separatedBy: "，").count > 3  // 多个子问题
        ]
        
        let score = factors.filter { $0 }.count
        
        switch score {
        case 0...1: return .low
        case 2...3: return .medium
        default: return .high
        }
    }
}
```

### 5.4 缓存策略实现

```swift
class CacheManager {
    private let supabase = SupabaseManager.shared.client
    
    // 智能缓存查询
    func getCachedResponse(for query: String, context: AIContext?) async -> String? {
        // 1. 生成查询指纹
        let queryHash = generateHash(query: query, context: context)
        
        // 2. 查找缓存
        do {
            let response = try await supabase
                .from("ai_response_cache")
                .select()
                .eq("query_hash", value: queryHash)
                .single()
                .execute()
            
            if let data = response.data {
                let cache = try JSONDecoder().decode(CacheEntry.self, from: data)
                
                // 3. 检查有效期
                if cache.isValid {
                    // 4. 更新命中计数
                    await incrementHitCount(cacheId: cache.id)
                    return cache.responseText
                }
            }
        } catch {
            // 缓存未命中
        }
        
        return nil
    }
    
    // 保存到缓存
    func cacheResponse(
        query: String,
        response: String,
        context: AIContext?,
        ttl: TimeInterval = 3600
    ) async {
        
        // 判断是否应该缓存
        guard shouldCache(query: query) else { return }
        
        let queryHash = generateHash(query: query, context: context)
        let contextHash = context != nil ? generateHash(context: context!) : nil
        
        let cacheEntry = [
            "query_hash": queryHash,
            "query_text": query,
            "context_hash": contextHash as Any,
            "response_text": response,
            "cache_until": ISO8601DateFormatter().string(from: Date().addingTimeInterval(ttl)),
            "is_permanent": isGenericQuestion(query)
        ]
        
        do {
            try await supabase
                .from("ai_response_cache")
                .upsert(cacheEntry)
                .execute()
        } catch {
            print("Failed to cache response: \(error)")
        }
    }
    
    // 判断是否应该缓存
    private func shouldCache(query: String) -> Bool {
        // 不缓存的情况
        let excludePatterns = [
            "我的",     // 个人相关
            "今天",     // 时间相关
            "刚才",     // 上下文相关
            "上一个"    // 引用之前的对话
        ]
        
        return !excludePatterns.contains { query.contains($0) }
    }
    
    // 判断是否是通用问题
    private func isGenericQuestion(_ query: String) -> Bool {
        let genericPatterns = [
            "什么是紫微斗数",
            "十二宫位",
            "主星含义",
            "如何看盘"
        ]
        
        return genericPatterns.contains { query.contains($0) }
    }
    
    // 生成哈希
    private func generateHash(query: String, context: AIContext? = nil) -> String {
        var combined = query
        
        if let ctx = context {
            // 只包含影响回答的关键上下文
            combined += ctx.chartSummary ?? ""
            combined += ctx.userPreferences?.conversationStyle ?? ""
        }
        
        return SHA256.hash(data: combined.data(using: .utf8)!)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
```

## 六、预期成果

### 6.1 用户体验提升

| 指标 | 当前状态 | 目标状态 | 提升幅度 |
|------|---------|---------|---------|
| 多设备同步 | ❌ 不支持 | ✅ 实时同步 | 100% |
| 数据安全性 | 本地存储 | 云端加密存储 | 90% |
| AI响应质量 | 基础回复 | 智能上下文感知 | 60% |
| 个性化程度 | 统一体验 | 完全个性化 | 80% |
| 历史记录 | 单会话 | 完整历史 | 100% |
| 响应速度 | 3-4秒 | 1-2秒(缓存) | 50% |

### 6.2 技术指标

- **系统可用性**: 99.9% (SLA)
- **API响应时间**: P50 < 500ms, P95 < 2000ms
- **数据同步延迟**: < 5秒
- **缓存命中率**: > 40%
- **AI准确率**: > 85%
- **用户满意度**: > 4.5/5

### 6.3 商业价值

#### 订阅模式
```
免费版 (Free)
- 每日50次对话
- 基础功能
- 单设备

专业版 (Pro) - ¥30/月
- 每日500次对话
- 所有功能
- 多设备同步
- 优先支持

无限版 (Unlimited) - ¥98/月
- 无限对话
- GPT-4模型
- API访问
- 定制功能
```

#### 预期收益
- 月活用户(MAU): 10,000
- 付费转化率: 5%
- 平均客单价: ¥45
- 月收入预期: ¥22,500

## 七、风险控制

### 7.1 技术风险

| 风险项 | 影响 | 概率 | 缓解措施 |
|--------|------|------|----------|
| API服务中断 | 高 | 中 | 多层fallback机制 |
| 数据泄露 | 高 | 低 | RLS + 加密传输 |
| 成本超支 | 中 | 中 | 智能配额管理 |
| 性能问题 | 中 | 低 | 缓存 + CDN |
| 版本兼容 | 低 | 中 | 渐进式迁移 |

### 7.2 安全措施

```swift
// 数据加密
class SecurityManager {
    // AES-256加密敏感数据
    static func encryptSensitiveData(_ data: String) -> String {
        // 实现加密逻辑
    }
    
    // API密钥安全存储
    static func securelyStoreAPIKey(_ key: String) {
        // 使用Keychain存储
    }
    
    // 请求签名验证
    static func signRequest(_ request: URLRequest) -> URLRequest {
        // 添加HMAC签名
    }
}
```

### 7.3 隐私合规

- **GDPR合规**: 用户数据可导出/删除
- **数据最小化**: 只收集必要数据
- **透明度**: 清晰的隐私政策
- **用户控制**: 随时可删除账户和数据

### 7.4 降级策略

```swift
// 服务降级管理
class DegradationManager {
    enum ServiceLevel {
        case full       // 完整服务
        case degraded   // 降级服务
        case minimal    // 最小服务
        case offline    // 离线模式
    }
    
    static func getCurrentLevel() -> ServiceLevel {
        // 根据系统状态判断服务级别
        if !NetworkManager.isConnected {
            return .offline
        }
        
        if SupabaseManager.shared.isAuthenticated {
            if AIService.isAvailable {
                return .full
            } else {
                return .degraded
            }
        }
        
        return .minimal
    }
    
    static func handleDegradation(level: ServiceLevel) {
        switch level {
        case .full:
            // 启用所有功能
            break
            
        case .degraded:
            // 使用本地AI回复
            // 禁用部分高级功能
            break
            
        case .minimal:
            // 只提供基础功能
            // 使用本地缓存
            break
            
        case .offline:
            // 完全离线模式
            // 只读本地数据
            break
        }
    }
}
```

## 八、执行检查清单

### 8.1 准备工作

#### 环境准备
- [ ] Supabase账号注册
- [ ] 创建新项目
- [ ] 获取项目URL
- [ ] 获取Anon Key
- [ ] 获取Service Key

#### 开发环境
- [ ] Xcode 15+安装
- [ ] Swift 5.9+
- [ ] iOS 16+ SDK
- [ ] 模拟器/真机准备

#### 依赖管理
- [ ] SPM配置
- [ ] 依赖包安装
- [ ] 版本锁定

### 8.2 开发阶段检查

#### Phase 1 ✓
- [ ] Supabase项目创建
- [ ] 数据库Schema执行
- [ ] RLS策略配置
- [ ] iOS SDK集成
- [ ] 认证功能实现
- [ ] 基础UI完成

#### Phase 2 ✓
- [ ] 数据模型映射
- [ ] 迁移适配器完成
- [ ] 同步逻辑实现
- [ ] 冲突解决测试
- [ ] 离线模式验证

#### Phase 3 ✓
- [ ] 会话管理完成
- [ ] 上下文系统实现
- [ ] 知识库集成
- [ ] 配额控制测试
- [ ] 缓存机制验证

#### Phase 4 ✓
- [ ] 偏好设置UI
- [ ] 模板系统完成
- [ ] 反馈功能实现
- [ ] 运势缓存优化
- [ ] 导出功能测试

#### Phase 5 ✓
- [ ] 单元测试通过
- [ ] 集成测试完成
- [ ] 性能优化达标
- [ ] 安全审查通过
- [ ] 文档编写完成

### 8.3 上线准备

#### 生产环境
- [ ] 生产数据库配置
- [ ] 环境变量设置
- [ ] SSL证书配置
- [ ] CDN配置
- [ ] 备份策略设置

#### 监控告警
- [ ] 错误监控(Sentry)
- [ ] 性能监控(APM)
- [ ] 日志收集(LogRocket)
- [ ] 告警规则配置
- [ ] 值班安排

#### 运营准备
- [ ] 用户引导设计
- [ ] FAQ文档
- [ ] 客服系统
- [ ] 反馈渠道
- [ ] 社区建设

#### 应急预案
- [ ] 回滚方案
- [ ] 数据恢复流程
- [ ] 服务降级策略
- [ ] 应急联系人
- [ ] 故障处理SOP

### 8.4 发布流程

```bash
# 1. 代码冻结
git checkout -b release/v2.0.0

# 2. 版本更新
./scripts/bump-version.sh 2.0.0

# 3. 测试验证
./scripts/run-tests.sh --all

# 4. 构建发布包
xcodebuild archive ...

# 5. 上传TestFlight
./scripts/upload-testflight.sh

# 6. 灰度发布
./scripts/gradual-rollout.sh 10%

# 7. 监控观察
./scripts/monitor-metrics.sh

# 8. 全量发布
./scripts/full-release.sh

# 9. 发布总结
./scripts/post-mortem.sh
```

## 九、总结

### 9.1 项目亮点

- 🏗️ **完整架构**: 从iOS到后端的全栈解决方案
- 🧠 **智能AI**: 上下文感知、个性化、知识增强
- 📊 **数据驱动**: 完整的分析和优化体系
- 🔐 **安全可靠**: 多层保护、隐私合规
- 💰 **商业闭环**: 清晰的盈利模式

### 9.2 技术创新

- 智能上下文管理算法
- 多模型动态路由
- 渐进式数据迁移
- 混合缓存策略
- 自适应降级机制

### 9.3 未来展望

#### 短期目标（3个月）
- 用户数达到10,000
- 付费转化率5%
- 系统稳定性99.9%

#### 中期目标（6个月）
- 引入更多AI模型
- 开发Web版本
- 社区功能上线
- 国际化支持

#### 长期目标（1年）
- AI模型自训练
- 开放API平台
- 生态系统建设
- 企业版服务

---

## 附录A：相关资源

- [Supabase文档](https://supabase.com/docs)
- [Swift Supabase SDK](https://github.com/supabase/supabase-swift)
- [PostgreSQL文档](https://www.postgresql.org/docs/)
- [RLS最佳实践](https://supabase.com/docs/guides/auth/row-level-security)

## 附录B：故障排查

### 常见问题

1. **认证失败**
   - 检查API密钥
   - 验证网络连接
   - 查看RLS策略

2. **同步冲突**
   - 检查时间戳
   - 验证数据格式
   - 查看冲突日志

3. **性能问题**
   - 分析慢查询
   - 检查索引
   - 优化缓存

## 附录C：版本历史

- v2.0.0 - Supabase集成版本
- v1.0.0 - 初始版本

---

**文档版本**: 2.0.0  
**最后更新**: 2024-01-09  
**作者**: Purple Team  
**状态**: 已审核 ✅