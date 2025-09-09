//
//  ModernZiWeiView.swift
//  PurpleM
//
//  现代化紫微斗数界面 - 星语时光主题
//

import SwiftUI

// MARK: - 颜色主题
extension Color {
    static let cosmicPurple = Color(red: 0.4, green: 0.2, blue: 0.6)
    static let mysticPink = Color(red: 0.9, green: 0.5, blue: 0.7)
    static let starGold = Color(red: 1.0, green: 0.85, blue: 0.4)
    static let nightBlue = Color(red: 0.1, green: 0.1, blue: 0.3)
    static let moonSilver = Color(red: 0.85, green: 0.85, blue: 0.95)
    static let crystalWhite = Color.white.opacity(0.9)
}

// MARK: - 星空粒子效果
struct StarParticle: View {
    @State private var opacity: Double = 0
    @State private var scale: Double = 0
    let delay: Double
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 3)
                        .delay(delay)
                        .repeatForever(autoreverses: true)
                ) {
                    opacity = Double.random(in: 0.3...1.0)
                    scale = Double.random(in: 0.8...1.2)
                }
            }
    }
}

// MARK: - 动画背景
struct AnimatedBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.nightBlue,
                    Color.cosmicPurple,
                    Color.mysticPink.opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 流动的光效
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.mysticPink.opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 200
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: animate ? 100 : -100, y: animate ? -50 : 50)
                .blur(radius: 20)
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 8)
                            .repeatForever(autoreverses: true)
                    ) {
                        animate = true
                    }
                }
            
            // 星星粒子
            ForEach(0..<20, id: \.self) { i in
                StarParticle(
                    delay: Double(i) * 0.2,
                    size: CGFloat.random(in: 2...5)
                )
                .position(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 玻璃拟态卡片
struct GlassmorphicCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                ZStack {
                    Color.white.opacity(0.1)
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 10)
    }
}

// MARK: - 视觉效果
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - 主视图
struct ModernZiWeiView: View {
    @StateObject private var iztroManager = IztroManager()
    @State private var showInputView = false
    @State private var animateTitle = false
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            if !showInputView {
                // 欢迎页面
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
            } else {
                ModernInputView(iztroManager: iztroManager)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 现代化输入界面
struct ModernInputView: View {
    @ObservedObject var iztroManager: IztroManager
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var selectedGender = "女"
    @State private var isLunarDate = false
    @State private var showingChart = false
    @State private var animateForm = false
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            ScrollView {
                VStack(spacing: 25) {
                    // 标题
                    HStack {
                        Image(systemName: "moon.stars")
                            .font(.title)
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.starGold, Color.mysticPink]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("星盘信息")
                            .font(.system(size: 28, weight: .light, design: .serif))
                            .foregroundColor(.crystalWhite)
                    }
                    .padding(.top, 50)
                    
                    // 性别选择
                    GlassmorphicCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("性别", systemImage: "person.2")
                                .font(.headline)
                                .foregroundColor(.moonSilver)
                            
                            HStack(spacing: 20) {
                                ForEach(["女", "男"], id: \.self) { gender in
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            selectedGender = gender
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: gender == "女" ? "moon.fill" : "sun.max.fill")
                                            Text(gender)
                                        }
                                        .foregroundColor(selectedGender == gender ? .white : .moonSilver.opacity(0.6))
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 12)
                                        .background(
                                            Capsule()
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
                                                    Capsule()
                                                        .stroke(Color.moonSilver.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .scaleEffect(animateForm ? 1 : 0.9)
                    .opacity(animateForm ? 1 : 0)
                    .animation(.spring().delay(0.1), value: animateForm)
                    
                    // 日期选择
                    GlassmorphicCard {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Label("出生日期", systemImage: "calendar")
                                    .font(.headline)
                                    .foregroundColor(.moonSilver)
                                
                                Spacer()
                                
                                Toggle("", isOn: $isLunarDate)
                                    .labelsHidden()
                                    .toggleStyle(CustomToggleStyle())
                                
                                Text(isLunarDate ? "农历" : "阳历")
                                    .font(.caption)
                                    .foregroundColor(.moonSilver.opacity(0.8))
                            }
                            
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
                    .animation(.spring().delay(0.2), value: animateForm)
                    
                    // 时间选择
                    GlassmorphicCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("出生时间", systemImage: "clock")
                                .font(.headline)
                                .foregroundColor(.moonSilver)
                            
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
                    .animation(.spring().delay(0.3), value: animateForm)
                    
                    // 生成按钮
                    Button(action: generateChart) {
                        ZStack {
                            // 背景光晕
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.starGold.opacity(0.3),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 30,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .blur(radius: 10)
                            
                            VStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 32))
                                Text("生成星盘")
                                    .font(.system(size: 18, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(width: 120, height: 120)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.cosmicPurple, Color.mysticPink]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.starGold, Color.crystalWhite]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: Color.mysticPink.opacity(0.5), radius: 15, x: 0, y: 5)
                        }
                    }
                    .scaleEffect(animateForm ? 1 : 0.9)
                    .opacity(animateForm ? 1 : 0)
                    .animation(.spring().delay(0.4), value: animateForm)
                    .padding(.vertical, 20)
                }
                .padding(.horizontal)
                .padding(.bottom, 50)
            }
            .onAppear {
                animateForm = true
            }
            .sheet(isPresented: $showingChart) {
                ModernChartView(iztroManager: iztroManager)
            }
        }
    }
    
    private func generateChart() {
        // 获取日期组件
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        let day = calendar.component(.day, from: selectedDate)
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)
        
        // 调用IztroManager的calculate方法
        iztroManager.calculate(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            gender: selectedGender,
            isLunar: isLunarDate
        )
        
        showingChart = true
    }
}

// MARK: - 自定义Toggle样式
struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? Color.mysticPink.opacity(0.5) : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 30)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .offset(x: configuration.isOn ? 10 : -10)
                    .animation(.spring(), value: configuration.isOn)
            }
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}

// MARK: - 现代化星盘视图
struct ModernChartView: View {
    @ObservedObject var iztroManager: IztroManager
    @State private var selectedPalaceIndex: Int? = nil
    @State private var rotationDegree: Double = 0
    @State private var showDetails = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            ScrollView {
                VStack(spacing: 30) {
                    // 顶部信息栏
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.moonSilver.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Text("星盘解析")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundColor(.crystalWhite)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                showDetails.toggle()
                            }
                        }) {
                            Image(systemName: showDetails ? "info.circle.fill" : "info.circle")
                                .font(.title2)
                                .foregroundColor(.moonSilver.opacity(0.8))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // 基本信息卡片
                    if showDetails && !iztroManager.resultData.isEmpty {
                        ModernInfoCard(resultData: iztroManager.resultData)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                    }
                    
                    // 星盘展示 - 根据是否有结果数据
                    if !iztroManager.resultData.isEmpty {
                        // 使用PerfectChartRenderer渲染完美版星盘
                        PerfectChartRenderer(jsonData: iztroManager.resultData)
                            .frame(maxHeight: .infinity)
                    } else if iztroManager.isCalculating {
                        // 加载中提示
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .starGold))
                                .scaleEffect(1.5)
                            
                            Text("正在生成星盘...")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.moonSilver)
                        }
                        .frame(height: 400)
                    } else {
                        // 等待开始计算
                        VStack(spacing: 20) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundColor(.starGold.opacity(0.5))
                            
                            Text("等待生成星盘")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.moonSilver.opacity(0.5))
                        }
                        .frame(height: 400)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            rotationDegree = 360
        }
    }
}

// MARK: - 现代化信息卡片
struct ModernInfoCard: View {
    let resultData: String
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 20) {
                // 尝试解析JSON数据
                if let data = resultData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // 显示基本信息
                    if let solarDate = json["solarDate"] as? String,
                       let lunarDate = json["lunarDate"] as? String {
                        
                        HStack(spacing: 30) {
                            InfoPill(
                                icon: "calendar.badge.clock",
                                title: "农历",
                                value: lunarDate,
                                color: .starGold
                            )
                            
                            InfoPill(
                                icon: "sun.max",
                                title: "阳历",
                                value: solarDate,
                                color: .mysticPink
                            )
                        }
                    }
                    
                    // 四柱信息
                    if let chineseDate = json["chineseDate"] as? String {
                        HStack {
                            Image(systemName: "textformat.alt")
                                .foregroundColor(.starGold)
                            Text(chineseDate)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.crystalWhite)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                } else {
                    // 如果解析失败，显示原始数据的一部分
                    Text("星盘数据已生成")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.crystalWhite)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - 信息胶囊
struct InfoPill: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.moonSilver.opacity(0.6))
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.crystalWhite)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 预览
struct ModernZiWeiView_Previews: PreviewProvider {
    static var previews: some View {
        ModernZiWeiView()
    }
}