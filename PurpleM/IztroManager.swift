//
//  IztroManager.swift
//  PurpleM
//
//  管理WebView和JavaScript交互
//

import SwiftUI
import WebKit

class IztroManager: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    @Published var isReady = false
    @Published var resultData = ""
    @Published var isCalculating = false
    
    private var webView: WKWebView?
    
    override init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "iztroHandler")
        // 使用新的API来启用JavaScript（iOS 14.0+）
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            config.preferences.javaScriptEnabled = true
        }
        
        // 允许文件访问
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self
        
        // 加载HTML文件（使用final版本）
        if let htmlPath = Bundle.main.path(forResource: "iztro-final", ofType: "html") {
            let htmlUrl = URL(fileURLWithPath: htmlPath)
            let bundleUrl = URL(fileURLWithPath: Bundle.main.bundlePath)
            webView?.loadFileURL(htmlUrl, allowingReadAccessTo: bundleUrl)
        }
    }
    
    func calculate(year: Int, month: Int, day: Int, hour: Int, minute: Int, gender: String, isLunar: Bool) {
        guard isReady else {
            print("WebView not ready yet")
            return
        }
        
        isCalculating = true
        
        let input = [
            "year": year,
            "month": month,
            "day": day,
            "hour": hour,
            "minute": minute,
            "gender": gender,
            "fixLeap": false,
            "isLunar": isLunar
        ] as [String : Any]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: input),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            // 转义JSON字符串
            let escapedData = jsonString
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\"", with: "\\\"")
            
            let jsCode = "calculateAstrolabe('\(escapedData)')"
            print("Executing: \(jsCode)")
            
            webView?.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("JavaScript error: \(error)")
                    DispatchQueue.main.async {
                        self.isCalculating = false
                    }
                }
            }
        }
    }
    
    // MARK: - 大运数据获取
    func getDecadalData(age: Int, completion: @escaping (DecadalData?) -> Void) {
        guard isReady else {
            print("WebView not ready")
            completion(nil)
            return
        }
        
        let jsCode = "getDecadalData(\(age))"
        
        webView?.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("获取大运数据失败: \(error)")
                completion(nil)
                return
            }
            
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let response = try? JSONDecoder().decode(DecadalResponse.self, from: data),
               response.success {
                completion(response.data)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - 流年数据获取
    func getYearlyData(year: Int, completion: @escaping (YearlyData?) -> Void) {
        guard isReady else {
            print("WebView not ready")
            completion(nil)
            return
        }
        
        let jsCode = "getYearlyData(\(year))"
        
        webView?.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("获取流年数据失败: \(error)")
                completion(nil)
                return
            }
            
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let response = try? JSONDecoder().decode(YearlyResponse.self, from: data),
               response.success {
                completion(response.data)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - 流月数据获取
    func getMonthlyData(year: Int, month: Int, completion: @escaping (MonthlyData?) -> Void) {
        guard isReady else {
            print("WebView not ready")
            completion(nil)
            return
        }
        
        let jsCode = "getMonthlyData(\(year), \(month))"
        
        webView?.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("获取流月数据失败: \(error)")
                completion(nil)
                return
            }
            
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let response = try? JSONDecoder().decode(MonthlyResponse.self, from: data),
               response.success {
                completion(response.data)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - 流日数据获取
    func getDailyData(year: Int, month: Int, day: Int, completion: @escaping (DailyData?) -> Void) {
        guard isReady else {
            print("WebView not ready")
            completion(nil)
            return
        }
        
        let jsCode = "getDailyData(\(year), \(month), \(day))"
        
        webView?.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("获取流日数据失败: \(error)")
                completion(nil)
                return
            }
            
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let response = try? JSONDecoder().decode(DailyResponse.self, from: data),
               response.success {
                completion(response.data)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView loaded successfully")
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "iztroHandler", let data = message.body as? String {
            print("Received from JavaScript: \(data)")
            
            if data.contains("\"status\":\"ready\"") {
                DispatchQueue.main.async {
                    self.isReady = true
                    print("IztroManager is ready!")
                }
            } else {
                // 打印完整的JSON结构以分析所有星曜字段
                if let jsonData = data.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    print("\n========== 完整JSON数据结构 ==========")
                    
                    // 打印每个宫位的详细信息
                    if let palaces = json["palaces"] as? [[String: Any]] {
                        for (index, palace) in palaces.enumerated() {
                            print("\n【第\(index)个宫位】: \(palace["name"] ?? "")")
                            
                            // 打印所有字段名
                            for (key, value) in palace {
                                if let array = value as? [[String: Any]], !array.isEmpty {
                                    print("  - \(key): 包含 \(array.count) 个项目")
                                    for item in array {
                                        if let name = item["name"] as? String {
                                            print("    • \(name)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    print("========================================\n")
                }
                
                DispatchQueue.main.async {
                    self.resultData = data
                    self.isCalculating = false
                }
            }
        }
    }
}

// MARK: - 运限数据结构

// 大运数据
struct DecadalData: Codable {
    let palace: String
    let palaceIndex: Int
    let range: [Int]
    let heavenlyStem: String
    let earthlyBranch: String
    // stars字段改为可选的字符串数组，因为Any类型不符合Codable
    let stars: [String]?
}

struct DecadalResponse: Codable {
    let success: Bool
    let data: DecadalData?
    let error: String?
}

// 流年数据
struct YearlyData: Codable {
    let year: Int
    let palaces: [YearlyPalace]
    let mutagen: [String]
}

struct YearlyPalace: Codable {
    let name: String
    let index: Int
    let jiangqian12: [String]
    let suiqian12: [String]
}

struct YearlyResponse: Codable {
    let success: Bool
    let data: YearlyData?
    let error: String?
}

// MARK: - 流月数据结构
struct MonthlyData: Codable {
    let year: Int
    let month: Int
    let palaces: [MonthlyPalace]
    let mainInfluence: String
    let scores: FortuneScores
}

struct MonthlyPalace: Codable {
    let name: String
    let index: Int
    let isMonthlyFocus: Bool
}

struct MonthlyResponse: Codable {
    let success: Bool
    let data: MonthlyData?
    let error: String?
}

// MARK: - 流日数据结构
struct DailyData: Codable {
    let year: Int
    let month: Int
    let day: Int
    let weekday: Int
    let lunarDay: String
    let luckyHours: [String]
    let suitable: [String]
    let avoid: [String]
    let scores: FortuneScores
    let mainPalace: Int
}

struct FortuneScores: Codable {
    let overall: Int
    let career: Int
    let love: Int
    let wealth: Int
    let health: Int
}

struct DailyResponse: Codable {
    let success: Bool
    let data: DailyData?
    let error: String?
}