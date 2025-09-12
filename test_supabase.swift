#!/usr/bin/env swift

import Foundation

// Supabase configuration
let supabaseURL = "https://pwisjdcnhgbnjlcxjzzs.supabase.co"
let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB3aXNqZGNuaGdibmpsY3hqenpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0MzI4NDcsImV4cCI6MjA3MzAwODg0N30.sjk1teCZRGf9xc363eEyRgFnD0aPuCC3M8ttKsm9Qa4"

// Test creating a chat session
func testSupabaseConnection() {
    let semaphore = DispatchSemaphore(value: 0)
    
    // Create request
    let endpoint = "\(supabaseURL)/rest/v1/chat_sessions"
    guard let url = URL(string: endpoint) else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    
    // Create test data
    let testData: [String: Any] = [
        "id": UUID().uuidString,
        "user_id": UUID().uuidString,
        "session_type": "test",
        "title": "Test Session - \(Date())",
        "created_at": ISO8601DateFormatter().string(from: Date()),
        "updated_at": ISO8601DateFormatter().string(from: Date())
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: testData)
    } catch {
        print("❌ Failed to encode JSON: \(error)")
        return
    }
    
    // Make request
    print("📡 Testing Supabase connection...")
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
                print("📝 Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 201 {
                print("✅ Successfully created test session!")
                print("🎉 Supabase connection is working with service role key!")
            } else if httpResponse.statusCode == 409 {
                print("⚠️ Session already exists (expected for duplicate IDs)")
                print("✅ But connection is working!")
            } else {
                print("❌ Unexpected status code")
            }
        }
    }
    
    task.resume()
    semaphore.wait()
}

// Run test
testSupabaseConnection()