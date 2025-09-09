//
//  UserDataManager.swift
//  PurpleM
//
//  用户数据管理器 - 使用UserDefaults持久化存储
//

import SwiftUI
import Combine

// MARK: - 用户信息模型
struct UserInfo: Codable {
    var name: String
    var gender: String
    var birthDate: Date
    var birthTime: Date
    var birthLocation: String?
    var isLunarDate: Bool
    
    // 计算属性：获取生辰信息
    var birthYear: Int {
        Calendar.current.component(.year, from: birthDate)
    }
    
    var birthMonth: Int {
        Calendar.current.component(.month, from: birthDate)
    }
    
    var birthDay: Int {
        Calendar.current.component(.day, from: birthDate)
    }
    
    var birthHour: Int {
        Calendar.current.component(.hour, from: birthTime)
    }
    
    var birthMinute: Int {
        Calendar.current.component(.minute, from: birthTime)
    }
}

// MARK: - 星盘数据模型
struct ChartData: Codable {
    let jsonData: String
    let generatedDate: Date
    let userInfo: UserInfo
}

// MARK: - 用户数据管理器
class UserDataManager: ObservableObject {
    static let shared = UserDataManager()
    
    @Published var currentUser: UserInfo? {
        didSet {
            saveUserInfo()
        }
    }
    
    @Published var currentChart: ChartData? {
        didSet {
            saveChartData()
        }
    }
    
    @Published var hasUserInfo: Bool = false
    @Published var hasGeneratedChart: Bool = false
    
    private let userInfoKey = "PurpleM_UserInfo"
    private let chartDataKey = "PurpleM_ChartData"
    
    private init() {
        loadUserInfo()
        loadChartData()
    }
    
    // MARK: - 用户信息管理
    
    func saveUserInfo() {
        guard let user = currentUser else {
            UserDefaults.standard.removeObject(forKey: userInfoKey)
            hasUserInfo = false
            return
        }
        
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userInfoKey)
            hasUserInfo = true
        }
    }
    
    func loadUserInfo() {
        guard let data = UserDefaults.standard.data(forKey: userInfoKey),
              let decoded = try? JSONDecoder().decode(UserInfo.self, from: data) else {
            hasUserInfo = false
            return
        }
        
        currentUser = decoded
        hasUserInfo = true
    }
    
    func updateUserInfo(_ info: UserInfo) {
        currentUser = info
        // 用户信息改变后，需要重新生成星盘
        currentChart = nil
        hasGeneratedChart = false
    }
    
    func clearUserInfo() {
        currentUser = nil
        currentChart = nil
        hasUserInfo = false
        hasGeneratedChart = false
    }
    
    // MARK: - 星盘数据管理
    
    func saveChartData() {
        guard let chart = currentChart else {
            UserDefaults.standard.removeObject(forKey: chartDataKey)
            hasGeneratedChart = false
            return
        }
        
        if let encoded = try? JSONEncoder().encode(chart) {
            UserDefaults.standard.set(encoded, forKey: chartDataKey)
            hasGeneratedChart = true
        }
    }
    
    func loadChartData() {
        guard let data = UserDefaults.standard.data(forKey: chartDataKey),
              let decoded = try? JSONDecoder().decode(ChartData.self, from: data) else {
            hasGeneratedChart = false
            return
        }
        
        currentChart = decoded
        hasGeneratedChart = true
    }
    
    func saveGeneratedChart(jsonData: String, userInfo: UserInfo) {
        let chartData = ChartData(
            jsonData: jsonData,
            generatedDate: Date(),
            userInfo: userInfo
        )
        currentChart = chartData
    }
    
    // MARK: - 便捷方法
    
    func needsInitialSetup() -> Bool {
        return !hasUserInfo || currentUser == nil
    }
    
    func needsChartGeneration() -> Bool {
        return hasUserInfo && !hasGeneratedChart
    }
    
    func canShowChart() -> Bool {
        return hasUserInfo && hasGeneratedChart && currentChart != nil
    }
}