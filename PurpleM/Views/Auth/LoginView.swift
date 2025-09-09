import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingResetPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.indigo.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Logo和标题
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.linearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        
                        Text("紫微星语")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("探索命运的奥秘")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                    
                    // 输入表单
                    VStack(spacing: 20) {
                        // 邮箱输入
                        VStack(alignment: .leading, spacing: 8) {
                            Label("邮箱", systemImage: "envelope")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("请输入邮箱", text: $email)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        
                        // 密码输入
                        VStack(alignment: .leading, spacing: 8) {
                            Label("密码", systemImage: "lock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            SecureField("请输入密码", text: $password)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // 忘记密码
                        HStack {
                            Spacer()
                            Button("忘记密码？") {
                                showingResetPassword = true
                            }
                            .font(.caption)
                            .foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 错误信息
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // 登录按钮
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("登录")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    
                    // 分隔线
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("或")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)
                    
                    // 注册按钮
                    Button(action: { showingSignUp = true }) {
                        HStack {
                            Text("还没有账号？")
                                .foregroundColor(.secondary)
                            Text("立即注册")
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                        .font(.callout)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showingResetPassword) {
                ResetPasswordView()
            }
        }
        .onChange(of: authManager.authState) { _, newState in
            switch newState {
            case .error(let message):
                errorMessage = message
                isLoading = false
            case .loading:
                isLoading = true
            case .authenticated:
                isLoading = false
                // Navigation will be handled by parent view
            case .unauthenticated:
                isLoading = false
            }
        }
    }
    
    private func signIn() {
        errorMessage = ""
        Task {
            await authManager.signIn(email: email, password: password)
        }
    }
}