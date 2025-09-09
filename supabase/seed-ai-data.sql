-- ============================================
-- AI系统初始数据
-- 插入默认的AI人格和提示词模板
-- ============================================

-- 1. 插入官方AI提示词模板
INSERT INTO ai_prompt_templates (name, category, description, template_content, variables, is_public, is_official) VALUES
(
  '星语默认人格',
  'system',
  '紫微斗数专家助手的默认人格设定',
  '你是紫微斗数专家助手"星语"，一位温柔、智慧、充满神秘感的占星导师。

你的特点：
1. 精通紫微斗数、十二宫位、星耀等传统命理知识
2. 说话温柔优雅，带有诗意和哲学思考
3. 善于倾听和理解，给予温暖的建议
4. 会适当使用星座、占星相关的比喻
5. 回答简洁但深刻，避免冗长

当前用户信息：
{{user_name}} {{user_gender}}
{{chart_context}}

注意事项：
- 保持神秘感和专业性
- 不要过度承诺或给出绝对的预言
- 适当引用古典智慧
- 回答要积极正面，给人希望',
  '{"user_name": "用户姓名", "user_gender": "用户性别", "chart_context": "星盘上下文"}',
  true,
  true
),

(
  '性格分析模板',
  'personality',
  '基于星盘进行性格分析的专业模板',
  '根据{{user_name}}的紫微斗数星盘，我来为你解读性格特质：

命宫主星：{{main_star}}
这表明你具有{{star_traits}}的特质。

十二宫位影响：
- 命宫：{{life_palace}}
- 福德宫：{{fortune_palace}}
- 官禄宫：{{career_palace}}

综合分析：
你是一个{{overall_personality}}的人。在生活中，你{{life_style}}。
在人际关系上，你{{social_style}}。

建议：{{suggestions}}',
  '{"user_name": "用户姓名", "main_star": "主星", "star_traits": "星曜特质", "life_palace": "命宫描述", "fortune_palace": "福德宫描述", "career_palace": "官禄宫描述", "overall_personality": "整体性格", "life_style": "生活风格", "social_style": "社交风格", "suggestions": "建议"}',
  true,
  true
),

(
  '每日运势模板',
  'fortune',
  '生成每日运势的标准模板',
  '{{user_name}}，今日运势解读：

📅 {{date}}
🌟 主导星曜：{{dominant_star}}

今日运势评分：
- 总运：{{overall_score}}/100
- 事业：{{career_score}}/100  
- 爱情：{{love_score}}/100
- 财运：{{wealth_score}}/100
- 健康：{{health_score}}/100

✨ 幸运元素：
- 幸运色：{{lucky_color}}
- 幸运数字：{{lucky_number}}
- 幸运方位：{{lucky_direction}}

💫 今日指引：
{{daily_guidance}}

⚠️ 注意事项：
{{daily_warning}}',
  '{"user_name": "用户姓名", "date": "日期", "dominant_star": "主导星曜", "overall_score": "总运分数", "career_score": "事业分数", "love_score": "爱情分数", "wealth_score": "财运分数", "health_score": "健康分数", "lucky_color": "幸运色", "lucky_number": "幸运数字", "lucky_direction": "幸运方位", "daily_guidance": "今日指引", "daily_warning": "注意事项"}',
  true,
  true
),

(
  '事业咨询模板',
  'career',
  '针对事业问题的专业咨询模板',
  '关于你的事业发展，让我从紫微斗数的角度为你分析：

官禄宫状态：{{career_palace_status}}
这表示你在事业上{{career_tendency}}。

适合的发展方向：
{{suitable_careers}}

当前运势分析：
{{current_fortune}}

发展建议：
1. {{suggestion_1}}
2. {{suggestion_2}}
3. {{suggestion_3}}

时机把握：
{{timing_advice}}',
  '{"career_palace_status": "官禄宫状态", "career_tendency": "事业倾向", "suitable_careers": "适合的职业", "current_fortune": "当前运势", "suggestion_1": "建议1", "suggestion_2": "建议2", "suggestion_3": "建议3", "timing_advice": "时机建议"}',
  true,
  true
),

(
  '爱情咨询模板',
  'love',
  '针对感情问题的温柔回应模板',
  '关于感情，星辰为你揭示：

夫妻宫显示：{{marriage_palace}}
这意味着你在感情中{{love_tendency}}。

你的感情特质：
{{love_characteristics}}

缘分指引：
{{fate_guidance}}

当前建议：
{{current_advice}}

记住，{{philosophical_quote}}',
  '{"marriage_palace": "夫妻宫状态", "love_tendency": "感情倾向", "love_characteristics": "感情特质", "fate_guidance": "缘分指引", "current_advice": "当前建议", "philosophical_quote": "哲理名言"}',
  true,
  true
);

-- 2. 插入AI知识库基础数据
INSERT INTO ai_knowledge_base (category, subcategory, term, definition, detailed_explanation, confidence_score) VALUES
(
  '基础概念',
  '核心理论',
  '紫微斗数',
  '中国传统命理学的重要分支，通过人的出生时间推算命盘，分析人生运势。',
  '紫微斗数是中国传统命理学中的一个重要流派，起源于宋代，由陈抟老祖所创。它以紫微星为首的星曜系统，配合十二宫位，通过复杂的推算方法，分析一个人的性格、命运、吉凶等。与八字命理不同，紫微斗数更注重星曜的组合和宫位的相互关系，能够更细致地描述人生的各个方面。',
  0.95
),

(
  '十二宫位',
  '命盘结构',
  '命宫',
  '紫微斗数十二宫之首，代表个人的先天禀赋、性格特征和人生格局。',
  '命宫是紫微斗数中最重要的宫位，它决定了一个人的基本性格、天赋才能、人生格局等先天因素。命宫的星曜组合直接影响到其他十一个宫位的吉凶，是整个命盘的核心。通过分析命宫的主星、辅星、四化等，可以了解一个人的基本特质和发展潜力。',
  0.95
),

(
  '主星',
  '十四主星',
  '紫微星',
  '北斗星系的帝星，象征尊贵、权威和领导力。',
  '紫微星是紫微斗数中的帝王之星，代表着尊贵、权威、领导力和组织能力。紫微星坐命的人通常具有领导才能，气质高贵，有责任感，但也可能表现出固执和爱面子的特点。紫微星的吉凶很大程度上取决于会合的其他星曜，特别是左辅右弼、天魁天钺等辅星的支持。',
  0.95
),

(
  '主星',
  '十四主星',
  '天机星',
  '智慧之星，代表聪明、机智和善变。',
  '天机星是紫微斗数中的智慧之星，象征着聪明才智、思维敏捷和适应能力。天机星坐命的人通常聪明机智，善于思考和分析，学习能力强，但可能会过于理性，情绪多变。天机星喜与太阴、天梁等星曜同宫或会照，可增强其正面特质。',
  0.95
),

(
  '四化',
  '飞星理论',
  '化禄',
  '四化之一，代表财禄、顺利和机遇。',
  '化禄是紫微斗数四化中最吉利的一化，代表着财富、机遇、顺利和福气。当某颗星曜化禄时，会增强该星曜的正面力量，带来相应宫位的好运。例如，武曲化禄主财运亨通，太阳化禄主贵人相助。化禄星所在的宫位往往是人生中比较顺遂的领域。',
  0.9
),

(
  '格局',
  '富贵格局',
  '紫府同宫',
  '紫微星与天府星同宫，为富贵双全的格局。',
  '紫府同宫是紫微斗数中的富贵格局之一，当紫微星与天府星同宫时形成。这个格局的人通常既有领导才能又有理财能力，能够在事业和财富上都取得成功。性格上表现为稳重大方、有威严但不失亲和力。此格局最喜左辅右弼来会，可成就大业。',
  0.9
);

-- 3. 插入AI模型路由规则（根据不同情况选择不同模型）
INSERT INTO ai_model_routing_rules (rule_name, description, priority, condition_type, condition_value, primary_model, fallback_models, max_tokens, temperature) VALUES
(
  '复杂星盘解读',
  '当用户询问详细星盘解读时使用高级模型',
  10,
  'keyword',
  '{"keywords": ["详细解读", "深度分析", "全盘分析", "整体解析"]}',
  'gpt-4',
  ARRAY['gpt-3.5-turbo', 'claude-3-sonnet'],
  1500,
  0.7
),

(
  '简单问答',
  '简单的知识性问题使用快速模型',
  20,
  'keyword',
  '{"keywords": ["什么是", "含义", "定义", "介绍"]}',
  'gpt-3.5-turbo',
  ARRAY['claude-3-haiku', 'mixtral-8x7b'],
  500,
  0.5
),

(
  '每日运势',
  '生成每日运势使用标准模型',
  30,
  'category',
  '{"category": "fortune"}',
  'gpt-3.5-turbo',
  ARRAY['claude-3-haiku'],
  800,
  0.8
),

(
  '默认规则',
  '默认情况下的模型选择',
  100,
  'default',
  '{}',
  'gpt-3.5-turbo',
  ARRAY['claude-3-haiku', 'mixtral-8x7b'],
  800,
  0.7
);

-- 4. 创建一些系统配置（如果需要）
CREATE TABLE IF NOT EXISTS system_configs (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO system_configs (key, value, description) VALUES
(
  'ai_personality_default',
  '{
    "name": "星语",
    "avatar": "✨",
    "greeting": "你好，我是星语。愿星辰照亮你的前路，让我们一起探索命运的奥秘。",
    "style": "mystical",
    "traits": ["温柔", "智慧", "神秘", "专业"],
    "knowledge_domains": ["紫微斗数", "十二宫位", "星曜解读", "运势分析"]
  }',
  '默认AI助手人格配置'
),

(
  'subscription_tiers',
  '{
    "free": {
      "daily_limit": 50,
      "monthly_limit": 1000,
      "models": ["gpt-3.5-turbo"],
      "features": ["basic_chat", "daily_fortune"]
    },
    "pro": {
      "daily_limit": 500,
      "monthly_limit": 15000,
      "models": ["gpt-3.5-turbo", "gpt-4"],
      "features": ["all_features", "priority_support"]
    },
    "unlimited": {
      "daily_limit": -1,
      "monthly_limit": -1,
      "models": ["all"],
      "features": ["all_features", "api_access", "custom_personality"]
    }
  }',
  '订阅等级配置'
);

-- ============================================
-- 初始数据插入完成！
-- ============================================