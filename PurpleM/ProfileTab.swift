//
//  ProfileTab.swift
//  PurpleM
//
//  Tab4: 个人中心 - 用户管理和设置
//

import SwiftUI

struct ProfileTab: View {
    @StateObject private var userDataManager = UserDataManager.shared
    @State private var showEditUserInfo = false
    @State private var userAvatar = "person.circle.fill"
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // 用户信息卡片
                        GlassmorphicCard {
                            VStack(spacing: 20) {
                                // 头像和用户名
                                VStack(spacing: 15) {
                                    Image(systemName: userAvatar)
                                        .font(.system(size: 60))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.starGold, .mysticPink],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.1))
                                                .frame(width: 100, height: 100)
                                        )
                                    
                                    Text(userDataManager.currentUser?.name ?? "星语用户")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.crystalWhite)
                                    
                                    if let user = userDataManager.currentUser {
                                        HStack {
                                            Text(user.gender)
                                            Text("·")
                                            Text(formatBirthDate(user.birthDate))
                                        }
                                        .font(.system(size: 14))
                                        .foregroundColor(.moonSilver.opacity(0.8))
                                    } else {
                                        Text("探索星语奥秘的旅程刚刚开始")
                                            .font(.system(size: 14))
                                            .foregroundColor(.moonSilver.opacity(0.8))
                                    }
                                }
                                
                                // 编辑按钮
                                Button(action: {
                                    showEditUserInfo = true
                                }) {
                                    HStack {
                                        Image(systemName: "pencil.circle")
                                        Text("编辑资料")
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(.mysticPink)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .stroke(Color.mysticPink.opacity(0.5), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // 功能列表
                        VStack(spacing: 15) {
                            // 我的星盘
                            ProfileMenuItem(
                                icon: "star.circle",
                                title: "我的星盘",
                                subtitle: "查看历史星盘记录",
                                action: { /* TODO */ }
                            )
                            
                            // 聊天记录
                            ProfileMenuItem(
                                icon: "message.circle",
                                title: "聊天记录",
                                subtitle: "与星语助手的对话历史",
                                action: { /* TODO */ }
                            )
                            
                            // 学习进度
                            ProfileMenuItem(
                                icon: "book.circle",
                                title: "学习进度",
                                subtitle: "紫微斗数知识掌握情况",
                                action: { /* TODO */ }
                            )
                            
                            // 应用设置
                            ProfileMenuItem(
                                icon: "gearshape.circle",
                                title: "应用设置",
                                subtitle: "通知、主题、隐私等设置",
                                action: { /* TODO */ }
                            )
                            
                            // 帮助与反馈
                            ProfileMenuItem(
                                icon: "questionmark.circle",
                                title: "帮助与反馈",
                                subtitle: "使用说明和意见建议",
                                action: { /* TODO */ }
                            )
                            
                            // 关于应用
                            ProfileMenuItem(
                                icon: "info.circle",
                                title: "关于Purple",
                                subtitle: "版本信息和开发团队",
                                action: { /* TODO */ }
                            )
                        }
                        .padding(.horizontal)
                        
                        // 版本信息
                        VStack(spacing: 10) {
                            Text("Purple 星语时光")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.crystalWhite)
                            
                            Text("Version 1.0.0 (Beta)")
                                .font(.system(size: 12))
                                .foregroundColor(.moonSilver.opacity(0.6))
                            
                            Text("传承千年智慧，点亮人生星光")
                                .font(.system(size: 11, weight: .light, design: .rounded))
                                .foregroundColor(.starGold.opacity(0.8))
                                .italic()
                        }
                        .padding(.top, 30)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showEditUserInfo) {
                UserInfoInputView(iztroManager: IztroManager(), onComplete: {
                    // 更新完成后刷新界面
                })
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func formatBirthDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
}

// 个人中心菜单项
struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GlassmorphicCard {
                HStack(spacing: 15) {
                    // 图标
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.starGold)
                        .frame(width: 40)
                    
                    // 文字信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.crystalWhite)
                        
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.moonSilver.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // 箭头
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.moonSilver.opacity(0.5))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileTab_Previews: PreviewProvider {
    static var previews: some View {
        ProfileTab()
    }
}