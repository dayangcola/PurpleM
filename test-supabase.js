#!/usr/bin/env node

/**
 * Supabase连接测试脚本
 * 用于验证Supabase配置是否正确
 */

const https = require('https');

// 从SupabaseConfig.swift中复制的实际配置
const SUPABASE_URL = 'https://pwisjdcnhgbnjlcxjzzs.supabase.co';  
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB3aXNqZGNuaGdibmpsY3hqenpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0MzI4NDcsImV4cCI6MjA3MzAwODg0N30.sjk1teCZRGf9xc363eEyRgFnD0aPuCC3M8ttKsm9Qa4';
const VERCEL_API_URL = 'https://purple-m.vercel.app/api/chat-auto';  // Vercel API

// 颜色输出
const colors = {
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    reset: '\x1b[0m'
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

// 测试函数
async function makeRequest(url, options = {}) {
    return new Promise((resolve, reject) => {
        const urlObj = new URL(url);
        const requestOptions = {
            hostname: urlObj.hostname,
            path: urlObj.pathname + urlObj.search,
            method: options.method || 'GET',
            headers: {
                'Content-Type': 'application/json',
                'apikey': SUPABASE_ANON_KEY,
                ...options.headers
            }
        };

        const req = https.request(requestOptions, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    const result = JSON.parse(data);
                    if (res.statusCode >= 200 && res.statusCode < 300) {
                        resolve(result);
                    } else {
                        reject(new Error(`HTTP ${res.statusCode}: ${JSON.stringify(result)}`));
                    }
                } catch (e) {
                    reject(new Error(`Parse error: ${data}`));
                }
            });
        });

        req.on('error', reject);
        
        if (options.body) {
            req.write(JSON.stringify(options.body));
        }
        
        req.end();
    });
}

// 测试套件
async function runTests() {
    log('\n🧪 开始测试Supabase连接...\n', 'blue');
    
    let passedTests = 0;
    let failedTests = 0;
    
    // Test 1: 测试Supabase健康检查
    try {
        log('1. 测试Supabase服务状态...', 'yellow');
        const healthUrl = `${SUPABASE_URL}/rest/v1/`;
        const health = await makeRequest(healthUrl);
        log('   ✅ Supabase服务正常', 'green');
        passedTests++;
    } catch (error) {
        log(`   ❌ Supabase连接失败: ${error.message}`, 'red');
        log('   请检查 SUPABASE_URL 和 SUPABASE_ANON_KEY 是否正确', 'yellow');
        failedTests++;
    }
    
    // Test 2: 测试profiles表访问
    try {
        log('\n2. 测试profiles表访问权限...', 'yellow');
        const profilesUrl = `${SUPABASE_URL}/rest/v1/profiles?select=id&limit=1`;
        const profiles = await makeRequest(profilesUrl);
        log('   ✅ profiles表可访问', 'green');
        passedTests++;
    } catch (error) {
        log(`   ❌ profiles表访问失败: ${error.message}`, 'red');
        log('   请确保已创建profiles表并设置了RLS策略', 'yellow');
        failedTests++;
    }
    
    // Test 3: 测试chat_sessions表
    try {
        log('\n3. 测试chat_sessions表...', 'yellow');
        const sessionsUrl = `${SUPABASE_URL}/rest/v1/chat_sessions?select=id&limit=1`;
        const sessions = await makeRequest(sessionsUrl);
        log('   ✅ chat_sessions表可访问', 'green');
        passedTests++;
    } catch (error) {
        log(`   ❌ chat_sessions表访问失败: ${error.message}`, 'red');
        log('   请运行schema.sql创建表结构', 'yellow');
        failedTests++;
    }
    
    // Test 4: 测试chat_messages表
    try {
        log('\n4. 测试chat_messages表...', 'yellow');
        const messagesUrl = `${SUPABASE_URL}/rest/v1/chat_messages?select=id&limit=1`;
        const messages = await makeRequest(messagesUrl);
        log('   ✅ chat_messages表可访问', 'green');
        passedTests++;
    } catch (error) {
        log(`   ❌ chat_messages表访问失败: ${error.message}`, 'red');
        failedTests++;
    }
    
    // Test 5: 测试user_ai_preferences表
    try {
        log('\n5. 测试user_ai_preferences表...', 'yellow');
        const prefsUrl = `${SUPABASE_URL}/rest/v1/user_ai_preferences?select=id&limit=1`;
        const prefs = await makeRequest(prefsUrl);
        log('   ✅ user_ai_preferences表可访问', 'green');
        passedTests++;
    } catch (error) {
        log(`   ❌ user_ai_preferences表访问失败: ${error.message}`, 'red');
        failedTests++;
    }
    
    // Test 6: 测试user_ai_quotas表
    try {
        log('\n6. 测试user_ai_quotas表...', 'yellow');
        const quotasUrl = `${SUPABASE_URL}/rest/v1/user_ai_quotas?select=id&limit=1`;
        const quotas = await makeRequest(quotasUrl);
        log('   ✅ user_ai_quotas表可访问', 'green');
        passedTests++;
    } catch (error) {
        log(`   ❌ user_ai_quotas表访问失败: ${error.message}`, 'red');
        failedTests++;
    }
    
    // Test 7: 测试Vercel AI API
    try {
        log('\n7. 测试Vercel AI API...', 'yellow');
        const testMessage = {
            message: '你好',
            conversationHistory: [],
            userInfo: {
                name: '测试用户'
            }
        };
        
        const response = await new Promise((resolve, reject) => {
            const urlObj = new URL(VERCEL_API_URL);
            const postData = JSON.stringify(testMessage);
            
            const options = {
                hostname: urlObj.hostname,
                path: urlObj.pathname,
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData)
                }
            };
            
            const req = https.request(options, (res) => {
                let data = '';
                res.on('data', (chunk) => data += chunk);
                res.on('end', () => {
                    try {
                        const result = JSON.parse(data);
                        if (res.statusCode === 200) {
                            resolve(result);
                        } else {
                            reject(new Error(`HTTP ${res.statusCode}: ${data}`));
                        }
                    } catch (e) {
                        reject(new Error(`Parse error: ${data}`));
                    }
                });
            });
            
            req.on('error', reject);
            req.write(postData);
            req.end();
        });
        
        if (response.success && response.response) {
            log('   ✅ Vercel AI API正常工作', 'green');
            log(`   收到回复: "${response.response.substring(0, 50)}..."`, 'blue');
            passedTests++;
        } else {
            log('   ⚠️  AI API返回异常', 'yellow');
        }
    } catch (error) {
        log(`   ❌ Vercel AI API测试失败: ${error.message}`, 'red');
        failedTests++;
    }
    
    // Test 8: 测试RPC函数
    try {
        log('\n8. 测试search_knowledge RPC函数...', 'yellow');
        const rpcUrl = `${SUPABASE_URL}/rest/v1/rpc/search_knowledge`;
        const rpcBody = { query: '紫微' };
        
        const result = await makeRequest(rpcUrl, {
            method: 'POST',
            body: rpcBody
        });
        
        log('   ✅ RPC函数可用', 'green');
        if (Array.isArray(result) && result.length > 0) {
            log(`   找到 ${result.length} 条相关知识`, 'blue');
        }
        passedTests++;
    } catch (error) {
        log(`   ⚠️  RPC函数未找到或未配置: ${error.message}`, 'yellow');
        log('   这是可选功能，不影响基本使用', 'blue');
    }
    
    // 测试总结
    log('\n' + '='.repeat(50), 'blue');
    log(`\n📊 测试完成！\n`, 'blue');
    log(`   ✅ 通过: ${passedTests} 项`, 'green');
    if (failedTests > 0) {
        log(`   ❌ 失败: ${failedTests} 项`, 'red');
    }
    
    if (failedTests === 0) {
        log('\n🎉 恭喜！所有测试通过，系统配置正确！', 'green');
    } else {
        log('\n⚠️  部分测试失败，请根据提示检查配置', 'yellow');
        log('\n建议检查项：', 'yellow');
        log('1. 确认Supabase URL和API Key正确', 'yellow');
        log('2. 确认已运行schema.sql创建所有表', 'yellow');
        log('3. 确认RLS策略已正确设置', 'yellow');
        log('4. 确认Vercel部署成功', 'yellow');
    }
}

// 主函数
async function main() {
    log('====================================', 'blue');
    log('   Purple星语 Supabase 连接测试', 'blue');
    log('====================================', 'blue');
    
    // 配置已经设置好，可以直接运行测试
    
    // 运行测试
    await runTests();
}

// 执行
main().catch(error => {
    log(`\n❌ 测试过程出错: ${error.message}`, 'red');
    process.exit(1);
});