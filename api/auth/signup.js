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
    const { email, password, username } = req.body;

    // 验证输入
    if (!email || !password || !username) {
      return res.status(400).json({ 
        error: '请提供完整的注册信息' 
      });
    }

    // 验证密码长度
    if (password.length < 6) {
      return res.status(400).json({ 
        error: '密码至少需要6个字符' 
      });
    }

    // 检查用户名是否已存在
    const { data: existingUser } = await supabase
      .from('profiles')
      .select('username')
      .eq('username', username)
      .single();

    if (existingUser) {
      return res.status(400).json({ 
        error: '该用户名已被使用' 
      });
    }

    // 创建用户
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          username: username
        }
      }
    });

    if (authError) {
      return res.status(400).json({ 
        error: authError.message || '注册失败' 
      });
    }

    // 创建或更新profile
    const { error: profileError } = await supabase
      .from('profiles')
      .upsert({
        id: authData.user.id,
        email: authData.user.email,
        username: username,
        subscription_tier: 'free',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      });

    if (profileError) {
      console.error('Profile creation error:', profileError);
      // 不影响注册流程
    }

    // 初始化用户AI配额
    const { error: quotaError } = await supabase
      .from('user_ai_quotas')
      .insert({
        user_id: authData.user.id,
        subscription_tier: 'free',
        daily_limit: 50,
        monthly_limit: 1000,
        daily_used: 0,
        monthly_used: 0,
        total_tokens_used: 0,
        daily_reset_at: new Date().toISOString().split('T')[0],
        monthly_reset_at: new Date().toISOString()
      });

    if (quotaError) {
      console.error('Quota initialization error:', quotaError);
    }

    // 初始化用户AI偏好设置
    const { error: prefError } = await supabase
      .from('user_ai_preferences')
      .insert({
        user_id: authData.user.id,
        conversation_style: 'mystical',
        response_length: 'medium',
        language_complexity: 'normal',
        auto_save_sessions: true,
        show_interpretation_hints: true
      });

    if (prefError) {
      console.error('Preferences initialization error:', prefError);
    }

    // 构建用户对象
    const user = {
      id: authData.user.id,
      email: authData.user.email,
      username: username,
      avatarUrl: null,
      subscriptionTier: 'free',
      createdAt: authData.user.created_at
    };

    res.status(200).json({
      user,
      access_token: authData.session?.access_token || null,
      refresh_token: authData.session?.refresh_token || null,
      success: true,
      message: '注册成功！请查收邮件验证您的账号。'
    });

  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ 
      error: '服务器错误，请稍后重试',
      success: false 
    });
  }
}