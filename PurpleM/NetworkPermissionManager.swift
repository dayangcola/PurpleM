//
//  NetworkPermissionManager.swift
//  PurpleM
//
//  Created by assistant on 2025/9/13.
//

import SwiftUI
import Network
import UserNotifications

class NetworkPermissionManager: ObservableObject {
    static let shared = NetworkPermissionManager()
    
    @Published var isNetworkPermissionGranted = false
    @Published var showNetworkPermissionAlert = false
    @Published var networkStatus: NWPath.Status = .unsatisfied
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        setupNetworkMonitor()
        checkInitialNetworkPermission()
    }
    
    private func setupNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.networkStatus = path.status
                
                if path.status == .satisfied {
                    self?.isNetworkPermissionGranted = true
                    self?.performInitialNetworkRequest()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func checkInitialNetworkPermission() {
        let hasRequestedPermission = UserDefaults.standard.bool(forKey: "hasRequestedNetworkPermission")
        
        if !hasRequestedPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showNetworkPermissionAlert = true
            }
        } else {
            performInitialNetworkRequest()
        }
    }
    
    func requestNetworkPermission() {
        UserDefaults.standard.set(true, forKey: "hasRequestedNetworkPermission")
        
        performInitialNetworkRequest()
    }
    
    private func performInitialNetworkRequest() {
        guard let url = URL(string: "https://gateway.vercel.app/api/health") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if error == nil {
                    self?.isNetworkPermissionGranted = true
                    print("网络权限已获取")
                } else {
                    print("网络请求失败: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
        task.resume()
    }
    
    func createPermissionAlert() -> Alert {
        Alert(
            title: Text("需要网络权限"),
            message: Text("紫微斗数需要访问网络来获取最新的运势数据和AI分析服务。请允许应用访问网络。"),
            primaryButton: .default(Text("允许")) {
                self.requestNetworkPermission()
                self.showNetworkPermissionAlert = false
            },
            secondaryButton: .cancel(Text("稍后")) {
                self.showNetworkPermissionAlert = false
            }
        )
    }
}

struct NetworkPermissionView: View {
    @StateObject private var permissionManager = NetworkPermissionManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("网络权限")
                .font(.title)
                .fontWeight(.bold)
            
            Text("紫微斗数需要网络权限来为您提供：")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "实时运势分析")
                PermissionFeatureRow(icon: "brain", text: "AI智能解读")
                PermissionFeatureRow(icon: "arrow.down.circle", text: "数据同步服务")
                PermissionFeatureRow(icon: "bubble.left.and.bubble.right", text: "在线咨询功能")
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            Button(action: {
                permissionManager.requestNetworkPermission()
            }) {
                Text("允许网络访问")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
            }
            .padding(.top)
            
            Button(action: {
                permissionManager.showNetworkPermissionAlert = false
            }) {
                Text("稍后决定")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(30)
    }
}

struct PermissionFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}