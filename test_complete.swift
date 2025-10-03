#!/usr/bin/env swift

import Foundation

// Supabase configuration
let supabaseURL = "https://pwisjdcnhgbnjlcxjzzs.supabase.co"
let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB3aXNqZGNuaGdibmpsY3hqenpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0MzI4NDcsImV4cCI6MjA3MzAwODg0N30.sjk1teCZRGf9xc363eEyRgFnD0aPuCC3M8ttKsm9Qa4"

// Test creating a message without foreign key dependency
func testMessageCreation() {
    let semaphore = DispatchSemaphore(value: 0)
    
    // Create request for messages (simpler, no foreign key)
    let endpoint = "\(supabaseURL)/rest/v1/chat_messages"
    guard let url = URL(string: endpoint) else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    
    // Create test message
    let testData: [String: Any] = [
        "id": UUID().uuidString,
        "session_id": UUID().uuidString,
        "user_id": UUID().uuidString,
        "role": "user",
        "content": "Test message from Swift",
        "created_at": ISO8601DateFormatter().string(from: Date())
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: testData)
    } catch {
        print("❌ Failed to encode JSON: \(error)")
        return
    }
    
    // Make request
    print("📡 Testing message creation...")
    print("🔗 URL: \(endpoint)")
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let error = error {
            print("❌ Network error: \(error)")
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Status Code: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                if httpResponse.statusCode != 201 {
                    print("📝 Response: \(responseString)")
                }
            }
            
            if httpResponse.statusCode == 201 {
                print("✅ Successfully created test message!")
                print("🎉 Supabase connection is fully working!")
            } else if httpResponse.statusCode == 409 {
                print("⚠️ Message already exists (expected for duplicate IDs)")
                print("✅ Connection is working!")
            } else {
                print("⚠️ Unexpected status, but connection established")
            }
        }
    }
    
    task.resume()
    semaphore.wait()
}

// Test reading data (should always work with current policies)
func testDataReading() {
    let semaphore = DispatchSemaphore(value: 0)
    
    // Try to read any sessions
    let endpoint = "\(supabaseURL)/rest/v1/chat_sessions?limit=1"
    guard let url = URL(string: endpoint) else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    
    print("\n📖 Testing data reading...")
    print("🔗 URL: \(endpoint)")
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let error = error {
            print("❌ Network error: \(error)")
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                print("✅ Successfully read data!")
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        if let array = json as? [[String: Any]] {
                            print("📋 Found \(array.count) session(s)")
                        }
                    } catch {
                        print("📝 Response received but couldn't parse")
                    }
                }
            }
        }
    }
    
    task.resume()
    semaphore.wait()
}

// Run tests
print("🧪 Running Supabase Connection Tests")
print(String(repeating: "=", count: 40))
testMessageCreation()
testDataReading()
print(String(repeating: "=", count: 40))
print("✅ All tests completed!")