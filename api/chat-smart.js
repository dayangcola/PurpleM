// 智能聊天API - 带重试和限流处理
// 部署后访问：https://purple-m.vercel.app/api/chat-smart

// 延迟函数
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// 带重试的fetch
async function fetchWithRetry(url, options, maxRetries = 2) {
  let lastError;
  
  for (let i = 0; i <= maxRetries; i++) {
    try {
      const response = await fetch(url, options);
      
      // 如果是429（限流），等待后重试
      if (response.status === 429) {
        const retryAfter = parseInt(response.headers.get('retry-after') || '5');
        console.log(`Rate limited, waiting ${retryAfter} seconds...`);
        
        if (i < maxRetries) {
          await delay(retryAfter * 1000);
          continue;
        }
      }
      
      return response;
    } catch (error) {
      lastError = error;
      
      if (i < maxRetries) {
        console.log(`Retry ${i + 1}/${maxRetries} after error:`, error.message);
        await delay(2000 * (i + 1)); // 指数退避
        continue;
      }
    }
  }
  
  throw lastError || new Error('Max retries exceeded');
}

export default async function handler(req, res) {
  // CORS设置
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // 处理OPTIONS请求
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  // 只接受POST请求
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { message, conversationHistory = [], userInfo = {} } = req.body;

    if (!message) {
      res.status(400).json({ error: 'Message is required' });
      return;
    }

    // AI人格设置
    const systemPrompt = `你是紫微斗数专家助手"星语"，一位温柔、智慧、充满神秘感的占星导师。

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
- 回答要积极正面，给人希望`;

    // 用户上下文
    let userContext = '';
    if (userInfo.name) {
      userContext = `\n用户信息：姓名${userInfo.name}，性别${userInfo.gender || '未知'}`;
      if (userInfo.hasChart) {
        userContext += '\n用户已生成紫微斗数星盘。';
      }
    }

    // 构建消息
    const messages = [
      { role: 'system', content: systemPrompt + userContext },
      ...conversationHistory.slice(-10), // 保留最近10条
      { role: 'user', content: message }
    ];

    // 尝试多个策略
    let aiMessage = '';
    let serviceUsed = '';
    const errors = [];

    // 策略1: Vercel AI Gateway with retry
    const VERCEL_AI_GATEWAY_KEY = process.env.VERCEL_AI_GATEWAY_KEY;
    
    if (VERCEL_AI_GATEWAY_KEY) {
      try {
        console.log('Trying Vercel AI Gateway with smart retry...');
        
        const aiResponse = await fetchWithRetry(
          'https://ai-gateway.vercel.sh/v1/chat/completions',
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              model: 'gpt-3.5-turbo',
              messages,
              temperature: 0.8,
              max_tokens: 800, // 减少token以降低限流风险
            }),
          },
          2 // 最多重试2次
        );

        if (aiResponse.ok) {
          const aiData = await aiResponse.json();
          aiMessage = aiData.choices[0]?.message?.content || '';
          serviceUsed = 'Vercel AI Gateway';
        } else {
          const errorText = await aiResponse.text();
          errors.push(`AI Gateway: ${aiResponse.status} - ${errorText}`);
        }
      } catch (error) {
        console.error('AI Gateway error:', error);
        errors.push(`AI Gateway: ${error.message}`);
      }
    }

    // 策略2: 如果Gateway失败，尝试使用OpenAI直接访问（如果配置了）
    if (!aiMessage && process.env.OPENAI_API_KEY) {
      try {
        console.log('Falling back to OpenAI direct...');
        
        const response = await fetch('https://api.openai.com/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: 'gpt-3.5-turbo',
            messages,
            temperature: 0.8,
            max_tokens: 800,
          }),
        });

        if (response.ok) {
          const data = await response.json();
          aiMessage = data.choices[0]?.message?.content || '';
          serviceUsed = 'OpenAI Direct';
        } else {
          errors.push(`OpenAI: ${response.status}`);
        }
      } catch (error) {
        errors.push(`OpenAI: ${error.message}`);
      }
    }

    // 如果还是没有响应，返回友好的错误消息
    if (!aiMessage) {
      console.error('All services failed:', errors);
      
      // 根据错误类型返回不同的提示
      if (errors.some(e => e.includes('429'))) {
        aiMessage = '星语正在冥想中，请稍后再来找我聊天吧。✨\n\n（提示：服务繁忙，请等待几秒后重试）';
      } else {
        aiMessage = '星辰似乎有些暗淡，让我稍后再为你解读命运。\n\n（提示：服务暂时不可用，请稍后重试）';
      }
      serviceUsed = 'Fallback';
    }

    // 返回响应
    res.status(200).json({
      response: aiMessage,
      success: true,
      service: serviceUsed,
      // 如果是限流，告诉客户端等待时间
      retryAfter: errors.some(e => e.includes('429')) ? 5 : undefined
    });

  } catch (error) {
    console.error('Chat API error:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: error.message 
    });
  }
}