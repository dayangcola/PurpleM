// 无限制聊天API - 自动切换服务，确保始终可用
// 部署后访问：https://purple-m.vercel.app/api/chat-unlimited

// 固定的AI回复模板（当所有API都失败时使用）
const fallbackResponses = [
  "从你的星盘来看，近期会有新的机遇出现。保持开放的心态，善于观察身边的变化，你会发现意想不到的收获。记住，命运的轮盘始终在转动，而你是自己命运的主宰。",
  "星辰告诉我，你正处在一个重要的成长期。虽然可能会遇到一些挑战，但这些都是让你变得更强大的垫脚石。相信自己的直觉，它会指引你走向正确的方向。",
  "紫微星正照耀着你的命宫，这预示着你将迎来一段充满智慧和洞察力的时期。利用这段时间深入思考，制定长远的计划，你会发现事半功倍。",
  "你的福德宫星光璀璨，这意味着内心的平和与满足感将会增强。不要被外界的喧嚣所干扰，专注于自己真正想要的东西，幸福就在不远处。",
  "命运之轮正在为你转动，带来新的可能性。保持积极的态度，勇敢地迈出第一步，即使道路看起来模糊不清，星光也会为你照亮前行的路。"
];

// 根据消息内容生成相关的回复
function generateSmartFallback(message) {
  const keywords = {
    '爱情|感情|恋爱|结婚|伴侣': '从你的夫妻宫来看，感情运势正在上升期。保持真诚和开放的心态，缘分自会到来。已有伴侣的话，多些理解和包容，关系会更加和谐。',
    '事业|工作|职业|升职|跳槽': '你的官禄宫星耀明亮，事业上将有不错的发展。坚持努力，把握机会，成功就在眼前。记得保持谦逊，贵人会在关键时刻助你一臂之力。',
    '财运|金钱|投资|理财|收入': '财帛宫显示，你的财运正在稳步提升。理性投资，量入为出，会有意外之财。但切记不可贪心，稳健理财才是长久之道。',
    '健康|身体|疾病|养生': '从你的疾厄宫来看，要多注意身体健康。规律作息，适度运动，保持良好的生活习惯。预防胜于治疗，照顾好自己才能走得更远。',
    '学业|考试|学习|升学': '文昌星照耀，学业运势极佳。专注学习，勤奋努力，必有所成。考试期间保持平常心，发挥出你的真实水平。'
  };

  for (const [pattern, response] of Object.entries(keywords)) {
    if (new RegExp(pattern).test(message)) {
      return response;
    }
  }

  // 如果没有匹配的关键词，返回随机通用回复
  return fallbackResponses[Math.floor(Math.random() * fallbackResponses.length)];
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

    let aiMessage = '';
    let serviceUsed = '';

    // 尝试1: Vercel AI Gateway（不重试，快速失败）
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
          serviceUsed = 'AI Gateway';
        }
      } catch (error) {
        console.log('AI Gateway failed, trying next service...');
      }
    }

    // 尝试2: OpenAI直接访问
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
          serviceUsed = 'OpenAI';
        }
      } catch (error) {
        console.log('OpenAI failed, using fallback...');
      }
    }

    // 尝试3: 智能本地回复（永远可用）
    if (!aiMessage) {
      aiMessage = generateSmartFallback(message);
      serviceUsed = 'Local Smart';
      
      // 如果有用户名，个性化回复
      if (userInfo.name) {
        aiMessage = `${userInfo.name}，` + aiMessage;
      }
    }

    // 返回响应 - 保证始终有回复
    res.status(200).json({
      response: aiMessage,
      success: true,
      service: serviceUsed
    });

  } catch (error) {
    console.error('Chat error, using fallback:', error);
    
    // 即使出错也返回一个回复
    res.status(200).json({
      response: generateSmartFallback(req.body?.message || ''),
      success: true,
      service: 'Emergency Fallback'
    });
  }
}