//
//  DecadalAnalysisView.swift
//  PurpleM
//
//  大运分析视图 - 展示十年大运趋势
//  完全依赖iztro库计算，不自己实现算法
//

import SwiftUI

struct DecadalAnalysisView: View {
    @ObservedObject var iztroManager: IztroManager
    @StateObject private var userDataManager = UserDataManager.shared
    @State private var currentAge: Int = 25
    @State private var currentDecadal: DecadalData? = nil
    @State private var isLoading = false
    @State private var allDecadals: [DecadalInfo] = []
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    // 标题栏
                    HStack {
                        Image(systemName: "calendar.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.starGold, .mysticPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("大运分析")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundColor(.crystalWhite)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // 年龄选择器
                    AgeSelector(currentAge: $currentAge, onAgeChange: { age in
                        loadDecadalData(for: age)
                    })
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .starGold))
                            .padding(.top, 50)
                    } else {
                        // 当前大运卡片
                        if let decadal = currentDecadal {
                            CurrentDecadalCard(decadal: decadal, age: currentAge)
                                .padding(.horizontal)
                        }
                        
                        // 大运时间轴
                        DecadalTimeline(allDecadals: allDecadals, currentAge: currentAge)
                            .padding(.horizontal)
                        
                        // 大运详细说明
                        DecadalDetailCard()
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .onAppear {
            calculateUserAge()
            loadAllDecadals()
        }
    }
    
    // 计算用户实际年龄
    private func calculateUserAge() {
        if let user = userDataManager.currentUser {
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: user.birthDate, to: Date())
            currentAge = ageComponents.year ?? 25
        }
    }
    
    // 加载特定年龄的大运数据
    private func loadDecadalData(for age: Int) {
        isLoading = true
        
        iztroManager.getDecadalData(age: age) { data in
            DispatchQueue.main.async {
                self.currentDecadal = data
                self.isLoading = false
            }
        }
    }
    
    // 加载所有大运（用于时间轴展示）
    private func loadAllDecadals() {
        // 遍历获取各个年龄段的大运
        var decadals: [DecadalInfo] = []
        
        // 从1岁到100岁，每10年取一个点
        for age in stride(from: 5, through: 95, by: 10) {
            iztroManager.getDecadalData(age: age) { data in
                if let data = data {
                    let info = DecadalInfo(
                        startAge: data.range[0],
                        endAge: data.range[1],
                        palace: data.palace,
                        stem: data.heavenlyStem,
                        branch: data.earthlyBranch
                    )
                    decadals.append(info)
                }
                
                // 排序并更新
                DispatchQueue.main.async {
                    self.allDecadals = decadals.sorted { $0.startAge < $1.startAge }
                }
            }
        }
        
        // 加载当前年龄的大运
        loadDecadalData(for: currentAge)
    }
}

// MARK: - 年龄选择器
struct AgeSelector: View {
    @Binding var currentAge: Int
    let onAgeChange: (Int) -> Void
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 15) {
                Text("选择年龄查看大运")
                    .font(.system(size: 14))
                    .foregroundColor(.moonSilver)
                
                HStack(spacing: 20) {
                    Button(action: {
                        if currentAge > 1 {
                            currentAge -= 1
                            onAgeChange(currentAge)
                        }
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                            .foregroundColor(.mysticPink.opacity(0.8))
                    }
                    
                    Text("\(currentAge)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.starGold, .mysticPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 80)
                    
                    Text("岁")
                        .font(.system(size: 20))
                        .foregroundColor(.crystalWhite)
                    
                    Button(action: {
                        if currentAge < 100 {
                            currentAge += 1
                            onAgeChange(currentAge)
                        }
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(.mysticPink.opacity(0.8))
                    }
                }
                
                // 快速跳转按钮
                HStack(spacing: 15) {
                    ForEach([20, 30, 40, 50, 60], id: \.self) { age in
                        Button(action: {
                            currentAge = age
                            onAgeChange(age)
                        }) {
                            Text("\(age)")
                                .font(.system(size: 14, weight: currentAge == age ? .bold : .regular))
                                .foregroundColor(currentAge == age ? .starGold : .moonSilver)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(currentAge == age ? Color.starGold.opacity(0.2) : Color.clear)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(currentAge == age ? Color.starGold.opacity(0.5) : Color.moonSilver.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 当前大运卡片
struct CurrentDecadalCard: View {
    let decadal: DecadalData
    let age: Int
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 15) {
                // 标题
                HStack {
                    Image(systemName: "star.circle.fill")
                        .foregroundColor(.starGold)
                    Text("当前大运")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                    Text("\(decadal.range[0])-\(decadal.range[1])岁")
                        .font(.system(size: 14))
                        .foregroundColor(.moonSilver)
                }
                
                // 大运信息
                HStack(spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("宫位")
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver)
                        Text(decadal.palace)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.starGold)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("天干地支")
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver)
                        Text("\(decadal.heavenlyStem)\(decadal.earthlyBranch)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.mysticPink)
                    }
                    
                    Spacer()
                }
                
                // 进度条
                let progress = Float(age - decadal.range[0]) / Float(decadal.range[1] - decadal.range[0] + 1)
                VStack(alignment: .leading, spacing: 5) {
                    Text("大运进度")
                        .font(.system(size: 12))
                        .foregroundColor(.moonSilver)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.starGold, .mysticPink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    Text("已过 \(age - decadal.range[0])年，还剩 \(decadal.range[1] - age)年")
                        .font(.system(size: 11))
                        .foregroundColor(.moonSilver.opacity(0.8))
                }
                
                // 大运特点说明
                Text(getDecadalDescription(palace: decadal.palace))
                    .font(.system(size: 13))
                    .foregroundColor(.crystalWhite.opacity(0.9))
                    .lineSpacing(4)
                    .padding(.top, 5)
            }
        }
    }
    
    private func getDecadalDescription(palace: String) -> String {
        // 根据宫位返回大运特点（这些是传统紫微斗数的解释，不是算法）
        switch palace {
        case "命宫":
            return "命宫大运期间，个人发展机遇多，适合开创新事业，把握人生方向。"
        case "财帛":
            return "财帛宫大运，财运亨通，投资理财机会增多，注意合理规划。"
        case "官禄":
            return "官禄宫大运，事业发展顺利，升职加薪机会多，贵人相助。"
        case "夫妻":
            return "夫妻宫大运，感情生活丰富，单身者易遇良缘，已婚者感情稳定。"
        case "子女":
            return "子女宫大运，创造力旺盛，适合学习新知识，子女缘分深厚。"
        case "疾厄":
            return "疾厄宫大运，需注意身体健康，定期体检，保持良好作息。"
        case "迁移":
            return "迁移宫大运，外出机会多，适合旅行、出差、海外发展。"
        case "交友":
            return "交友宫大运，人际关系活跃，朋友助力大，社交圈扩大。"
        case "田宅":
            return "田宅宫大运，家庭和谐，适合置业投资，家运兴旺。"
        case "福德":
            return "福德宫大运，精神愉悦，生活品质提升，享受人生。"
        case "父母":
            return "父母宫大运，长辈缘分深，得到支持和庇护，学业有成。"
        case "兄弟":
            return "兄弟宫大运，兄弟朋友助力，合作机会多，人脉广泛。"
        default:
            return "此大运期间运势平稳，稳中求进。"
        }
    }
}

// MARK: - 大运时间轴
struct DecadalTimeline: View {
    let allDecadals: [DecadalInfo]
    let currentAge: Int
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "timeline.selection")
                        .foregroundColor(.cosmicPurple)
                    Text("人生大运轨迹")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(allDecadals, id: \.startAge) { decadal in
                            DecadalTimelineItem(
                                decadal: decadal,
                                isCurrent: currentAge >= decadal.startAge && currentAge <= decadal.endAge,
                                isPast: currentAge > decadal.endAge
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 时间轴项目
struct DecadalTimelineItem: View {
    let decadal: DecadalInfo
    let isCurrent: Bool
    let isPast: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // 宫位名
            Text(decadal.palace)
                .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                .foregroundColor(textColor())
            
            // 时间线节点
            ZStack {
                Circle()
                    .fill(backgroundColor())
                    .frame(width: 40, height: 40)
                
                if isCurrent {
                    Circle()
                        .stroke(Color.starGold, lineWidth: 2)
                        .frame(width: 45, height: 45)
                }
                
                Text("\(decadal.stem)\(decadal.branch)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // 年龄范围
            Text("\(decadal.startAge)-\(decadal.endAge)")
                .font(.system(size: 10))
                .foregroundColor(.moonSilver.opacity(0.8))
        }
        .frame(width: 80)
        .padding(.vertical, 10)
        .overlay(
            // 连接线
            Rectangle()
                .fill(isPast ? Color.moonSilver.opacity(0.3) : Color.moonSilver.opacity(0.1))
                .frame(width: 80, height: 1)
                .offset(x: 40)
            , alignment: .trailing
        )
    }
    
    private func textColor() -> Color {
        if isCurrent {
            return .starGold
        } else if isPast {
            return .moonSilver.opacity(0.6)
        } else {
            return .crystalWhite
        }
    }
    
    private func backgroundColor() -> Color {
        if isCurrent {
            return Color.starGold.opacity(0.8)
        } else if isPast {
            return Color.moonSilver.opacity(0.3)
        } else {
            return Color.cosmicPurple.opacity(0.5)
        }
    }
}

// MARK: - 大运详细说明
struct DecadalDetailCard: View {
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "book.circle")
                        .foregroundColor(.cyan)
                    Text("大运说明")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.crystalWhite)
                    Spacer()
                }
                
                Text("大运是紫微斗数中的重要概念，每十年为一个大运，影响该时期的整体运势走向。")
                    .font(.system(size: 13))
                    .foregroundColor(.crystalWhite.opacity(0.9))
                    .lineSpacing(4)
                
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint(text: "大运从出生开始计算，依次经过十二宫位")
                    BulletPoint(text: "每个大运持续十年，主导该时期的吉凶祸福")
                    BulletPoint(text: "大运交接期需特别注意，运势变化明显")
                }
            }
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 14))
                .foregroundColor(.starGold)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.moonSilver.opacity(0.9))
                .lineSpacing(3)
        }
    }
}

// MARK: - 数据模型
struct DecadalInfo {
    let startAge: Int
    let endAge: Int
    let palace: String
    let stem: String
    let branch: String
}

struct DecadalAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        DecadalAnalysisView(iztroManager: IztroManager())
    }
}