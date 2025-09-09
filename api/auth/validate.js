import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  // CORS设置
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // 获取Authorization header
    const token = req.headers.authorization?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({ 
        error: '未提供认证令牌',
        valid: false 
      });
    }

    // 验证token
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error || !user) {
      return res.status(401).json({ 
        error: '无效的认证令牌',
        valid: false 
      });
    }

    // 获取用户profile
    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    // 返回验证成功和用户信息
    res.status(200).json({
      valid: true,
      user: {
        id: user.id,
        email: user.email,
        username: profile?.username || null,
        avatarUrl: profile?.avatar_url || null,
        subscriptionTier: profile?.subscription_tier || 'free',
        createdAt: user.created_at
      }
    });

  } catch (error) {
    console.error('Validation error:', error);
    res.status(500).json({ 
      error: '服务器错误',
      valid: false 
    });
  }
}