//
//  ChatTab.swift
//  PurpleM
//
//  Tab3: 聊天 - AI助手和智能问答
//

import SwiftUI

struct ChatTab: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                VStack(spacing: 0) {
                    // 顶部标题
                    HStack {
                        Image(systemName: "sparkles.tv")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.starGold, .mysticPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("星语助手")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundColor(.crystalWhite)
                        
                        Spacer()
                        
                        Button(action: {
                            // TODO: 清空聊天记录
                        }) {
                            Image(systemName: "trash.circle")
                                .foregroundColor(.moonSilver.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    
                    if messages.isEmpty {
                        // 欢迎页面
                        Spacer()
                        
                        VStack(spacing: 20) {
                            // 虚拟助手头像
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.cosmicPurple, .mysticPink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                )
                            
                            Text("你好！我是你的专属星语助手")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.crystalWhite)
                            
                            Text("我可以为你解答紫微斗数相关问题，分析你的星盘，或者陪你聊天")
                                .font(.system(size: 14))
                                .foregroundColor(.moonSilver)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            // 快捷问题
                            VStack(spacing: 10) {
                                Text("你可以问我：")
                                    .font(.system(size: 12))
                                    .foregroundColor(.moonSilver.opacity(0.8))
                                
                                QuickQuestionButton(text: "我的性格特点是什么？")
                                QuickQuestionButton(text: "今天适合做什么？")
                                QuickQuestionButton(text: "如何提升我的事业运？")
                                QuickQuestionButton(text: "紫微斗数是什么？")
                            }
                            .padding(.top, 20)
                        }
                        
                        Spacer()
                    } else {
                        // 聊天记录区域
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(messages) { message in
                                    ChatBubble(message: message)
                                }
                            }
                            .padding()
                        }
                    }
                    
                    // 输入区域
                    HStack(spacing: 12) {
                        TextField("输入你想问的问题...", text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.primary)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(inputText.isEmpty ? .gray : .mysticPink)
                        }
                        .disabled(inputText.isEmpty)
                    }
                    .padding()
                    .background(Color.black.opacity(0.1))
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 添加用户消息
        let userMessage = ChatMessage(
            id: UUID(),
            content: inputText,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // 清空输入框
        let currentInput = inputText
        inputText = ""
        
        // 模拟AI回复（后续会接入真实API）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let aiResponse = ChatMessage(
                id: UUID(),
                content: "感谢你的提问：「\(currentInput)」\n\n这个功能正在开发中，很快就能为你提供专业的紫微斗数解答！✨",
                isFromUser: false,
                timestamp: Date()
            )
            messages.append(aiResponse)
        }
    }
}

// 聊天消息数据模型
struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

// 聊天气泡组件
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.isFromUser ? .white : .crystalWhite)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isFromUser ? 
                                  LinearGradient(colors: [.mysticPink, .cosmicPurple], startPoint: .leading, endPoint: .trailing) :
                                  Color.white.opacity(0.1)
                            )
                    )
                
                Text(timeString(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.moonSilver.opacity(0.6))
            }
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// 快捷问题按钮
struct QuickQuestionButton: View {
    let text: String
    
    var body: some View {
        Button(action: {
            // TODO: 点击后发送这个问题
        }) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.crystalWhite)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(Color.moonSilver.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct ChatTab_Previews: PreviewProvider {
    static var previews: some View {
        ChatTab()
    }
}