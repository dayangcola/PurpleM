#!/usr/bin/env python3
"""
自动修复makeRequest调用的脚本
将所有makeRequest替换为SupabaseAPIHelper方法
"""

import re
import os
import shutil
from datetime import datetime

def backup_file(filepath):
    """创建文件备份"""
    backup_path = f"{filepath}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(filepath, backup_path)
    print(f"✅ 备份已创建: {backup_path}")
    return backup_path

def fix_makerequest_in_file(filepath):
    """修复文件中的makeRequest调用"""
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    fixes_made = 0
    
    # 模式1: GET请求 - makeRequest(endpoint: ..., expecting: ...)
    pattern_get = r'try await SupabaseManager\.shared\.makeRequest\(\s*endpoint:\s*([^,]+),\s*expecting:\s*([^)]+)\)'
    
    def replace_get(match):
        nonlocal fixes_made
        fixes_made += 1
        endpoint = match.group(1).strip()
        expecting_type = match.group(2).strip()
        
        # 移除 .self 如果存在
        expecting_type = expecting_type.replace('.self', '')
        
        return f'''let userToken = KeychainManager.shared.getAccessToken()
            guard let data = try await SupabaseAPIHelper.get(
                endpoint: {endpoint},
                baseURL: SupabaseManager.shared.baseURL,
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken
            ) else {{
                throw APIError.invalidResponse
            }}
            let result = try JSONDecoder().decode({expecting_type}.self, from: data)'''
    
    # 模式2: POST请求 - makeRequest(endpoint: ..., method: "POST", body: ..., ...)
    pattern_post = r'try await SupabaseManager\.shared\.makeRequest\(\s*endpoint:\s*([^,]+),\s*method:\s*"POST",\s*body:\s*([^,]+),\s*(?:headers:\s*[^,]+,\s*)?expecting:\s*([^)]+)\)'
    
    def replace_post(match):
        nonlocal fixes_made
        fixes_made += 1
        endpoint = match.group(1).strip()
        body = match.group(2).strip()
        expecting_type = match.group(3).strip()
        
        return f'''let userToken = KeychainManager.shared.getAccessToken()
            _ = try await SupabaseAPIHelper.post(
                endpoint: {endpoint},
                baseURL: SupabaseManager.shared.baseURL,
                authType: .authenticated,
                apiKey: SupabaseManager.shared.apiKey,
                userToken: userToken,
                body: /* TODO: Convert {body} to dictionary */,
                useFieldMapping: false
            )'''
    
    # 应用替换
    content = re.sub(pattern_get, replace_get, content)
    content = re.sub(pattern_post, replace_post, content)
    
    # 如果有修改，写回文件
    if fixes_made > 0:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ 修复了 {fixes_made} 处makeRequest调用")
        return fixes_made
    else:
        print(f"ℹ️  没有找到需要修复的makeRequest调用")
        return 0

def main():
    """主函数"""
    files_to_fix = [
        'PurpleM/Services/DatabaseFixManager.swift',
        'PurpleM/Services/SupabaseManager.swift',
        'PurpleM/Services/SupabaseManager+Knowledge.swift',
        'PurpleM/Services/SupabaseValidationTest.swift'
    ]
    
    total_fixes = 0
    
    print("🔧 开始自动修复makeRequest调用...")
    print("=" * 50)
    
    for filepath in files_to_fix:
        if os.path.exists(filepath):
            print(f"\n📄 处理文件: {os.path.basename(filepath)}")
            backup_file(filepath)
            fixes = fix_makerequest_in_file(filepath)
            total_fixes += fixes
        else:
            print(f"❌ 文件不存在: {filepath}")
    
    print("\n" + "=" * 50)
    print(f"✅ 总共修复了 {total_fixes} 处makeRequest调用")
    print("\n⚠️  注意事项:")
    print("1. 请手动检查生成的代码")
    print("2. 确保body参数正确转换为字典格式")
    print("3. 编译并测试所有更改")

if __name__ == "__main__":
    main()