//
//  IztroWebView.swift
//  PurpleM
//
//  使用原始iztro JavaScript算法
//

import SwiftUI
import WebKit

struct IztroWebView: UIViewRepresentable {
    @Binding var astrolabeData: String
    let onDataReceived: (String) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "iztroHandler")
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true
        
        // 允许文件访问
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // 加载本地HTML文件
        if let htmlPath = Bundle.main.path(forResource: "iztro", ofType: "html") {
            let htmlUrl = URL(fileURLWithPath: htmlPath)
            let bundleUrl = URL(fileURLWithPath: Bundle.main.bundlePath)
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: bundleUrl)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 当需要计算时，调用JavaScript函数
        if !astrolabeData.isEmpty {
            // 需要转义JSON字符串中的特殊字符
            let escapedData = astrolabeData
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            
            let jsCode = "calculateAstrolabe('\(escapedData)')"
            print("Executing JavaScript: \(jsCode)")
            
            webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("JavaScript error: \(error)")
                } else {
                    print("JavaScript executed successfully")
                }
            }
            
            // 清空数据避免重复调用
            DispatchQueue.main.async {
                self.astrolabeData = ""
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: IztroWebView
        
        init(_ parent: IztroWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "iztroHandler", let data = message.body as? String {
                print("Received from JavaScript: \(data)")
                parent.onDataReceived(data)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView loaded successfully")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed to load: \(error)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView failed provisional navigation: \(error)")
        }
    }
}