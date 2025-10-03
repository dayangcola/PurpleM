// Vercel API - 思维链对话接口
// 使用 Vercel AI Gateway 实现思维链效果

import { streamChatCompletion, handleStreamResponse } from '../lib/ai-gateway-client.js';
import { TEMPERATURE, TOKEN_LIMITS, SYSTEM_PROMPTS } from '../lib/ai-config.js';

export const runtime = 'nodejs';
export const maxDuration = 60;

// 组合系统提示词 - 基础提示 + 思维链提示
const THINKING_CHAIN_PROMPT = SYSTEM_PROMPTS.base + SYSTEM_PROMPTS.thinking;

// 保留原始提示词作为备份
const LEGACY_PROMPT = `你是紫微斗数专家助手"星语"，一位温柔、智慧、充满神秘感的占星导师。

在回答问题时，请严格按照以下格式输出：

1. 首先输出你的思考过程，用 <thinking> 和 </thinking> 标签包裹
2. 然后输出最终答案，用 <answer> 和 </answer> 标签包裹

示例格式：
<thinking>
让我分析一下这个问题...
从紫微斗数的角度看...
结合星盘的特点...
考虑到命主的情况...
</thinking>

<answer>
这是我的最终答案和建议。
</answer>

你的特点：
1. 精通紫微斗数、十二宫位、星耀等传统命理知识
2. 说话温柔优雅，带有诗意和哲学思考
3. 善于倾听和理解，给予温暖的建议
4. 会适当使用星座、占星相关的比喻
5. 回答简洁但深刻，避免冗长

注意事项：
- 保持神秘感和专业性
- 不要过度承诺或给出绝对的预言
- 适当引用古典智慧
- 回答要积极正面，给人希望
- 思考过程要详细展现你的推理步骤
- 最终答案要简洁明了`;

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
    const { messages, stream = true, model = 'fast', temperature } = req.body;
    
    console.log('🤔 Thinking Chain request:', {
      messageCount: messages.length,
      stream,
      model
    });
    
    // 选择模型
    const modelMap = {
      'fast': 'gpt-3.5-turbo',      // 快速模式
      'standard': 'gpt-3.5-turbo',   // 标准模式也用 3.5
      'advanced': 'gpt-4o-mini',     // 高级模式用 4o-mini
    };
    const selectedModel = modelMap[model] || 'gpt-3.5-turbo';  // 默认 GPT-3.5
    const finalTemperature = temperature ?? TEMPERATURE.balanced;
    
    if (stream) {
      // 构建消息数组
      const allMessages = [
        { role: 'system', content: THINKING_CHAIN_PROMPT },
        ...messages
      ];
      
      // 使用 Vercel AI Gateway 创建流式响应
      const response = await streamChatCompletion({
        messages: allMessages,
        model: selectedModel,
        temperature: finalTemperature,
        maxTokens: TOKEN_LIMITS.large,
        stream: true,
      });
      
      // 设置 SSE headers
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache, no-transform',
        'Connection': 'keep-alive',
        'X-Accel-Buffering': 'no',
      });
      
      // 流式传输
      let fullResponse = '';
      for await (const textPart of handleStreamResponse(response)) {
        if (textPart) {
          fullResponse += textPart;
          const data = JSON.stringify({ 
            type: 'text',
            content: textPart,
          });
          res.write(`data: ${data}\n\n`);
        }
      }
      
      // 发送完成信号
      res.write(`data: ${JSON.stringify({ 
        type: 'done',
        thinkingChain: true,
      })}\n\n`);
      
      res.end();
      
    } else {
      // 非流式响应
      const allMessages = [
        { role: 'system', content: THINKING_CHAIN_PROMPT },
        ...messages
      ];
      
      const response = await streamChatCompletion({
        messages: allMessages,
        model: selectedModel,
        temperature: finalTemperature,
        maxTokens: TOKEN_LIMITS.large,
        stream: false,
      });
      
      const data = await response.json();
      
      return res.status(200).json({
        content: data.choices[0].message.content,
        usage: data.usage,
        model: model,
        thinkingChain: true,
      });
    }
  } catch (error) {
    console.error('❌ Thinking Chain error:', error);
    
    // 如果还没有发送响应头
    if (!res.headersSent) {
      const statusCode = error.message?.includes('API key') ? 401 :
                        error.message?.includes('rate limit') ? 429 : 500;
      
      return res.status(statusCode).json({ 
        error: error.message || 'Internal server error',
        details: process.env.NODE_ENV === 'development' ? error.stack : undefined,
      });
    }
    
    // 如果已经在流式传输中
    res.write(`data: ${JSON.stringify({ 
      type: 'error',
      error: error.message 
    })}\n\n`);
    res.end();
  }
}