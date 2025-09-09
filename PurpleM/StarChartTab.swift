//
//  StarChartTab.swift  
//  PurpleM
//
//  Tab1: 星盘展示 - 智能显示用户星盘或引导输入
//

import SwiftUI

struct StarChartTab: View {
    @ObservedObject var iztroManager: IztroManager
    @StateObject private var userDataManager = UserDataManager.shared
    @State private var showInputView = false
    @State private var isGeneratingChart = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                if userDataManager.needsInitialSetup() {
                    // 首次使用，显示欢迎界面
                    WelcomeView(showInputView: $showInputView)
                } else if userDataManager.canShowChart() {
                    // 已有星盘数据，直接显示
                    if let chartData = userDataManager.currentChart {
                        PerfectChartRenderer(jsonData: chartData.jsonData)
                            .transition(.opacity)
                    }
                } else if userDataManager.needsChartGeneration() {
                    // 有用户信息但没有星盘，自动生成
                    GeneratingChartView()
                        .onAppear {
                            generateChartForCurrentUser()
                        }
                }
            }
            .sheet(isPresented: $showInputView) {
                UserInfoInputView(iztroManager: iztroManager, onComplete: {
                    showInputView = false
                    // 输入完成后自动生成星盘
                    generateChartForCurrentUser()
                })
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func generateChartForCurrentUser() {
        guard let user = userDataManager.currentUser else { return }
        
        isGeneratingChart = true
        
        // 调用算法生成星盘
        iztroManager.calculate(
            year: user.birthYear,
            month: user.birthMonth,
            day: user.birthDay,
            hour: user.birthHour,
            minute: user.birthMinute,
            gender: user.gender,
            isLunar: user.isLunarDate
        )
        
        // 创建一个定时器监听结果
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if !iztroManager.resultData.isEmpty {
                userDataManager.saveGeneratedChart(
                    jsonData: iztroManager.resultData,
                    userInfo: user
                )
                isGeneratingChart = false
                timer.invalidate()
            } else if !iztroManager.isCalculating {
                // 如果计算已完成但没有结果，可能出错了
                isGeneratingChart = false
                timer.invalidate()
            }
        }
    }
}

// MARK: - 欢迎视图
struct WelcomeView: View {
    @Binding var showInputView: Bool
    @State private var animateTitle = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Logo动画
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.starGold, Color.mysticPink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(animateTitle ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 20)
                            .repeatForever(autoreverses: false),
                        value: animateTitle
                    )
                
                Image(systemName: "star.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.starGold, Color.mysticPink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 10) {
                Text("星语时光")
                    .font(.system(size: 42, weight: .thin, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.starGold, Color.crystalWhite]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("紫微斗数 · 探索命运的奥秘")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.moonSilver)
                    .opacity(0.8)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    showInputView = true
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("开启星盘之旅")
                    Image(systemName: "sparkles")
                }
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.cosmicPurple, Color.mysticPink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.mysticPink.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            
            Spacer()
        }
        .onAppear {
            animateTitle = true
        }
    }
}

// MARK: - 生成中视图
struct GeneratingChartView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 30) {
            // 加载动画
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.starGold.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: CGFloat(60 + index * 30), height: CGFloat(60 + index * 30))
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            Animation.linear(duration: Double(2 + index))
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.starGold)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 1)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            
            Text("正在生成您的星盘...")
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundColor(.crystalWhite)
            
            Text("星辰归位中，请稍候")
                .font(.system(size: 14))
                .foregroundColor(.moonSilver.opacity(0.8))
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct StarChartTab_Previews: PreviewProvider {
    static var previews: some View {
        StarChartTab(iztroManager: IztroManager())
    }
}