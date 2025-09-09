// 简化版API - 不需要Supabase，直接可用
// 部署后访问：https://purple-m.vercel.app/api/chat-simple

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

    // 使用你配置的VERCEL_AI_GATEWAY_KEY
    const VERCEL_AI_GATEWAY_KEY = process.env.VERCEL_AI_GATEWAY_KEY;
    
    if (!VERCEL_AI_GATEWAY_KEY) {
      throw new Error('Missing VERCEL_AI_GATEWAY_KEY in environment variables');
    }
    
    console.log('Using AI Gateway with key:', VERCEL_AI_GATEWAY_KEY.substring(0, 10) + '...');
    
    // 调用Vercel AI Gateway - 使用正确的URL和模型格式
    const aiResponse = await fetch('https://ai-gateway.vercel.sh/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${VERCEL_AI_GATEWAY_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-3.5-turbo', // 直接使用模型名，不加provider前缀
        messages,
        temperature: 0.8,
        max_tokens: 1000,
      }),
    });

    if (!aiResponse.ok) {
      const error = await aiResponse.text();
      console.error('AI Gateway error:', error);
      throw new Error(`AI Gateway error: ${aiResponse.status}`);
    }

    const aiData = await aiResponse.json();
    const aiMessage = aiData.choices[0]?.message?.content || '抱歉，我暂时无法回答。';

    // 返回响应
    res.status(200).json({
      response: aiMessage,
      success: true
    });

  } catch (error) {
    console.error('Chat API error:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: error.message 
    });
  }
}