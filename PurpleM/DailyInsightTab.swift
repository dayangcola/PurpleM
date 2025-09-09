//
//  DailyInsightTab.swift
//  PurpleM
//
//  Tab2: 今日要点 - 每日运势和个人洞察
//

import SwiftUI

struct DailyInsightTab: View {
    @State private var currentDate = Date()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 复用相同的背景
                AnimatedBackground()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // 标题区域
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "sun.max.circle")
                                    .font(.system(size: 28))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.starGold, .mysticPink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text("今日要点")
                                    .font(.system(size: 26, weight: .light, design: .serif))
                                    .foregroundColor(.crystalWhite)
                            }
                            
                            Text(formatDate(currentDate))
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.moonSilver)
                        }
                        .padding(.top, 20)
                        
                        // 占位内容卡片
                        GlassmorphicCard {
                            VStack(spacing: 15) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.starGold)
                                    Text("每日运势")
                                        .font(.headline)
                                        .foregroundColor(.crystalWhite)
                                    Spacer()
                                }
                                
                                Text("正在开发中...")
                                    .font(.body)
                                    .foregroundColor(.moonSilver)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("即将为您提供：")
                                    .font(.subheadline)
                                    .foregroundColor(.moonSilver.opacity(0.8))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    FeatureItem(icon: "calendar", text: "今日整体运势")
                                    FeatureItem(icon: "briefcase", text: "事业运势分析")
                                    FeatureItem(icon: "heart", text: "感情运势指引")
                                    FeatureItem(icon: "leaf", text: "健康注意事项")
                                    FeatureItem(icon: "paintbrush", text: "幸运色彩推荐")
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 心情记录卡片
                        GlassmorphicCard {
                            VStack(spacing: 15) {
                                HStack {
                                    Image(systemName: "book.circle")
                                        .foregroundColor(.mysticPink)
                                    Text("心情日记")
                                        .font(.headline)
                                        .foregroundColor(.crystalWhite)
                                    Spacer()
                                }
                                
                                Text("记录每天的心情变化，与星象运势对比分析")
                                    .font(.body)
                                    .foregroundColor(.moonSilver)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 EEEE"
        return formatter.string(from: date)
    }
}

// 功能项目视图
struct FeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.starGold.opacity(0.8))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.crystalWhite.opacity(0.9))
            Spacer()
        }
    }
}

struct DailyInsightTab_Previews: PreviewProvider {
    static var previews: some View {
        DailyInsightTab()
    }
}