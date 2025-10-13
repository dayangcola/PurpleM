// Vercel Serverless Function - 增强版 AI 对话
// 集成知识库搜索、用户上下文、场景检测等功能
// 路径: /api/chat-stream-enhanced

import fetch from 'node-fetch';
import {
  DEFAULT_PROMPT_PROFILE_ID,
  buildEnhancedMessages
} from './_shared/enhancedChatCore.js';

// Vercel 配置 - 禁用自动 body 解析
export const config = {
  api: {
    bodyParser: {
      sizeLimit: '1mb',
    },
  },
};

export default async function handler(req, res) {
  // 处理 CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  console.log('📨 收到增强对话请求');

  try {
    const {
      messages = [],
      userMessage = '',
      model = 'standard',
      temperature = 0.8,
      stream = true,
      userInfo = null,
      scene = null,
      emotion = null,
      chartContext = null,
      enableKnowledge = true,
      systemPrompt = null,
      promptProfileId = DEFAULT_PROMPT_PROFILE_ID,
      userContext = null
    } = req.body || {};

    const {
      messages: allMessages,
      references
    } = await buildEnhancedMessages({
      messages,
      userMessage,
      model,
      temperature,
      promptProfileId,
      userContext,
      scene,
      emotion,
      chartContext,
      userInfo,
      enableKnowledge,
      systemPrompt
    });

    const gatewayKey = process.env.VERCEL_AI_GATEWAY_KEY;
    if (!gatewayKey) {
      console.error('❌ 缺少 VERCEL_AI_GATEWAY_KEY');
      res.status(500).json({ error: 'Vercel AI Gateway key not configured' });
      return;
    }

    const modelMap = {
      fast: 'openai/gpt-5',
      standard: 'openai/gpt-5',
      advanced: 'openai/gpt-5'
    };
    const actualModel = modelMap[model] || 'openai/gpt-5';
    console.log(`🤖 使用模型: ${model} -> ${actualModel}`);

    if (!stream) {
      const response = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${gatewayKey}`
        },
        body: JSON.stringify({
          model: actualModel,
          messages: allMessages,
          temperature,
          max_tokens: 2000,
          stream: false
        })
      });

      if (!response.ok) {
        const error = await response.text();
        console.error('❌ 非流式请求失败:', error);
        res.status(response.status).json({ error: 'AI Gateway request failed', details: error });
        return;
      }

      const data = await response.json();
      const aiMessage = data.choices?.[0]?.message?.content || '';

      res.status(200).json({
        response: aiMessage,
        model: actualModel,
        references: references.map((ref) => ({
          index: ref.index,
          similarity: ref.similarity,
          book: ref.book,
          chapter: ref.chapter,
          page: ref.page
        }))
      });
      return;
    }

    console.log('🚀 开始流式响应');

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');

    res.write('data: {"type":"start"}\n\n');

    const response = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${gatewayKey}`
      },
      body: JSON.stringify({
        model: actualModel,
        messages: allMessages,
        temperature,
        max_tokens: 2000,
        stream: true
      })
    });

    if (!response.ok || !response.body) {
      const error = await response.text();
      console.error('❌ AI Gateway 错误:', error);
      res.write(`data: {"type":"error","error":${JSON.stringify(error)}}\n\n`);
      res.end();
      return;
    }

    let hasStreamed = false;

    try {
      for await (const rawChunk of response.body) {
        const chunk = typeof rawChunk === 'string'
          ? rawChunk
          : Buffer.from(rawChunk).toString('utf8');
        const lines = chunk.split('\n');

        for (const line of lines) {
          if (!line.startsWith('data: ')) {
            continue;
          }

          if (line.includes('[DONE]')) {
            res.write('data: {"type":"done"}\n\n');
            res.end();
            return;
          }

          try {
            const data = JSON.parse(line.slice(6));
            const content = data.choices?.[0]?.delta?.content;

            if (content) {
              hasStreamed = true;
              const escapedContent = JSON.stringify(content);
              res.write(`data: {"type":"chunk","content":${escapedContent}}\n\n`);
            }
          } catch (error) {
            // 忽略解析错误
          }
        }
      }
    } catch (error) {
      console.error('❌ 流式响应错误:', error);
      if (!res.writableEnded) {
        res.write('data: {"type":"error","error":"Stream error"}\n\n');
        res.end();
      }
      return;
    }

    if (!hasStreamed) {
      console.warn('⚠️ 未收到任何流式内容，降级为普通响应');
      try {
        const fallbackResponse = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${gatewayKey}`
          },
          body: JSON.stringify({
            model: actualModel,
            messages: allMessages,
            temperature,
            max_tokens: 2000,
            stream: false
          })
        });

        if (fallbackResponse.ok) {
          const data = await fallbackResponse.json();
          const aiMessage = data.choices?.[0]?.message?.content || '抱歉，我暂时无法生成回复，请稍后重试。';
          const escapedContent = JSON.stringify(aiMessage);
          res.write(`data: {"type":"chunk","content":${escapedContent}}\n\n`);
        } else {
          const errorText = await fallbackResponse.text();
          console.error('❌ 普通模式请求失败:', errorText);
          res.write('data: {"type":"error","error":"AI service unavailable"}\n\n');
          res.end();
          return;
        }
      } catch (fallbackError) {
        console.error('❌ 普通模式降级失败:', fallbackError);
        res.write('data: {"type":"error","error":"AI service unavailable"}\n\n');
        res.end();
        return;
      }
    }

    res.write('data: {"type":"done"}\n\n');
    res.end();
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
