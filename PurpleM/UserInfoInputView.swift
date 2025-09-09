//
//  UserInfoInputView.swift
//  PurpleM
//
//  用户信息输入视图 - 精简版
//

import SwiftUI

struct UserInfoInputView: View {
    @ObservedObject var iztroManager: IztroManager
    @StateObject private var userDataManager = UserDataManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var userName = ""
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var selectedGender = "女"
    @State private var isLunarDate = false
    @State private var birthLocation = ""
    @State private var animateForm = false
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            ScrollView {
                VStack(spacing: 25) {
                    // 标题
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.moonSilver.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Text("个人信息")
                            .font(.system(size: 28, weight: .light, design: .serif))
                            .foregroundColor(.crystalWhite)
                        
                        Spacer()
                        
                        // 占位，保持标题居中
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.clear)
                    }
                    .padding(.top, 20)
                    
                    // 姓名输入
                    GlassmorphicCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("姓名", systemImage: "person.circle")
                                .font(.headline)
                                .foregroundColor(.crystalWhite)
                            
                            TextField("请输入您的姓名", text: $userName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                    }
                    .scaleEffect(animateForm ? 1 : 0.9)
                    .opacity(animateForm ? 1 : 0)
                    .animation(.spring().delay(0.05), value: animateForm)
                    
                    // 性别选择
                    GlassmorphicCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("性别", systemImage: "person.2")
                                .font(.headline)
                                .foregroundColor(.crystalWhite)
                            
                            HStack(spacing: 20) {
                                ForEach(["女", "男"], id: \.self) { gender in
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            selectedGender = gender
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: gender == "女" ? "person.fill.turn.left" : "person.fill.turn.right")
                                                .font(.system(size: 24))
                                            Text(gender == "女" ? "女性" : "男性")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(selectedGender == gender ? .white : .moonSilver.opacity(0.6))
                                        .frame(width: 80, height: 80)
                                        .background(
                                            RoundedRectangle(cornerRadius: 15)
                                                .fill(selectedGender == gender ?
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            gender == "女" ? Color.mysticPink : Color.cosmicPurple,
                                                            gender == "女" ? Color.mysticPink.opacity(0.6) : Color.cosmicPurple.opacity(0.6)
                                                        ]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ) :
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [Color.clear, Color.clear]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 15)
                                                        .stroke(selectedGender == gender ? 
                                                            Color.clear : 
                                                            Color.moonSilver.opacity(0.3), 
                                                            lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    .scaleEffect(animateForm ? 1 : 0.9)
                    .opacity(animateForm ? 1 : 0)
                    .animation(.spring().delay(0.1), value: animateForm)
                    
                    // 日期选择
                    GlassmorphicCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("出生日期", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.crystalWhite)
                            
                            // 历法切换
                            HStack(spacing: 0) {
                                ForEach([false, true], id: \.self) { isLunar in
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            isLunarDate = isLunar
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: isLunar ? "moon.circle" : "sun.max.circle")
                                                .font(.system(size: 16))
                                            Text(isLunar ? "农历" : "公历")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(isLunarDate == isLunar ? .white : .moonSilver.opacity(0.6))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            isLunarDate == isLunar ?
                                            AnyView(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.starGold, Color.mysticPink]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            ) :
                                            AnyView(Color.clear)
                                        )
                                    }
                                }
                            }
                            .background(Color.cosmicPurple.opacity(0.2))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.moonSilver.opacity(0.3), lineWidth: 1)
                            )
                            
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .accentColor(.mysticPink)
                            .colorScheme(.dark)
                        }
                    }
                    .scaleEffect(animateForm ? 1 : 0.9)
                    .opacity(animateForm ? 1 : 0)
                    .animation(.spring().delay(0.15), value: animateForm)
                    
                    // 时间选择
                    GlassmorphicCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("出生时间", systemImage: "clock")
                                .font(.headline)
                                .foregroundColor(.crystalWhite)
                            
                            DatePicker(
                                "",
                                selection: $selectedTime,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(WheelDatePickerStyle())
                            .frame(height: 120)
                            .colorScheme(.dark)
                        }
                    }
                    .scaleEffect(animateForm ? 1 : 0.9)
                    .opacity(animateForm ? 1 : 0)
                    .animation(.spring().delay(0.2), value: animateForm)
                    
                    // 出生地（可选）
                    GlassmorphicCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("出生地点（可选）", systemImage: "location.circle")
                                .font(.headline)
                                .foregroundColor(.crystalWhite)
                            
                            TextField("例如：北京市", text: $birthLocation)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                    }
                    .scaleEffect(animateForm ? 1 : 0.9)
                    .opacity(animateForm ? 1 : 0)
                    .animation(.spring().delay(0.25), value: animateForm)
                    
                    // 保存按钮
                    Button(action: saveUserInfo) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("保存并生成星盘")
                        }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.cosmicPurple, Color.mysticPink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                        .shadow(color: Color.mysticPink.opacity(0.5), radius: 10, x: 0, y: 5)
                    }
                    .disabled(userName.isEmpty)
                    .opacity(userName.isEmpty ? 0.5 : 1)
                    .scaleEffect(animateForm ? 1 : 0.9)
                    .opacity(animateForm ? 1 : 0)
                    .animation(.spring().delay(0.3), value: animateForm)
                    .padding(.vertical, 20)
                }
                .padding(.horizontal)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            animateForm = true
            // 如果是编辑模式，加载现有数据
            if let user = userDataManager.currentUser {
                userName = user.name
                selectedGender = user.gender
                selectedDate = user.birthDate
                selectedTime = user.birthTime
                isLunarDate = user.isLunarDate
                birthLocation = user.birthLocation ?? ""
            }
        }
    }
    
    private func saveUserInfo() {
        let userInfo = UserInfo(
            name: userName,
            gender: selectedGender,
            birthDate: selectedDate,
            birthTime: selectedTime,
            birthLocation: birthLocation.isEmpty ? nil : birthLocation,
            isLunarDate: isLunarDate
        )
        
        userDataManager.updateUserInfo(userInfo)
        presentationMode.wrappedValue.dismiss()
        onComplete()
    }
}

// 自定义文本输入框样式
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .foregroundColor(.crystalWhite)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.moonSilver.opacity(0.3), lineWidth: 1)
            )
    }
}