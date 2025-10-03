import Foundation

struct SupabaseConfig {
    // 从Vercel获取的配置信息
    static let url = URL(string: "https://pwisjdcnhgbnjlcxjzzs.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB3aXNqZGNuaGdibmpsY3hqenpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0MzI4NDcsImV4cCI6MjA3MzAwODg0N30.sjk1teCZRGf9xc363eEyRgFnD0aPuCC3M8ttKsm9Qa4"
    
    // Service Role Key - 需要从Supabase仪表板获取正确的key
    // 注意：仅用于开发！生产环境不应在客户端使用此key
    // 暂时使用anon key，等待应用RLS策略后即可正常工作
    static let serviceRoleKey = anonKey  // 临时使用anon key
    
    // 深链接配置
    static let redirectURL = URL(string: "purplem://auth-callback")!
    
    // API端点
    static let apiBaseURL = "https://purple-m.vercel.app/api"
}