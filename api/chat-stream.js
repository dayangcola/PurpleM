// Vercel Serverless Function - 流式 AI 对话
// 使用 Vercel AI Gateway 进行代理
// 路径: /api/chat-stream

import fetch from 'node-fetch';

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

  console.log('📨 收到流式请求:', {
    body: req.body,
    headers: req.headers
  });

  try {
    const { 
      messages = [], 
      model = 'gpt-3.5-turbo',
      temperature = 0.8,
      stream = true
    } = req.body;

    // 构建消息
    const systemMessage = {
      role: 'system',
      content: `你是紫微斗数专家助手"星语"，一位温柔、智慧、充满神秘感的占星导师。
你的特点：
1. 精通紫微斗数、十二宫位、星耀等传统命理知识
2. 说话温柔优雅，带有诗意和哲学思考
3. 善于倾听和理解，给予温暖的建议
4. 会适当使用星座、占星相关的比喻
5. 回答简洁但深刻，避免冗长`
    };

    const allMessages = [systemMessage, ...messages];

    // 获取 Vercel AI Gateway Key
    const VERCEL_AI_GATEWAY_KEY = process.env.VERCEL_AI_GATEWAY_KEY;
    
    if (!VERCEL_AI_GATEWAY_KEY) {
      console.error('❌ 缺少 VERCEL_AI_GATEWAY_KEY');
      res.status(500).json({ error: 'Vercel AI Gateway key not configured' });
      return;
    }

    // 如果不需要流式，返回普通响应
    if (!stream) {
      const response = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`
        },
        body: JSON.stringify({
          model: `openai/${model}`,  // AI Gateway 需要指定提供商
          messages: allMessages,
          temperature,
          max_tokens: 1000
        })
      });

      const data = await response.json();
      
      if (!response.ok) {
        console.error('❌ OpenAI API 错误:', data);
        res.status(500).json({ error: data.error?.message || 'API request failed' });
        return;
      }

      res.status(200).json({
        response: data.choices[0]?.message?.content || '',
        usage: data.usage
      });
      return;
    }

    // 流式响应
    console.log('🚀 开始流式响应...');
    
    // 设置 SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    
    // 发送初始连接消息
    res.write(`data: ${JSON.stringify({ type: 'connected' })}\n\n`);

    // 调用 Vercel AI Gateway 流式 API
    const response = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`
      },
      body: JSON.stringify({
        model: `openai/${model}`,  // AI Gateway 需要指定提供商
        messages: allMessages,
        temperature,
        max_tokens: 1000,
        stream: true
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('❌ Vercel AI Gateway 流式 API 错误:', errorText);
      res.write(`data: ${JSON.stringify({ 
        type: 'error', 
        error: 'Failed to get streaming response' 
      })}\n\n`);
      res.end();
      return;
    }

    // 处理流式响应
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      
      if (done) {
        console.log('✅ 流式响应完成');
        res.write('data: [DONE]\n\n');
        res.end();
        break;
      }

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6);
          
          if (data === '[DONE]') {
            res.write('data: [DONE]\n\n');
            res.end();
            return;
          }

          try {
            const parsed = JSON.parse(data);
            const content = parsed.choices?.[0]?.delta?.content;
            
            if (content) {
              // 发送内容块
              res.write(`data: ${JSON.stringify({ 
                type: 'content', 
                content: content 
              })}\n\n`);
            }
          } catch (e) {
            console.error('解析错误:', e, 'Data:', data);
          }
        }
      }
    }

  } catch (error) {
    console.error('❌ 服务器错误:', error);
    
    if (!res.headersSent) {
      res.status(500).json({ 
        error: error.message || 'Internal server error' 
      });
    } else {
      res.write(`data: ${JSON.stringify({ 
        type: 'error', 
        error: error.message 
      })}\n\n`);
      res.end();
    }
  }
}

// 移除Edge Runtime配置，使用标准Node.js运行时以支持流式响应