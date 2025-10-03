//
//  LoadingIndicator.swift
//  PurpleM
//
//  优雅的加载状态指示器
//

import SwiftUI

// MARK: - 加载状态枚举
enum LoadingState {
    case idle
    case loading(message: String = "加载中...")
    case success(message: String = "加载成功")
    case error(message: String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - 骨架屏组件
struct SkeletonView: View {
    @State private var shimmer = false
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.1),
                        Color.gray.opacity(0.3)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmer ? geometry.size.width : -geometry.size.width)
                        .animation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: shimmer
                        )
                }
            )
            .onAppear {
                shimmer = true
            }
    }
}

// MARK: - 优雅的圆形进度指示器
struct CircularProgressView: View {
    @State private var rotation: Double = 0
    let lineWidth: CGFloat
    let size: CGFloat
    
    init(size: CGFloat = 40, lineWidth: CGFloat = 3) {
        self.size = size
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.2),
                        Color.purple
                    ]),
                    center: .center
                ),
                lineWidth: lineWidth
            )
            .frame(width: size, height: size)
            .rotationEffect(Angle(degrees: rotation))
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
    }
}

// MARK: - 紫薇星动画加载器
struct PurpleStarLoader: View {
    @State private var animating = false
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // 外圈星星
            ForEach(0..<8) { index in
                Image(systemName: "star.fill")
                    .foregroundColor(.purple)
                    .scaleEffect(animating ? 0.5 : 1.0)
                    .opacity(animating ? 0.3 : 1.0)
                    .offset(
                        x: cos(CGFloat(index) * .pi / 4) * 30,
                        y: sin(CGFloat(index) * .pi / 4) * 30
                    )
                    .rotationEffect(Angle(degrees: animating ? 360 : 0))
                    .animation(
                        Animation.easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animating
                    )
            }
            
            // 中心紫薇星
            Image(systemName: "star.fill")
                .font(.system(size: 30))
                .foregroundColor(.purple)
                .scaleEffect(scale)
                .animation(
                    Animation.easeInOut(duration: 1)
                        .repeatForever(autoreverses: true),
                    value: scale
                )
        }
        .onAppear {
            animating = true
            scale = 1.3
        }
    }
}

// MARK: - 全屏加载视图
struct FullScreenLoadingView: View {
    let message: String
    let showProgress: Bool
    @State private var progress: Double = 0
    
    init(message: String = "正在加载...", showProgress: Bool = false) {
        self.message = message
        self.showProgress = showProgress
    }
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // 加载内容
            VStack(spacing: 20) {
                PurpleStarLoader()
                    .frame(width: 80, height: 80)
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if showProgress {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                        .frame(width: 200)
                        .onAppear {
                            simulateProgress()
                        }
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(radius: 10)
            )
        }
    }
    
    private func simulateProgress() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if progress < 0.9 {
                progress += 0.05
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - 内联加载指示器
struct InlineLoadingView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            CircularProgressView(size: 20, lineWidth: 2)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - 卡片骨架屏
struct CardSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            SkeletonView()
                .frame(height: 20)
                .frame(maxWidth: 150)
            
            // 内容行
            ForEach(0..<3) { _ in
                SkeletonView()
                    .frame(height: 14)
            }
            
            // 按钮
            HStack {
                Spacer()
                SkeletonView(cornerRadius: 15)
                    .frame(width: 80, height: 30)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 2)
        )
    }
}

// MARK: - 列表骨架屏
struct ListSkeletonView: View {
    let itemCount: Int
    
    init(itemCount: Int = 5) {
        self.itemCount = itemCount
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<itemCount, id: \.self) { _ in
                HStack(spacing: 12) {
                    // 头像
                    SkeletonView(cornerRadius: 25)
                        .frame(width: 50, height: 50)
                    
                    // 内容
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonView()
                            .frame(height: 16)
                            .frame(maxWidth: 120)
                        
                        SkeletonView()
                            .frame(height: 12)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
        }
    }
}

// MARK: - 下拉刷新指示器
struct PullToRefreshView: View {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    
    @State private var pullProgress: CGFloat = 0
    @State private var refreshThreshold: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if pullProgress > 0 || isRefreshing {
                    HStack {
                        Spacer()
                        
                        if isRefreshing {
                            CircularProgressView(size: 25, lineWidth: 2)
                        } else {
                            Image(systemName: "arrow.down")
                                .rotationEffect(
                                    Angle(degrees: pullProgress >= refreshThreshold ? 180 : 0)
                                )
                                .animation(.easeInOut(duration: 0.2), value: pullProgress)
                        }
                        
                        Spacer()
                    }
                    .frame(height: max(0, pullProgress))
                    .opacity(Double(pullProgress / refreshThreshold))
                }
            }
        }
    }
}

// MARK: - 状态管理视图修饰器
struct LoadingModifier: ViewModifier {
    @Binding var loadingState: LoadingState
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(loadingState.isLoading)
                .blur(radius: loadingState.isLoading ? 2 : 0)
            
            if loadingState.isLoading {
                FullScreenLoadingView(
                    message: {
                        if case .loading(let message) = loadingState {
                            return message
                        }
                        return "加载中..."
                    }()
                )
            }
        }
    }
}

// MARK: - View扩展
extension View {
    func withLoadingState(_ state: Binding<LoadingState>) -> some View {
        modifier(LoadingModifier(loadingState: state))
    }
}

// MARK: - 预览
struct LoadingIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            CircularProgressView()
            PurpleStarLoader()
            InlineLoadingView(message: "正在分析命盘...")
            CardSkeletonView()
        }
        .padding()
    }
}