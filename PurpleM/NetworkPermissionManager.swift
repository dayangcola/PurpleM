//
//  NetworkPermissionManager.swift
//  PurpleM
//
//  Created by assistant on 2025/9/13.
//

import SwiftUI
import Network

class NetworkPermissionManager: ObservableObject {
    static let shared = NetworkPermissionManager()
    
    @Published var isNetworkPermissionGranted = false
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
            // 首次启动时直接发起网络请求，触发系统权限弹窗
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.requestNetworkPermission()
            }
        } else {
            performInitialNetworkRequest()
        }
    }
    
    private func requestNetworkPermission() {
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
}