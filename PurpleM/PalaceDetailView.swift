//
//  PalaceDetailView.swift
//  PurpleM
//
//  宫位详情弹窗视图
//

import SwiftUI

struct PalaceDetailView: View {
    let palace: FullPalace
    @Binding var isPresented: Bool
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            
            // 详情卡片
            VStack(spacing: 0) {
                // 顶部标题栏
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(palace.name)
                            .font(.system(size: 24, weight: .medium, design: .serif))
                            .foregroundColor(.crystalWhite)
                        
                        HStack(spacing: 8) {
                            Text("\(palace.heavenlyStem)\(palace.earthlyBranch)")
                                .font(.system(size: 14))
                                .foregroundColor(.starGold)
                            
                            if palace.isSoulPalace == true {
                                Label("命宫", systemImage: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.starGold)
                            }
                            
                            if palace.isBodyPalace {
                                Label("身宫", systemImage: "person.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.mysticPink)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.moonSilver.opacity(0.6))
                    }
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [.cosmicPurple.opacity(0.3), .mysticPink.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // 选项卡
                HStack(spacing: 0) {
                    TabButton(title: "星耀", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "解读", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabButton(title: "大运", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                .background(Color.black.opacity(0.2))
                
                // 内容区域
                ScrollView {
                    VStack(spacing: 15) {
                        if selectedTab == 0 {
                            StarsDetailView(palace: palace)
                        } else if selectedTab == 1 {
                            InterpretationView(palace: palace)
                        } else {
                            DecadalView(palace: palace)
                        }
                    }
                    .padding(20)
                }
                .frame(maxHeight: 400)
            }
            .frame(maxWidth: UIScreen.main.bounds.width - 40)
            .background(
                ZStack {
                    Color.nightBlue
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                }
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.starGold.opacity(0.3), .mysticPink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
}

// 选项卡按钮
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .crystalWhite : .moonSilver.opacity(0.7))
                
                Rectangle()
                    .fill(isSelected ? Color.starGold : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}

// 星耀详情视图
struct StarsDetailView: View {
    let palace: FullPalace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 主星
            if let majorStars = palace.majorStars, !majorStars.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("主星", systemImage: "star.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.starGold)
                    
                    ForEach(majorStars.indices, id: \.self) { index in
                        StarDetailRow(star: majorStars[index])
                    }
                }
            }
            
            // 辅星
            if let minorStars = palace.minorStars, !minorStars.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("辅星", systemImage: "star")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cyan)
                    
                    ForEach(minorStars.indices, id: \.self) { index in
                        StarDetailRow(star: minorStars[index])
                    }
                }
            }
            
            // 杂曜
            if let adjectiveStars = palace.adjectiveStars, !adjectiveStars.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("杂曜", systemImage: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    FlowLayout(items: adjectiveStars) { star in
                        Text(star)
                            .font(.system(size: 12))
                            .foregroundColor(.moonSilver)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
            }
        }
    }
}

// 星耀详情行
struct StarDetailRow: View {
    let star: SquareStarInfo
    
    var body: some View {
        HStack {
            Text(star.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.crystalWhite)
            
            if let brightness = star.brightness, !brightness.isEmpty {
                Text(brightness)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            
            if let mutagen = star.mutagen, !mutagen.isEmpty {
                Text(mutagen)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(getMutagenColor(mutagen))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .stroke(getMutagenColor(mutagen).opacity(0.5), lineWidth: 1)
                    )
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func getMutagenColor(_ mutagen: String) -> Color {
        switch mutagen {
        case "禄": return .green
        case "权": return .orange
        case "科": return .blue
        case "忌": return .red
        default: return .gray
        }
    }
}

// 解读视图
struct InterpretationView: View {
    let palace: FullPalace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // 宫位基本含义
            VStack(alignment: .leading, spacing: 10) {
                Label("宫位含义", systemImage: "book.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.starGold)
                
                Text(getPalaceDescription(palace.name))
                    .font(.system(size: 14))
                    .foregroundColor(.crystalWhite.opacity(0.9))
                    .lineSpacing(4)
            }
            
            // 星耀组合解读
            if let majorStars = palace.majorStars, !majorStars.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("星耀特征", systemImage: "star.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.mysticPink)
                    
                    Text(getStarCombinationInterpretation(majorStars))
                        .font(.system(size: 14))
                        .foregroundColor(.crystalWhite.opacity(0.9))
                        .lineSpacing(4)
                }
            }
        }
    }
    
    private func getPalaceDescription(_ name: String) -> String {
        switch name {
        case "命宫":
            return "代表个人的性格、天赋、命运走向。是整个命盘的核心，影响一生的基本格局。"
        case "兄弟":
            return "代表兄弟姐妹、朋友、同事等平辈关系，也显示合作运势。"
        case "夫妻":
            return "代表婚姻感情、配偶状况、感情模式，是姻缘运势的重要指标。"
        case "子女":
            return "代表子女缘分、创造力、下属关系，也显示投资和创业运。"
        case "财帛":
            return "代表财富状况、赚钱能力、理财观念，是财运的主要宫位。"
        case "疾厄":
            return "代表健康状况、体质特征、潜在疾病，需要特别关注的健康领域。"
        case "迁移":
            return "代表外出运势、环境适应力、贵人运，显示在外发展的机遇。"
        case "交友":
            return "代表朋友圈、社交能力、人际关系，影响人脉资源。"
        case "官禄":
            return "代表事业发展、工作状态、社会地位，是事业运势的核心。"
        case "田宅":
            return "代表不动产、家庭环境、祖业继承，显示居住和财产状况。"
        case "福德":
            return "代表精神享受、兴趣爱好、晚年生活，影响生活品质和幸福感。"
        case "父母":
            return "代表父母缘分、长辈关系、文书运，也显示学业和考试运。"
        default:
            return "此宫位影响生活的特定领域，需要结合星耀详细分析。"
        }
    }
    
    private func getStarCombinationInterpretation(_ stars: [SquareStarInfo]) -> String {
        let starNames = stars.map { $0.name }.joined(separator: "、")
        
        // 这里可以根据不同的星耀组合给出更详细的解读
        if stars.contains(where: { $0.name == "紫微" }) {
            return "紫微星坐守，具有领导才能和贵气，适合管理和领导工作。"
        } else if stars.contains(where: { $0.name == "天府" }) {
            return "天府星坐守，财运稳定，为人稳重，适合经商和理财。"
        } else if stars.contains(where: { $0.name == "太阳" }) {
            return "太阳星坐守，性格开朗热情，贵人运佳，适合公职和服务业。"
        } else if stars.contains(where: { $0.name == "太阴" }) {
            return "太阴星坐守，心思细腻，想象力丰富，适合文艺和创意工作。"
        } else {
            return "此宫位星耀组合（\(starNames)）需要综合分析才能得出准确解读。"
        }
    }
}

// 大运视图
struct DecadalView: View {
    let palace: FullPalace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("大运信息", systemImage: "calendar.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.starGold)
            
            if let ages = palace.ages, !ages.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("起运年龄")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.crystalWhite)
                    
                    HStack {
                        ForEach(ages.prefix(5), id: \.self) { age in
                            Text("\(age)岁")
                                .font(.system(size: 12))
                                .foregroundColor(.moonSilver)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                    }
                }
            }
            
            Text("大运分析功能即将推出，敬请期待...")
                .font(.system(size: 13))
                .foregroundColor(.moonSilver.opacity(0.7))
                .italic()
        }
    }
}

// 流式布局
struct FlowLayout<Item, ItemView: View>: View {
    let items: [Item]
    let itemView: (Item) -> ItemView
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                itemView(item)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        if index == items.count - 1 {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if index == items.count - 1 {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .frame(height: height * -1)
    }
}