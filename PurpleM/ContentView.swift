import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                // 加载状态
                ZStack {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.1), Color.indigo.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.linearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.purple)
                        
                        Text("加载中...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
            case .authenticated:
                // 已登录，显示主界面
                TabBarView()
                    .environmentObject(authManager)
                
            case .unauthenticated, .error:
                // 未登录或错误，显示登录界面
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .animation(.easeInOut, value: authManager.authState)
    }
}