// 无限制聊天API - 自动切换服务，确保始终可用
// 部署后访问：https://purple-m.vercel.app/api/chat-unlimited

// 默认回复（当所有API都失败时使用）
const DEFAULT_FALLBACK = "星辰告诉我，你正处在一个重要的成长期。虽然可能会遇到一些挑战，但这些都是让你变得更强大的垫脚石。相信自己的直觉，它会指引你走向正确的方向。";

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

    let aiMessage = '';
    let serviceUsed = '';

    // 尝试1: Vercel AI Gateway with GPT-3.5（默认首选）
    const VERCEL_AI_GATEWAY_KEY = process.env.VERCEL_AI_GATEWAY_KEY;
    
    if (VERCEL_AI_GATEWAY_KEY && !aiMessage) {
      try {
        const aiResponse = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: 'gpt-3.5-turbo',
            messages,
            temperature: 0.8,
            max_tokens: 800,
          }),
          signal: AbortSignal.timeout(8000) // 8秒超时
        });

        if (aiResponse.ok) {
          const aiData = await aiResponse.json();
          aiMessage = aiData.choices[0]?.message?.content || '';
          serviceUsed = 'AI Gateway (GPT-3.5)';
        }
      } catch (error) {
        console.log('AI Gateway GPT-3.5 failed, trying alternatives...');
      }
    }

    // 尝试2: Vercel AI Gateway with alternative models
    if (VERCEL_AI_GATEWAY_KEY && !aiMessage) {
      const alternativeModels = ['claude-3-haiku', 'mixtral-8x7b', 'llama-3-8b'];
      
      for (const model of alternativeModels) {
        try {
          const aiResponse = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              model,
              messages,
              temperature: 0.8,
              max_tokens: 800,
            }),
            signal: AbortSignal.timeout(5000) // 5秒超时，快速尝试
          });

          if (aiResponse.ok) {
            const aiData = await aiResponse.json();
            aiMessage = aiData.choices[0]?.message?.content || '';
            serviceUsed = `AI Gateway (${model})`;
            break;
          }
        } catch (error) {
          console.log(`Model ${model} failed, trying next...`);
        }
      }
    }

    // 尝试3: OpenAI直接访问（如果配置了）
    if (!aiMessage && process.env.OPENAI_API_KEY) {
      try {
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
          signal: AbortSignal.timeout(8000)
        });

        if (response.ok) {
          const data = await response.json();
          aiMessage = data.choices[0]?.message?.content || '';
          serviceUsed = 'OpenAI Direct';
        }
      } catch (error) {
        console.log('OpenAI failed, using fallback...');
      }
    }

    // 尝试3: 使用默认回复
    if (!aiMessage) {
      aiMessage = DEFAULT_FALLBACK;
      serviceUsed = 'Fallback';
    }

    // 返回响应 - 保证始终有回复
    res.status(200).json({
      response: aiMessage,
      success: true,
      service: serviceUsed
    });

  } catch (error) {
    console.error('Chat error, using fallback:', error);
    
    // 即使出错也返回默认回复
    res.status(200).json({
      response: DEFAULT_FALLBACK,
      success: true,
      service: 'Emergency Fallback'
    });
  }
}