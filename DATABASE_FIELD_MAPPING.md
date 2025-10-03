# 数据库字段映射参考文档

## 📅 更新日期：2025-09-13

`★ Insight ─────────────────────────────────────`
数据库表的字段命名不一致是导致SQL错误的主要原因。star_charts表使用generated_at而不是created_at，这种细微差异需要特别注意。本文档作为权威参考，确保所有代码使用正确的字段名。
`─────────────────────────────────────────────────`

## 🗂️ 数据库表字段清单

### 1. profiles 表
```sql
- id                UUID (主键，关联auth.users)
- email             TEXT (唯一)
- username          TEXT (唯一)
- full_name         TEXT
- avatar_url        TEXT
- phone             TEXT
- subscription_tier TEXT (默认'free')
- is_active         BOOLEAN (默认TRUE)
- created_at        TIMESTAMPTZ ✅
- updated_at        TIMESTAMPTZ ✅
```

### 2. star_charts 表 ⚠️ 特殊时间字段
```sql
- id                    UUID (主键)
- user_id               UUID (外键->profiles)
- chart_data            JSONB
- chart_image_url       TEXT
- interpretation_summary TEXT
- version               TEXT (默认'1.0')
- is_primary            BOOLEAN (默认FALSE)
- generated_at          TIMESTAMPTZ ⚠️ (不是created_at!)
- updated_at            TIMESTAMPTZ ✅
```

### 3. user_birth_info 表
```sql
- id              UUID (主键)
- user_id         UUID (外键->profiles，唯一)
- name            TEXT
- gender          TEXT
- birth_date      DATE
- birth_time      TIME
- birth_location  TEXT
- is_lunar_date   BOOLEAN (默认FALSE)
- birth_province  TEXT
- birth_city      TEXT
- created_at      TIMESTAMPTZ ✅
- updated_at      TIMESTAMPTZ ✅
```

### 4. chat_sessions 表
```sql
- id                UUID (主键)
- user_id           UUID (外键->profiles)
- title             TEXT
- context_summary   TEXT
- star_chart_id     UUID (外键->star_charts)
- session_type      TEXT (默认'general')
- tokens_used       INTEGER (默认0)
- model_preferences JSONB
- quality_score     FLOAT
- is_archived       BOOLEAN (默认FALSE)
- last_message_at   TIMESTAMPTZ
- created_at        TIMESTAMPTZ ✅
- updated_at        TIMESTAMPTZ ✅
```

### 5. chat_messages 表
```sql
- id              UUID (主键)
- session_id      UUID (外键->chat_sessions)
- user_id         UUID (外键->profiles)
- role            TEXT
- content         TEXT
- content_type    TEXT (默认'text')
- tokens_count    INTEGER
- model_used      TEXT
- service_used    TEXT
- response_time_ms INTEGER
- cost_credits    FLOAT
- is_starred      BOOLEAN (默认FALSE)
- is_hidden       BOOLEAN (默认FALSE)
- feedback        TEXT
- feedback_text   TEXT
- metadata        JSONB
- created_at      TIMESTAMPTZ ✅
```

### 6. user_ai_quotas 表
```sql
- id                UUID (主键)
- user_id           UUID (外键->profiles，唯一)
- quota_limit       INTEGER (默认100000)
- quota_used        INTEGER (默认0)
- reset_date        DATE
- subscription_plan TEXT (默认'free')
- created_at        TIMESTAMPTZ ✅
- updated_at        TIMESTAMPTZ ✅
```

### 7. user_ai_preferences 表
```sql
- id             UUID (主键)
- user_id        UUID (外键->profiles，唯一)
- ai_model       TEXT (默认'gpt-3.5-turbo')
- temperature    FLOAT (默认0.7)
- max_tokens     INTEGER (默认2000)
- system_prompt  TEXT
- response_style TEXT (默认'balanced')
- created_at     TIMESTAMPTZ ✅
- updated_at     TIMESTAMPTZ ✅
```

### 8. daily_fortunes 表
```sql
- id            UUID (主键)
- user_id       UUID (外键->profiles)
- fortune_date  DATE
- fortune_data  JSONB
- is_generated  BOOLEAN (默认FALSE)
- created_at    TIMESTAMPTZ ✅
- updated_at    TIMESTAMPTZ ✅
```

## ⚠️ 常见错误和注意事项

### 1. star_charts 表的特殊性
```sql
-- ❌ 错误
SELECT * FROM star_charts WHERE created_at > NOW() - INTERVAL '24 hours';

-- ✅ 正确
SELECT * FROM star_charts WHERE generated_at > NOW() - INTERVAL '24 hours';
```

### 2. Swift 代码中的字段映射
```swift
// ✅ 正确的 CodingKeys
struct CloudChartData: Codable {
    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"  // 不是 created_at!
        case updatedAt = "updated_at"
        // ...
    }
}
```

### 3. API 请求中的字段名
```javascript
// ❌ 错误
{
    "userId": "123",
    "chartData": {...},
    "createdAt": "2025-09-13"  // star_charts表没有这个字段
}

// ✅ 正确
{
    "user_id": "123",
    "chart_data": {...},
    "generated_at": "2025-09-13"  // 使用正确的字段名
}
```

## 🔧 字段映射规则

### Swift (camelCase) → Database (snake_case)
- `userId` → `user_id`
- `chartData` → `chart_data`
- `generatedAt` → `generated_at`
- `isPrimary` → `is_primary`
- `birthDate` → `birth_date`
- `sessionId` → `session_id`

### 特殊映射（需要注意）
- star_charts表: `generatedDate` → `generated_at` (不是created_at)
- 所有其他表: `createdDate` → `created_at`

## 📝 SQL 查询模板

### 检查最近的星盘数据
```sql
-- 使用 generated_at，不是 created_at
SELECT 
    sc.id,
    sc.user_id,
    sc.generated_at,  -- 正确的字段名
    p.username
FROM star_charts sc
JOIN profiles p ON sc.user_id = p.id
WHERE sc.generated_at > NOW() - INTERVAL '24 hours'
ORDER BY sc.generated_at DESC;
```

### 检查用户的所有数据
```sql
SELECT 
    'profiles' as table_name,
    COUNT(*) as count,
    MAX(created_at) as latest
FROM profiles
WHERE id = '用户ID'

UNION ALL

SELECT 
    'star_charts',
    COUNT(*),
    MAX(generated_at)  -- 注意：使用generated_at
FROM star_charts
WHERE user_id = '用户ID'

UNION ALL

SELECT 
    'chat_sessions',
    COUNT(*),
    MAX(created_at)
FROM chat_sessions
WHERE user_id = '用户ID';
```

## 🚀 使用建议

1. **开发时**：始终参考此文档确认字段名
2. **调试时**：如果遇到"column does not exist"错误，首先检查是否是star_charts表的generated_at问题
3. **代码审查**：确保新代码使用正确的字段映射
4. **API设计**：使用SupabaseAPIHelper自动处理字段映射

## 📋 检查清单

在编写涉及数据库的代码时，请检查：

- [ ] star_charts表使用`generated_at`而不是`created_at`
- [ ] Swift模型的CodingKeys正确映射了数据库字段
- [ ] API请求使用snake_case字段名
- [ ] SQL查询使用实际存在的字段名
- [ ] 字段映射辅助类包含了所有需要的映射

## 相关文件
- `/PurpleM/Services/SupabaseAPIHelper.swift` - 字段映射实现
- `/PurpleM/Services/SupabaseManager+Charts.swift` - 星盘数据模型
- `/supabase/schema.sql` - 数据库schema定义
- `/supabase/fix-all-rls-policies.sql` - RLS策略和测试查询