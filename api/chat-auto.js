// 智能聊天API - 自动选择最佳的AI服务
// 部署后访问：https://purple-m.vercel.app/api/chat-auto

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

    // 尝试不同的AI服务
    let aiMessage = '';
    let serviceUsed = '';
    
    // 策略1: 尝试Vercel AI Gateway (新URL)
    const AI_GATEWAY_KEY = process.env.AI_GATEWAY_API_KEY || process.env.VERCEL_AI_GATEWAY_KEY;
    if (AI_GATEWAY_KEY) {
      try {
        console.log('Trying Vercel AI Gateway with key:', AI_GATEWAY_KEY.substring(0, 10) + '...');
        const response = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${AI_GATEWAY_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: 'openai/gpt-3.5-turbo',
            messages,
            temperature: 0.8,
            max_tokens: 1000,
          }),
        });
        
        if (response.ok) {
          const data = await response.json();
          aiMessage = data.choices[0]?.message?.content || '';
          serviceUsed = 'Vercel AI Gateway';
        } else {
          console.log('AI Gateway failed:', response.status, await response.text());
        }
      } catch (e) {
        console.log('AI Gateway error:', e.message);
      }
    }
    
    // 策略2: 如果AI Gateway失败，尝试直接使用OpenAI
    if (!aiMessage && process.env.OPENAI_API_KEY) {
      try {
        console.log('Trying OpenAI API directly');
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
            max_tokens: 1000,
          }),
        });
        
        if (response.ok) {
          const data = await response.json();
          aiMessage = data.choices[0]?.message?.content || '';
          serviceUsed = 'OpenAI Direct';
        }
      } catch (e) {
        console.log('OpenAI error:', e.message);
      }
    }
    
    // 策略3: 如果你的vck_密钥可能是其他Vercel服务，尝试老的URL
    if (!aiMessage && AI_GATEWAY_KEY) {
      try {
        console.log('Trying alternative Vercel endpoint');
        const response = await fetch('https://gateway.vercel.app/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${AI_GATEWAY_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model: 'gpt-3.5-turbo',
            messages,
            temperature: 0.8,
            max_tokens: 1000,
          }),
        });
        
        if (response.ok) {
          const data = await response.json();
          aiMessage = data.choices[0]?.message?.content || '';
          serviceUsed = 'Vercel Alternative';
        }
      } catch (e) {
        console.log('Alternative endpoint error:', e.message);
      }
    }

    if (!aiMessage) {
      throw new Error('所有AI服务都失败了。请检查环境变量配置。');
    }

    // 返回响应
    res.status(200).json({
      response: aiMessage,
      success: true,
      service: serviceUsed // 告诉你使用了哪个服务
    });

  } catch (error) {
    console.error('Chat API error:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: error.message,
      hint: '请确保在Vercel环境变量中设置了 AI_GATEWAY_API_KEY 或 OPENAI_API_KEY'
    });
  }
}