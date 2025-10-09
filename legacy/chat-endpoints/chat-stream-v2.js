// Vercel API - 统一的流式对话接口 v2
// 使用 Vercel AI Gateway 实现标准化的流式响应

import { streamChatCompletion, generateEmbedding, handleStreamResponse } from '../lib/ai-gateway-client.js';
import { TEMPERATURE, TOKEN_LIMITS, SYSTEM_PROMPTS, SCENE_CONFIGS } from '../lib/ai-config.js';
import { createClient } from '@supabase/supabase-js';

// 使用 Node.js 运行时以支持所有功能
export const runtime = 'nodejs';
export const maxDuration = 60;

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

export default async function handler(req, res) {
  // CORS 处理
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const {
      messages = [],
      userMessage,
      userInfo,
      scene,
      emotion,
      chartContext,
      enableKnowledge = true,
      enableThinking = true,
      model = 'standard',
      temperature,
    } = req.body;

    console.log('📝 Stream v2 request:', {
      hasUserMessage: !!userMessage,
      hasUserInfo: !!userInfo,
      scene,
      emotion,
      enableKnowledge,
      enableThinking,
      model,
      messageCount: messages.length
    });

    // 1. 构建系统提示词
    let systemPrompt = buildSystemPrompt({
      basePrompt: SYSTEM_PROMPTS.base,
      scene,
      emotion,
      userInfo,
      chartContext,
      enableThinking,
    });

    // 2. 知识库增强（如果启用）
    if (enableKnowledge && userMessage) {
      try {
        const knowledgeContext = await enhanceWithKnowledge(userMessage);
        if (knowledgeContext) {
          systemPrompt += '\n\n' + knowledgeContext;
          console.log('✅ Knowledge enhanced with', knowledgeContext.length, 'chars');
        }
      } catch (error) {
        console.error('❌ Knowledge enhancement failed:', error);
        // 继续执行，不中断流程
      }
    }

    // 3. 选择模型
    const modelMap = {
      'fast': 'openai/gpt-5',        // 快速模式使用GPT-5
      'standard': 'openai/gpt-5',    // 标准模式使用GPT-5
      'advanced': 'openai/gpt-5',    // 高级模式使用GPT-5
    };
    const selectedModel = modelMap[model] || 'openai/gpt-5';  // 默认 GPT-5
    
    // 4. 获取场景配置
    const sceneConfig = scene ? SCENE_CONFIGS[scene] : {};
    const finalTemperature = temperature ?? sceneConfig.temperature ?? TEMPERATURE.balanced;
    const maxTokens = sceneConfig.maxTokens || TOKEN_LIMITS.large;

    // 5. 构建完整的消息数组
    const allMessages = [
      { role: 'system', content: systemPrompt },
      ...messages
    ];

    // 6. 使用 Vercel AI Gateway 创建流式响应
    const response = await streamChatCompletion({
      messages: allMessages,
      model: selectedModel,
      temperature: finalTemperature,
      maxTokens: maxTokens,
      stream: true,
    });

    // 7. 设置 SSE headers
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no', // 禁用 Nginx 缓冲
    });

    // 8. 流式传输响应
    let fullResponse = '';
    let chunkCount = 0;
    
    for await (const textPart of handleStreamResponse(response)) {
      if (textPart) {
        fullResponse += textPart;
        chunkCount++;
        
        // 发送数据块
        const data = JSON.stringify({ 
          type: 'text',
          content: textPart,
          chunkIndex: chunkCount,
        });
        res.write(`data: ${data}\n\n`);
        
        // 定期刷新以确保客户端接收
        if (chunkCount % 5 === 0) {
          res.flush?.();
        }
      }
    }
    
    // 9. 发送完成信号
    res.write(`data: ${JSON.stringify({ 
      type: 'done',
      totalChunks: chunkCount,
      totalLength: fullResponse.length,
    })}\n\n`);
    
    res.end();
    
    console.log('✅ Stream completed:', {
      chunks: chunkCount,
      length: fullResponse.length,
      tokens: usage?.totalTokens,
    });

  } catch (error) {
    console.error('❌ Stream v2 error:', error);
    
    // 如果还没有发送响应头，返回 JSON 错误
    if (!res.headersSent) {
      const statusCode = error.message?.includes('API key') ? 401 :
                        error.message?.includes('rate limit') ? 429 : 500;
      
      return res.status(statusCode).json({ 
        error: error.message || 'Internal server error',
        type: 'stream_error',
        details: process.env.NODE_ENV === 'development' ? error.stack : undefined,
      });
    }
    
    // 如果已经在流式传输中，发送错误事件
    res.write(`data: ${JSON.stringify({ 
      type: 'error',
      error: error.message 
    })}\n\n`);
    res.end();
  }
}

// 知识库增强函数
async function enhanceWithKnowledge(query) {
  try {
    // 1. 生成嵌入向量（使用 Vercel AI Gateway）
    const embedding = await generateEmbedding(query);

    // 2. 向量搜索
    const { data: results, error } = await supabase.rpc('search_knowledge', {
      query_embedding: embedding,
      match_threshold: 0.7,
      match_count: 3,
    });

    if (error) {
      console.error('Supabase search error:', error);
      return null;
    }

    if (!results || results.length === 0) {
      console.log('No knowledge results found');
      return null;
    }

    // 3. 构建知识上下文
    let context = '【知识库参考】\n';
    results.forEach((item, idx) => {
      context += `\n参考${idx + 1}：`;
      if (item.citation) {
        context += `${item.citation}\n`;
      }
      if (item.content) {
        // 限制每条内容长度
        const content = item.content.substring(0, 300);
        context += `内容：${content}${item.content.length > 300 ? '...' : ''}\n`;
      }
      context += `相关度：${(item.similarity * 100).toFixed(1)}%\n`;
    });

    return context;
  } catch (error) {
    console.error('Knowledge enhancement failed:', error);
    return null;
  }
}

// 构建系统提示词
function buildSystemPrompt({ 
  basePrompt, 
  scene, 
  emotion, 
  userInfo, 
  chartContext,
  enableThinking 
}) {
  let prompt = basePrompt;

  // 添加思维链模式
  if (enableThinking) {
    prompt += SYSTEM_PROMPTS.thinking;
  }

  // 添加场景上下文
  if (scene && SCENE_CONFIGS[scene]) {
    prompt += `\n\n【当前场景】${scene}\n${SCENE_CONFIGS[scene].prompt}`;
  }

  // 添加情绪识别
  if (emotion) {
    const emotionGuide = {
      'anxious': '用户似乎有些焦虑，请给予安抚和支持',
      'curious': '用户充满好奇心，可以深入讲解',
      'confused': '用户可能有困惑，请耐心解释',
      'excited': '用户很兴奋，可以分享他们的喜悦',
      'worried': '用户有担忧，请给予理解和建议',
    };
    
    if (emotionGuide[emotion]) {
      prompt += `\n\n【情绪感知】${emotionGuide[emotion]}`;
    }
  }

  // 添加用户信息
  if (userInfo) {
    prompt += `\n\n【用户信息】`;
    if (userInfo.name) prompt += `\n姓名：${userInfo.name}`;
    if (userInfo.gender) prompt += `\n性别：${userInfo.gender}`;
    if (userInfo.birthDate) prompt += `\n生日：${userInfo.birthDate}`;
    if (userInfo.birthTime) prompt += `\n出生时间：${userInfo.birthTime}`;
    if (userInfo.birthPlace) prompt += `\n出生地：${userInfo.birthPlace}`;
  }

  // 添加命盘上下文
  if (chartContext) {
    prompt += `\n\n【命盘信息】\n${chartContext}`;
  }

  return prompt;
}

// 导出工具函数供其他模块使用
export { enhanceWithKnowledge, buildSystemPrompt };