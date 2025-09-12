#!/usr/bin/env swift

import Foundation

// Supabase configuration
let supabaseURL = "https://pwisjdcnhgbnjlcxjzzs.supabase.co"
let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB3aXNqZGNuaGdibmpsY3hqenpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0MzI4NDcsImV4cCI6MjA3MzAwODg0N30.sjk1teCZRGf9xc363eEyRgFnD0aPuCC3M8ttKsm9Qa4"

// Test 1: Test session creation with valid session_type
func testValidSessionType() {
    let semaphore = DispatchSemaphore(value: 0)
    
    print("\n🧪 Test 1: Valid session_type")
    print(String(repeating: "-", count: 40))
    
    let endpoint = "\(supabaseURL)/rest/v1/chat_sessions"
    guard let url = URL(string: endpoint) else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    
    let testData: [String: Any] = [
        "id": UUID().uuidString,
        "user_id": UUID().uuidString,
        "session_type": "general",  // Valid type
        "title": "Test Session - Valid Type",
        "created_at": ISO8601DateFormatter().string(from: Date()),
        "updated_at": ISO8601DateFormatter().string(from: Date())
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: testData)
    } catch {
        print("❌ Failed to encode JSON")
        return
    }
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 201 {
                print("✅ Success: Session created with valid type")
            } else if httpResponse.statusCode == 409 {
                print("⚠️ Foreign key constraint (expected without profile)")
            } else if httpResponse.statusCode == 400 {
                if let data = data, let resp = String(data: data, encoding: .utf8),
                   resp.contains("session_type_check") {
                    print("❌ Failed: session_type still invalid")
                }
            }
        }
    }
    
    task.resume()
    semaphore.wait()
}

// Test 2: Test UPSERT on user_ai_preferences
func testUpsertPreferences() {
    let semaphore = DispatchSemaphore(value: 0)
    
    print("\n🧪 Test 2: UPSERT user_ai_preferences")
    print(String(repeating: "-", count: 40))
    
    let userId = UUID().uuidString
    let endpoint = "\(supabaseURL)/rest/v1/user_ai_preferences?on_conflict=user_id"
    guard let url = URL(string: endpoint) else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
    
    let preferences: [String: Any] = [
        "user_id": userId,
        "preferences": ["theme": "dark"],
        "created_at": ISO8601DateFormatter().string(from: Date()),
        "updated_at": ISO8601DateFormatter().string(from: Date())
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: preferences)
    } catch {
        print("❌ Failed to encode JSON")
        return
    }
    
    // First insert
    print("📝 First insert...")
    var firstTask = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                print("   ✅ First insert successful")
            }
        }
    }
    firstTask.resume()
    semaphore.wait()
    
    // Second insert (should update, not fail)
    print("📝 Second insert (UPSERT)...")
    let secondTask = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 409 {
                print("   ❌ Failed: UPSERT not working (duplicate key)")
            } else if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                print("   ✅ Success: UPSERT working correctly")
            }
        }
    }
    secondTask.resume()
    semaphore.wait()
}

// Test 3: Test all valid session types
func testAllSessionTypes() {
    print("\n🧪 Test 3: All valid session_type values")
    print(String(repeating: "-", count: 40))
    
    let validTypes = ["general", "chart_reading", "fortune", "consultation"]
    
    for sessionType in validTypes {
        let semaphore = DispatchSemaphore(value: 0)
        
        let endpoint = "\(supabaseURL)/rest/v1/chat_sessions"
        guard let url = URL(string: endpoint) else { continue }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let testData: [String: Any] = [
            "id": UUID().uuidString,
            "user_id": UUID().uuidString,
            "session_type": sessionType,
            "title": "Test \(sessionType)",
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testData)
        } catch {
            continue
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let httpResponse = response as? HTTPURLResponse {
                let icon = httpResponse.statusCode == 400 ? "❌" : "✅"
                print("\(icon) session_type '\(sessionType)': Status \(httpResponse.statusCode)")
            }
        }
        
        task.resume()
        semaphore.wait()
    }
}

// Run all tests
print("🚀 Running Database Fix Validation Tests")
print(String(repeating: "=", count: 50))
testValidSessionType()
testUpsertPreferences()
testAllSessionTypes()
print("\n" + String(repeating: "=", count: 50))
print("✅ All tests completed!")
print("\n💡 Next steps:")
print("1. If session_type tests pass (409, not 400) - ✅ Fixed")
print("2. If UPSERT test passes (no 409 on second insert) - ✅ Fixed")
print("3. All valid session types should not return 400")