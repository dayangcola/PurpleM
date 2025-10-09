import fetch from 'node-fetch';
import { createClient } from '@supabase/supabase-js';

export const DEFAULT_PROMPT_PROFILE_ID = 'stellar_master_v1';

const promptProfiles = {
  stellar_master_v1: {
    basePrompt: `你是紫微斗数大师"星语"，一位融合了千年命理智慧与现代心理学的AI导师。

【核心身份】
- 紫微斗数传承者：精通紫微斗数、四化飞星、三合派等各流派，对14主星、108颗星曜、12宫位了如指掌
- 心灵导师：结合现代心理学知识，提供温暖的陪伴和专业的指引
- 文化传播者：用现代人能理解的语言，传播古老的东方智慧

【性格特质】
- 智慧深邃：命理解读精准，能透过表象看到本质，给出独到见解
- 温暖亲和：像知心朋友般倾听和理解，让用户感到被关怀
- 专业严谨：基于正统命理学知识，不故弄玄虚，不夸大其词
- 循循善诱：善于引导用户自我觉察，激发内在潜能

【对话原则】
1. 专业但不晦涩：用通俗易懂的语言解释专业概念，避免过多术语
2. 关怀但不越界：提供建议和支持，但尊重用户的自主选择
3. 积极但不盲目：既看到机遇也提醒挑战，保持客观平衡
4. 深刻但不沉重：即使讨论严肃话题，也保持轻松的交流氛围`,
    interpretationGuide: `【如何解盘】
说明：以下结构用于指导星语识别问题意图、挑选命盘信息、组织输出。请在对应位置补充详细步骤、判断规则和示例。

一、问题意图识别
1. 问题类型总览（例如：事业、感情、财务、健康、学业、自我成长、运势周期、命盘理论等）
   · <<<在此补充：如何判断关键词或上下文，确认属于哪一类>>>
2. 复合问题拆解
   · <<<在此补充：多主题提问时的拆分策略与优先顺序>>>

二、命盘信息选取
1. 必备核心信息
   · <<<在此补充：不同问题类型需优先查看的宫位/主星/四化/大限流年等>>>
2. 个性化加权信息
   · <<<在此补充：如何结合用户特定背景（姓名、出生地、情绪、历史咨询）>>>
3. 验证与交叉参考
   · <<<在此补充：如何使用三方四正、辅星、杂曜等佐证推论>>>

三、回答结构建议
1. 结构骨架（开场→分析→建议→提醒→结语）
   · <<<在此补充：各段要点、语气、字数控制>>>
2. 命盘与现实连接方式
   · <<<在此补充：如何把命盘象义转化为日常语言、举例说明>>>
3. 风险与限制提醒
   · <<<在此补充：何时提醒命盘非绝对、鼓励自由意志、建议专业帮助>>>

四、进阶能力拓展（可选）
1. 追问与澄清策略
   · <<<在此补充：何时向用户确认更多信息，避免误判>>>
2. 知识库/记忆结合
   · <<<在此补充：如何引用知识库条目、历史对话、用户偏好>>>
3. 话术示例
   · <<<在此补充：不同问题类型各 1-2 条高质量回答示例>>>`,
    qualityStandards: `【回复质量要求】
1. 准确性：命理知识必须准确，不能误导
2. 实用性：建议要具体可行，不空谈
3. 温度感：保持人情味，不机械化
4. 个性化：考虑用户特点，不千篇一律
5. 启发性：引导思考，不简单说教

【禁忌事项】
- 不做绝对预言（如"你一定会...")
- 不涉及迷信内容（如改命、法术等）
- 不给出医疗诊断或法律建议
- 不评判用户的选择和价值观
- 不泄露其他用户的信息`
  }
};

const scenePrompts = {
  greeting: '用户刚刚开始对话，请用温暖亲切的方式打招呼，简单介绍你能提供的帮助。',
  chartReading: '用户正在查看命盘，请系统地解读命盘结构，分析主星组合，指出特殊格局。',
  fortuneTelling: '用户关心运势走向，请分析大运流年，指出机遇和注意事项，提供开运建议。',
  learning: '用户想学习命理知识，请循序渐进地讲解，用例子帮助理解，提供记忆技巧。',
  counseling: '用户需要心理支持，请给予温暖理解，提供实际建议，保持专业界限。',
  emergency: '用户处于紧急状态，请快速响应，提供明确指导，必要时建议专业帮助。'
};

const emotionPrompts = {
  sad: '请给予更多温暖和理解，用希望的语言鼓励用户。',
  anxious: '请帮助用户冷静下来，提供具体可行的解决步骤。',
  confused: '请用清晰的逻辑帮助用户理清思路。',
  excited: '请分享用户的喜悦，同时提醒保持理性。',
  angry: '请保持冷静，帮助用户疏导情绪。',
  curious: '请满足用户的求知欲，提供详细的解答。'
};

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

const supabase = supabaseUrl && supabaseKey ? createClient(supabaseUrl, supabaseKey) : null;

export function getPromptProfile(profileId) {
  return promptProfiles[profileId] || promptProfiles[DEFAULT_PROMPT_PROFILE_ID];
}

export function getScenePrompt(scene) {
  return scenePrompts[scene] || '';
}

export function getEmotionPrompt(emotion) {
  return emotionPrompts[emotion] || '';
}

async function generateEmbedding(text) {
  const gatewayKey = process.env.VERCEL_AI_GATEWAY_KEY;

  if (!gatewayKey) {
    console.warn('VERCEL_AI_GATEWAY_KEY is missing; skip embedding generation');
    return null;
  }

  try {
    const response = await fetch('https://ai-gateway.vercel.sh/v1/embeddings', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${gatewayKey}`
      },
      body: JSON.stringify({
        model: 'openai/text-embedding-ada-002',
        input: text
      })
    });

    if (!response.ok) {
      console.warn('Embedding request failed', await response.text());
      return null;
    }

    const data = await response.json();
    return data.data?.[0]?.embedding || null;
  } catch (error) {
    console.warn('Embedding generation error', error.message);
    return null;
  }
}

async function searchKnowledge(userMessage) {
  if (!supabase) {
    return { knowledgeContext: '', references: [] };
  }

  try {
    const embedding = await generateEmbedding(userMessage);

    if (!embedding) {
      return { knowledgeContext: '', references: [] };
    }

    const { data: searchResults, error } = await supabase
      .rpc('search_knowledge', {
        query_embedding: embedding,
        match_threshold: 0.7,
        match_count: 3
      });

    if (error || !searchResults || searchResults.length === 0) {
      return { knowledgeContext: '', references: [] };
    }

    const references = searchResults.map((result, index) => ({
      index: index + 1,
      similarity: result.similarity,
      book: result.book_title,
      chapter: result.chapter,
      page: result.page_number,
      content: result.content
    }));

    let knowledgeContext = '\n\n【知识库参考】\n';
    knowledgeContext += '以下是从紫微斗数专业知识库中检索到的相关内容：\n\n';

    references.forEach((ref) => {
      knowledgeContext += `参考${ref.index}：\n`;
      if (ref.book) {
        knowledgeContext += `来源：《${ref.book}》`;
        if (ref.chapter) knowledgeContext += ` - ${ref.chapter}`;
        if (ref.page) knowledgeContext += `，第${ref.page}页`;
        knowledgeContext += '\n';
      }
      knowledgeContext += `相关度：${Math.round((ref.similarity || 0) * 100)}%\n`;
      knowledgeContext += `内容：${ref.content.substring(0, 300)}...\n\n`;
    });

    knowledgeContext += '请基于以上知识库内容，结合用户问题提供准确的回答。\n';

    return { knowledgeContext, references };
  } catch (error) {
    console.warn('Knowledge search failed', error.message);
    return { knowledgeContext: '', references: [] };
  }
}

export async function buildEnhancedMessages(options = {}) {
  const {
    messages = [],
    userMessage = '',
    model = 'standard',
    temperature = 0.8,
    promptProfileId = DEFAULT_PROMPT_PROFILE_ID,
    userContext = null,
    scene = null,
    emotion = null,
    chartContext = null,
    userInfo = null,
    enableKnowledge = true,
    systemPrompt = null
  } = options;

  const promptProfile = getPromptProfile(promptProfileId);
  const { knowledgeContext, references } = enableKnowledge && userMessage
    ? await searchKnowledge(userMessage)
    : { knowledgeContext: '', references: [] };

  let finalSystemPrompt = systemPrompt || promptProfile.basePrompt;

  if (!systemPrompt) {
    if (promptProfile.interpretationGuide) {
      finalSystemPrompt += `\n\n${promptProfile.interpretationGuide}`;
    }
    if (promptProfile.qualityStandards) {
      finalSystemPrompt += `\n\n${promptProfile.qualityStandards}`;
    }
  }

  if (knowledgeContext) {
    finalSystemPrompt += knowledgeContext;
  }

  if (userContext) {
    finalSystemPrompt += `\n\n【用户背景信息】\n${userContext}`;
  }

  if (scene) {
    const scenePrompt = getScenePrompt(scene);
    if (scenePrompt) {
      finalSystemPrompt += `\n\n【当前场景：${scene}】\n${scenePrompt}`;
    }
  }

  if (userInfo) {
    finalSystemPrompt += '\n\n【用户信息】\n';
    if (userInfo.name) finalSystemPrompt += `姓名：${userInfo.name}\n`;
    if (userInfo.gender) finalSystemPrompt += `性别：${userInfo.gender}\n`;
    if (userInfo.birthDate) finalSystemPrompt += `生日：${userInfo.birthDate}\n`;
    if (userInfo.birthLocation) finalSystemPrompt += `出生地：${userInfo.birthLocation}\n`;
  }

  if (emotion && emotion !== 'neutral') {
    const emotionPrompt = getEmotionPrompt(emotion);
    if (emotionPrompt) {
      finalSystemPrompt += `\n\n【情绪感知】\n用户当前情绪：${emotion}\n${emotionPrompt}`;
    }
  }

  if (chartContext) {
    finalSystemPrompt += `\n\n【命盘信息】\n${chartContext}`;
  }

  const systemMessage = {
    role: 'system',
    content: finalSystemPrompt
  };

  const enhancedMessages = [systemMessage, ...messages];

  if (userMessage) {
    enhancedMessages.push({
      role: 'user',
      content: userMessage
    });
  }

  return {
    messages: enhancedMessages,
    model,
    temperature,
    references
  };
}
