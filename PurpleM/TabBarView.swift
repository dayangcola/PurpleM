//
//  TabBarView.swift
//  PurpleM
//
//  主Tab容器 - Purple星语时光
//

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0
    @StateObject private var iztroManager = IztroManager()
    @StateObject private var userDataManager = UserDataManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 星盘展示
            StarChartTab(iztroManager: iztroManager, userDataManager: userDataManager)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "star.circle.fill" : "star.circle")
                    Text("星盘")
                }
                .tag(0)
            
            // Tab 2: 今日要点
            DailyInsightTab()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "sun.max.fill" : "sun.max")
                    Text("今日")
                }
                .tag(1)
            
            // Tab 3: 聊天
            ChatTab()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "message.circle.fill" : "message.circle")
                    Text("聊天")
                }
                .tag(2)
            
            // Tab 4: 个人中心
            ProfileTab()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.circle.fill" : "person.circle")
                    Text("我的")
                }
                .tag(3)
        }
        .accentColor(.mysticPink)
        .onAppear {
            // 自定义TabBar样式
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        // 设置TabBar背景
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        
        // 设置选中状态颜色
        appearance.selectionIndicatorTintColor = UIColor(Color.mysticPink)
        
        // 应用样式
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarView()
    }
}