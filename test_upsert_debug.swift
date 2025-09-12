#!/usr/bin/env swift

import Foundation

let supabaseURL = "https://pwisjdcnhgbnjlcxjzzs.supabase.co"
let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB3aXNqZGNuaGdibmpsY3hqenpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0MzI4NDcsImV4cCI6MjA3MzAwODg0N30.sjk1teCZRGf9xc363eEyRgFnD0aPuCC3M8ttKsm9Qa4"

func debugUpsert() {
    let semaphore = DispatchSemaphore(value: 0)
    let userId = UUID().uuidString
    
    // Try without on_conflict first
    print("🧪 Testing UPSERT with detailed error logging")
    print(String(repeating: "-", count: 50))
    
    let endpoint = "\(supabaseURL)/rest/v1/user_ai_preferences"
    guard let url = URL(string: endpoint) else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    request.setValue("return=representation", forHTTPHeaderField: "Prefer")
    
    let preferences: [String: Any] = [
        "id": UUID().uuidString,
        "user_id": userId,
        "model_preferences": [:],
        "memory_data": [:],
        "created_at": ISO8601DateFormatter().string(from: Date()),
        "updated_at": ISO8601DateFormatter().string(from: Date())
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: preferences)
    } catch {
        print("❌ Failed to encode JSON")
        return
    }
    
    print("📝 Attempting insert...")
    print("   User ID: \(userId)")
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Status: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📝 Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 400 {
                print("\n❌ Error 400 - likely missing required fields or invalid data format")
                print("💡 Check if user_ai_preferences table has required fields we're not providing")
            }
        }
    }
    
    task.resume()
    semaphore.wait()
}

// Test with minimal data
func testMinimalInsert() {
    let semaphore = DispatchSemaphore(value: 0)
    
    print("\n🧪 Testing minimal insert")
    print(String(repeating: "-", count: 50))
    
    let endpoint = "\(supabaseURL)/rest/v1/user_ai_preferences"
    guard let url = URL(string: endpoint) else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    
    // Try with just user_id
    let minimal: [String: Any] = [
        "user_id": UUID().uuidString
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: minimal)
    } catch {
        return
    }
    
    print("📝 Attempting minimal insert with just user_id...")
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Status: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📝 Response: \(responseString)")
            }
        }
    }
    
    task.resume()
    semaphore.wait()
}

print("🚀 Debugging UPSERT Issues")
print(String(repeating: "=", count: 50))
debugUpsert()
testMinimalInsert()
print("\n" + String(repeating: "=", count: 50))
print("✅ Debug complete!")