import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  // CORS设置
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { email, password } = req.body;

    // 验证输入
    if (!email || !password) {
      return res.status(400).json({ 
        error: '请提供邮箱和密码' 
      });
    }

    // 使用Supabase认证
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (authError) {
      return res.status(401).json({ 
        error: authError.message || '登录失败' 
      });
    }

    // 获取用户profile
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', authData.user.id)
      .single();

    if (profileError) {
      console.error('Profile fetch error:', profileError);
    }

    // 构建用户对象
    const user = {
      id: authData.user.id,
      email: authData.user.email,
      username: profile?.username || null,
      avatarUrl: profile?.avatar_url || null,
      subscriptionTier: profile?.subscription_tier || 'free',
      createdAt: authData.user.created_at
    };

    res.status(200).json({
      user,
      access_token: authData.session.access_token,
      refresh_token: authData.session.refresh_token,
      success: true
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ 
      error: '服务器错误，请稍后重试',
      success: false 
    });
  }
}