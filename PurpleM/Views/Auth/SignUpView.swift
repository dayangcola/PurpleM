import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = AuthManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingSuccessAlert = false
    @State private var isAutoLoggingIn = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color.indigo.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // 标题
                        VStack(spacing: 12) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 60))
                                .foregroundStyle(.linearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                            
                            Text("创建账号")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("开启你的命理之旅")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 30)
                        
                        // 输入表单
                        VStack(spacing: 20) {
                            // 用户名
                            VStack(alignment: .leading, spacing: 8) {
                                Label("用户名", systemImage: "person")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("请输入用户名", text: $username)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            
                            // 邮箱
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
                            
                            // 密码
                            VStack(alignment: .leading, spacing: 8) {
                                Label("密码", systemImage: "lock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("请输入密码（至少6位）", text: $password)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // 确认密码
                            VStack(alignment: .leading, spacing: 8) {
                                Label("确认密码", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("请再次输入密码", text: $confirmPassword)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // 密码匹配提示
                            if !password.isEmpty && !confirmPassword.isEmpty {
                                HStack {
                                    Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(password == confirmPassword ? .green : .red)
                                    Text(password == confirmPassword ? "密码匹配" : "密码不匹配")
                                        .font(.caption)
                                        .foregroundColor(password == confirmPassword ? .green : .red)
                                    Spacer()
                                }
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
                        
                        // 注册按钮
                        Button(action: signUp) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else if isAutoLoggingIn {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("注册成功，正在登录...")
                                    }
                                    .fontWeight(.semibold)
                                } else {
                                    Text("注册")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(!canSignUp)
                        
                        // 服务条款
                        VStack(spacing: 8) {
                            Text("注册即表示您同意我们的")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Button("服务条款") {
                                    // TODO: Show terms
                                }
                                .font(.caption)
                                .foregroundColor(.purple)
                                
                                Text("和")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("隐私政策") {
                                    // TODO: Show privacy policy
                                }
                                .font(.caption)
                                .foregroundColor(.purple)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("注册成功", isPresented: $showingSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("账号创建成功，正在自动登录...")
            }
        }
        .onChange(of: authManager.authState) { _, newState in
            switch newState {
            case .authenticated:
                // 注册成功并自动登录，显示欢迎信息
                isAutoLoggingIn = true
                isLoading = false
                
                // 延迟一下让用户看到成功状态
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    await MainActor.run {
                        dismiss()
                    }
                }
            case .error(let message):
                errorMessage = message
                isLoading = false
                isAutoLoggingIn = false
            case .loading:
                isLoading = true
            case .unauthenticated:
                isLoading = false
                isAutoLoggingIn = false
            }
        }
    }
    
    private var canSignUp: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !username.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        !isLoading
    }
    
    private func signUp() {
        errorMessage = ""
        
        // Validate email format
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            errorMessage = "请输入有效的邮箱地址"
            return
        }
        
        Task {
            await authManager.signUp(email: email, password: password, username: username)
        }
    }
}