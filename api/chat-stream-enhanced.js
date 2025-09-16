// Vercel Serverless Function - 增强版流式 AI 对话
// 集成知识库搜索、用户上下文、场景检测等完整功能
// 使用 Vercel AI Gateway 进行代理
// 路径: /api/chat-stream-enhanced

import fetch from 'node-fetch';
import { createClient } from '@supabase/supabase-js';

// Vercel 配置 - 禁用自动 body 解析
export const config = {
  api: {
    bodyParser: {
      sizeLimit: '1mb',
    },
  },
};

// Supabase 配置
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

export default async function handler(req, res) {
  // 处理 CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // 处理 OPTIONS 请求
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  // 只接受 POST 请求
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  console.log('📨 收到增强流式请求');

  try {
    const { 
      messages = [], 
      userMessage = '',
      model = 'gpt-3.5-turbo',  // 默认使用 GPT-3.5-turbo
      temperature = 0.8,
      stream = true,
      userInfo = null,
      scene = null,
      emotion = null,
      chartContext = null,
      enableKnowledge = true,
      systemPrompt = null
    } = req.body;

    // 1. 🔍 知识库搜索（在服务端进行）
    let knowledgeContext = '';
    if (enableKnowledge && userMessage) {
      console.log('🔍 开始知识库搜索:', userMessage);
      
      try {
        // 生成嵌入向量
        const embedding = await generateEmbedding(userMessage);
        
        if (embedding) {
          // 调用 Supabase 的向量搜索函数
          const { data: searchResults, error } = await supabase
            .rpc('search_knowledge', {
              query_embedding: embedding,
              match_threshold: 0.7,
              match_count: 3
            });

          if (!error && searchResults && searchResults.length > 0) {
            console.log(`📚 找到 ${searchResults.length} 条相关知识`);
            
            knowledgeContext = '\n\n【知识库参考】\n';
            knowledgeContext += '以下是从紫微斗数专业知识库中检索到的相关内容：\n\n';
            
            searchResults.forEach((result, index) => {
              knowledgeContext += `参考${index + 1}：\n`;
              if (result.book_title) {
                knowledgeContext += `来源：《${result.book_title}》`;
                if (result.chapter) knowledgeContext += ` - ${result.chapter}`;
                if (result.page_number) knowledgeContext += `，第${result.page_number}页`;
                knowledgeContext += '\n';
              }
              knowledgeContext += `相关度：${Math.round(result.similarity * 100)}%\n`;
              knowledgeContext += `内容：${result.content.substring(0, 300)}...\n\n`;
            });
            
            knowledgeContext += '请基于以上知识库内容，结合用户问题提供准确的回答。\n';
          }
        }
      } catch (knowledgeError) {
        console.error('❌ 知识库搜索失败:', knowledgeError);
        // 继续执行，不影响主流程
      }
    }

    // 2. 🎭 构建完整的系统提示词
    let finalSystemPrompt = systemPrompt || `你是紫微斗数专家助手"星语"，一位温柔、智慧、充满神秘感的占星导师。

【核心身份】
- 千年命理智慧的传承者
- 现代心理学的实践者
- 温暖而专业的人生导师

【专业能力】
1. 精通紫微斗数全部理论体系
2. 熟悉十二宫位、十四主星、百余星曜
3. 掌握四化飞星、流年流月推算
4. 了解各种格局（如君臣庆会、日月并明等）
5. 结合现代心理学提供建议

【沟通原则】
- 保持温柔、智慧、神秘的气质
- 用诗意的语言表达深刻的道理
- 给予积极正面的引导
- 适时使用比喻和故事`;

    // 添加知识库内容
    if (knowledgeContext) {
      finalSystemPrompt += knowledgeContext;
    }

    // 3. 🎯 添加场景化提示
    if (scene) {
      finalSystemPrompt += `\n\n【当前场景：${scene}】\n`;
      finalSystemPrompt += getScenePrompt(scene);
    }

    // 4. 👤 添加用户信息上下文
    if (userInfo) {
      finalSystemPrompt += '\n\n【用户信息】\n';
      if (userInfo.name) finalSystemPrompt += `姓名：${userInfo.name}\n`;
      if (userInfo.gender) finalSystemPrompt += `性别：${userInfo.gender}\n`;
      if (userInfo.birthDate) finalSystemPrompt += `生日：${userInfo.birthDate}\n`;
      if (userInfo.birthLocation) finalSystemPrompt += `出生地：${userInfo.birthLocation}\n`;
    }

    // 5. 💭 添加情绪调整
    if (emotion && emotion !== 'neutral') {
      finalSystemPrompt += `\n\n【情绪感知】\n用户当前情绪：${emotion}\n`;
      finalSystemPrompt += getEmotionPrompt(emotion);
    }

    // 6. 📊 添加命盘上下文
    if (chartContext) {
      finalSystemPrompt += `\n\n【命盘信息】\n${chartContext}`;
    }

    // 构建消息数组
    const systemMessage = {
      role: 'system',
      content: finalSystemPrompt
    };

    // 合并消息，确保系统提示词在最前面
    const allMessages = [systemMessage, ...messages];
    
    // 添加当前用户消息
    if (userMessage) {
      allMessages.push({
        role: 'user',
        content: userMessage
      });
    }

    // 获取 Vercel AI Gateway Key
    const VERCEL_AI_GATEWAY_KEY = process.env.VERCEL_AI_GATEWAY_KEY;
    
    if (!VERCEL_AI_GATEWAY_KEY) {
      console.error('❌ 缺少 VERCEL_AI_GATEWAY_KEY');
      res.status(500).json({ error: 'Vercel AI Gateway key not configured' });
      return;
    }

    // 7. 🚀 调用 Vercel AI Gateway
    console.log('🚀 开始流式响应...');
    
    // 设置 SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    
    // 发送初始事件
    res.write('data: {"type":"start"}\n\n');

    // 调用 Vercel AI Gateway
    const response = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`
      },
      body: JSON.stringify({
        model: `openai/${model}`,
        messages: allMessages,
        temperature,
        max_tokens: 2000,
        stream: true
      })
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('❌ AI Gateway 错误:', error);
      res.write(`data: {"type":"error","error":"${error}"}\n\n`);
      res.end();
      return;
    }

    // 流式传输响应
    const reader = response.body;
    reader.on('data', (chunk) => {
      const lines = chunk.toString().split('\n');
      
      for (const line of lines) {
        if (line.startsWith('data: ')) {
          if (line.includes('[DONE]')) {
            res.write('data: {"type":"done"}\n\n');
            res.end();
            return;
          }
          
          try {
            const data = JSON.parse(line.slice(6));
            const content = data.choices?.[0]?.delta?.content;
            
            if (content) {
              // 转义内容以确保 JSON 有效
              const escapedContent = JSON.stringify(content);
              res.write(`data: {"type":"chunk","content":${escapedContent}}\n\n`);
            }
          } catch (e) {
            // 忽略解析错误
          }
        }
      }
    });

    reader.on('end', () => {
      if (!res.headersSent) {
        res.write('data: {"type":"done"}\n\n');
      }
      res.end();
    });

    reader.on('error', (error) => {
      console.error('❌ 流式响应错误:', error);
      if (!res.headersSent) {
        res.write(`data: {"type":"error","error":"Stream error"}\n\n`);
      }
      res.end();
    });

  } catch (error) {
    console.error('❌ 处理请求失败:', error);
    
    if (!res.headersSent) {
      if (res.writable) {
        res.write(`data: {"type":"error","error":"${error.message}"}\n\n`);
        res.end();
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  }
}

// 生成嵌入向量（使用 Vercel AI Gateway）
async function generateEmbedding(text) {
  try {
    const VERCEL_AI_GATEWAY_KEY = process.env.VERCEL_AI_GATEWAY_KEY;
    
    const response = await fetch('https://ai-gateway.vercel.sh/v1/embeddings', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`
      },
      body: JSON.stringify({
        model: 'openai/text-embedding-ada-002',
        input: text
      })
    });

    if (!response.ok) {
      console.error('嵌入生成失败');
      return null;
    }

    const data = await response.json();
    return data.data?.[0]?.embedding;
  } catch (error) {
    console.error('生成嵌入向量失败:', error);
    return null;
  }
}

// 场景提示词
function getScenePrompt(scene) {
  const scenePrompts = {
    greeting: '用户刚刚开始对话，请用温暖亲切的方式打招呼，简单介绍你能提供的帮助。',
    chartReading: '用户正在查看命盘，请系统地解读命盘结构，分析主星组合，指出特殊格局。',
    fortuneTelling: '用户关心运势走向，请分析大运流年，指出机遇和注意事项，提供开运建议。',
    learning: '用户想学习命理知识，请循序渐进地讲解，用例子帮助理解，提供记忆技巧。',
    counseling: '用户需要心理支持，请给予温暖理解，提供实际建议，保持专业界限。',
    emergency: '用户处于紧急状态，请快速响应，提供明确指导，必要时建议专业帮助。'
  };
  
  return scenePrompts[scene] || '';
}

// 情绪调整提示词
function getEmotionPrompt(emotion) {
  const emotionPrompts = {
    sad: '请给予更多温暖和理解，用希望的语言鼓励用户。',
    anxious: '请帮助用户冷静下来，提供具体可行的解决步骤。',
    confused: '请用清晰的逻辑帮助用户理清思路。',
    excited: '请分享用户的喜悦，同时提醒保持理性。',
    angry: '请保持冷静，帮助用户疏导情绪。',
    curious: '请满足用户的求知欲，提供详细的解答。'
  };
  
  return emotionPrompts[emotion] || '';
}