import { createClient } from '@supabase/supabase-js';

// 初始化Supabase客户端
function getSupabaseClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  if (!supabaseUrl || !supabaseKey) {
    console.error('Missing Supabase environment variables');
    throw new Error('Supabase configuration missing');
  }
  
  return createClient(supabaseUrl, supabaseKey);
}

export default async function handler(req, res) {
  // CORS设置
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // 从URL路径提取操作类型
  const { action } = req.query;

  try {
    // 初始化Supabase客户端
    const supabase = getSupabaseClient();
    
    switch (action) {
      case 'login':
        return await handleLogin(req, res, supabase);
      case 'signup':
        return await handleSignup(req, res, supabase);
      case 'logout':
        return await handleLogout(req, res, supabase);
      case 'reset-password':
        return await handleResetPassword(req, res, supabase);
      case 'validate':
        return await handleValidate(req, res, supabase);
      default:
        return res.status(404).json({ error: 'Action not found' });
    }
  } catch (error) {
    console.error('Auth error:', error);
    res.status(500).json({ 
      error: error.message || '服务器错误，请稍后重试',
      success: false 
    });
  }
}

// 处理登录
async function handleLogin(req, res, supabase) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ 
      error: '请提供邮箱和密码' 
    });
  }

  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email,
    password
  });

  if (authError) {
    return res.status(401).json({ 
      error: authError.message || '登录失败' 
    });
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', authData.user.id)
    .single();

  const user = {
    id: authData.user.id,
    email: authData.user.email,
    username: profile?.username || null,
    avatar_url: profile?.avatar_url || null,
    subscription_tier: profile?.subscription_tier || 'free',
    created_at: authData.user.created_at
  };

  res.status(200).json({
    user,
    access_token: authData.session.access_token,
    refresh_token: authData.session.refresh_token,
    success: true
  });
}

// 处理注册
async function handleSignup(req, res, supabase) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { email, password, username } = req.body;
  
  console.log('Signup request:', { email, username });

  if (!email || !password || !username) {
    return res.status(400).json({ 
      error: '请提供完整的注册信息' 
    });
  }

  if (password.length < 6) {
    return res.status(400).json({ 
      error: '密码至少需要6个字符' 
    });
  }

  try {
    // 检查用户名是否已存在
    const { data: existingUser, error: checkError } = await supabase
      .from('profiles')
      .select('username')
      .eq('username', username)
      .single();

    if (checkError && checkError.code !== 'PGRST116') {
      console.error('Check username error:', checkError);
    }

    if (existingUser) {
      return res.status(400).json({ 
        error: '该用户名已被使用' 
      });
    }

    // 注册用户（传递username到user metadata）
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
      console.error('Signup error:', authError);
      return res.status(400).json({ 
        error: authError.message || '注册失败' 
      });
    }
    
    console.log('User created:', authData.user?.id);

    // 注意：profile、quota和preferences会由数据库触发器自动创建
    // 我们只需要等待一下让触发器完成
    await new Promise(resolve => setTimeout(resolve, 1000));

    // 验证profile是否创建成功
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', authData.user.id)
      .single();

    if (profileError) {
      console.error('Profile not found after creation:', profileError);
      // 如果触发器失败，手动创建
      const { error: manualError } = await supabase
        .from('profiles')
        .insert({
          id: authData.user.id,
          email: authData.user.email,
          username: username,
          subscription_tier: 'free'
        });
      
      if (manualError) {
        console.error('Manual profile creation failed:', manualError);
      }
    }

    const user = {
      id: authData.user.id,
      email: authData.user.email,
      username: username,
      avatar_url: null,  // 使用snake_case
      subscription_tier: profile?.subscription_tier || 'free',  // 使用snake_case
      created_at: authData.user.created_at
    };

    return res.status(200).json({
      user,
      access_token: authData.session?.access_token || null,
      refresh_token: authData.session?.refresh_token || null,
      success: true,
      message: '注册成功！请查收邮件验证您的账号。'
    });
  } catch (error) {
    console.error('Unexpected error during signup:', error);
    return res.status(500).json({
      error: error.message || '注册过程中发生错误',
      success: false
    });
  }
}

// 处理登出
async function handleLogout(req, res, supabase) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = req.headers.authorization?.replace('Bearer ', '');

  if (token) {
    const { error } = await supabase.auth.admin.signOut(token);
    if (error) {
      console.error('Logout error:', error);
    }
  }

  res.status(200).json({
    success: true,
    message: '已成功登出'
  });
}

// 处理密码重置
async function handleResetPassword(req, res, supabase) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ 
      error: '请提供邮箱地址' 
    });
  }

  const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: 'https://purple-m.vercel.app/reset-password-confirm'
  });

  if (error) {
    console.error('Reset password error:', error);
  }

  res.status(200).json({
    success: true,
    message: '如果该邮箱已注册，您将收到重置密码的链接'
  });
}

// 处理验证
async function handleValidate(req, res, supabase) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = req.headers.authorization?.replace('Bearer ', '');

  if (!token) {
    return res.status(401).json({ 
      error: '未提供认证令牌',
      valid: false 
    });
  }

  const { data: { user }, error } = await supabase.auth.getUser(token);

  if (error || !user) {
    return res.status(401).json({ 
      error: '无效的认证令牌',
      valid: false 
    });
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single();

  res.status(200).json({
    valid: true,
    user: {
      id: user.id,
      email: user.email,
      username: profile?.username || null,
      avatar_url: profile?.avatar_url || null,
      subscription_tier: profile?.subscription_tier || 'free',
      created_at: user.created_at
    }
  });
}