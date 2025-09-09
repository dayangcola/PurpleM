//
//  SquareChartRenderer.swift
//  PurpleM
//
//  方形12宫格星盘渲染 - 完整数据展示
//

import SwiftUI

// MARK: - 完整数据模型
struct FullAstrolabe: Codable {
    let success: Bool
    let gender: String
    let solarDate: String
    let lunarDate: String
    let chineseDate: String
    let time: String?
    let timeRange: String?
    let sign: String
    let zodiac: String
    let earthlyBranchOfSoulPalace: String?
    let earthlyBranchOfBodyPalace: String?
    let soul: String?
    let body: String?
    let fiveElementsClass: String
    let palaces: [FullPalace]
}

struct FullPalace: Codable {
    let index: Int
    let name: String
    let isBodyPalace: Bool
    let isSoulPalace: Bool?
    let isOriginalPalace: Bool?
    let heavenlyStem: String
    let earthlyBranch: String
    
    // 星曜
    let majorStars: [SquareStarInfo]?
    let minorStars: [SquareStarInfo]?
    let adjectiveStars: [String]?
    
    // 神煞
    let changsheng12: [String]?
    let boshi12: [String]?
    let jiangqian12: [String]?
    let suiqian12: [String]?
    
    // 运限
    let decadal: DecadalInfo?
    let ages: [Int]?
}

struct SquareStarInfo: Codable {
    let name: String
    let brightness: String?
    let mutagen: String?
}

struct DecadalInfo: Codable {
    let range: [Int]?
    let heavenlyStem: String?
    let earthlyBranch: String?
}

// MARK: - 方形星盘渲染器
struct SquareChartRenderer: View {
    let jsonData: String
    @State private var astrolabe: FullAstrolabe?
    @State private var selectedPalaceIndex: Int? = nil
    @State private var showFullDetails = false
    
    // 12宫格位置映射（方形布局）
    let palacePositions: [(row: Int, col: Int)] = [
        (2, 3), // 0: 巳
        (3, 3), // 1: 午
        (3, 2), // 2: 未
        (3, 1), // 3: 申
        (3, 0), // 4: 酉
        (2, 0), // 5: 戌
        (1, 0), // 6: 亥
        (0, 0), // 7: 子
        (0, 1), // 8: 丑
        (0, 2), // 9: 寅
        (0, 3), // 10: 卯
        (1, 3), // 11: 辰
    ]
    
    var body: some View {
        if let astrolabe = astrolabe {
            ScrollView {
                VStack(spacing: 15) {
                    // 基本信息面板
                    BasicInfoPanel(astrolabe: astrolabe)
                    
                    // 方形12宫格
                    SquareChart(
                        palaces: astrolabe.palaces,
                        positions: palacePositions,
                        selectedIndex: $selectedPalaceIndex
                    )
                    .frame(height: 400)
                    
                    // 选中宫位详情
                    if let index = selectedPalaceIndex,
                       index < astrolabe.palaces.count {
                        PalaceFullDetail(
                            palace: astrolabe.palaces[index],
                            showFull: $showFullDetails
                        )
                    }
                }
                .padding()
            }
        } else {
            Color.clear.onAppear {
                parseJSON()
            }
        }
    }
    
    private func parseJSON() {
        guard let data = jsonData.data(using: .utf8) else { return }
        
        // 尝试自动解码
        do {
            astrolabe = try JSONDecoder().decode(FullAstrolabe.self, from: data)
        } catch {
            // 手动解析
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                parseManually(json: json)
            }
        }
    }
    
    private func parseManually(json: [String: Any]) {
        var palaces: [FullPalace] = []
        
        if let palacesArray = json["palaces"] as? [[String: Any]] {
            for dict in palacesArray {
                palaces.append(parsePalace(dict))
            }
        }
        
        astrolabe = FullAstrolabe(
            success: json["success"] as? Bool ?? true,
            gender: json["gender"] as? String ?? "",
            solarDate: json["solarDate"] as? String ?? "",
            lunarDate: json["lunarDate"] as? String ?? "",
            chineseDate: json["chineseDate"] as? String ?? "",
            time: json["time"] as? String,
            timeRange: json["timeRange"] as? String,
            sign: json["sign"] as? String ?? "",
            zodiac: json["zodiac"] as? String ?? "",
            earthlyBranchOfSoulPalace: json["earthlyBranchOfSoulPalace"] as? String,
            earthlyBranchOfBodyPalace: json["earthlyBranchOfBodyPalace"] as? String,
            soul: json["soul"] as? String,
            body: json["body"] as? String,
            fiveElementsClass: json["fiveElementsClass"] as? String ?? "",
            palaces: palaces
        )
    }
    
    private func parsePalace(_ dict: [String: Any]) -> FullPalace {
        // 解析星曜
        var majorStars: [SquareStarInfo] = []
        if let stars = dict["majorStars"] as? [[String: Any]] {
            majorStars = stars.map { parseStarInfo($0) }
        }
        
        var minorStars: [SquareStarInfo] = []
        if let stars = dict["minorStars"] as? [[String: Any]] {
            minorStars = stars.map { parseStarInfo($0) }
        }
        
        return FullPalace(
            index: dict["index"] as? Int ?? 0,
            name: dict["name"] as? String ?? "",
            isBodyPalace: dict["isBodyPalace"] as? Bool ?? false,
            isSoulPalace: dict["isSoulPalace"] as? Bool,
            isOriginalPalace: dict["isOriginalPalace"] as? Bool,
            heavenlyStem: dict["heavenlyStem"] as? String ?? "",
            earthlyBranch: dict["earthlyBranch"] as? String ?? "",
            majorStars: majorStars.isEmpty ? nil : majorStars,
            minorStars: minorStars.isEmpty ? nil : minorStars,
            adjectiveStars: dict["adjectiveStars"] as? [String],
            changsheng12: dict["changsheng12"] as? [String],
            boshi12: dict["boshi12"] as? [String],
            jiangqian12: dict["jiangqian12"] as? [String],
            suiqian12: dict["suiqian12"] as? [String],
            decadal: nil,
            ages: dict["ages"] as? [Int]
        )
    }
    
    private func parseStarInfo(_ dict: [String: Any]) -> SquareStarInfo {
        SquareStarInfo(
            name: dict["name"] as? String ?? "",
            brightness: dict["brightness"] as? String,
            mutagen: dict["mutagen"] as? String
        )
    }
}

// MARK: - 基本信息面板
struct BasicInfoPanel: View {
    let astrolabe: FullAstrolabe
    
    var body: some View {
        VStack(spacing: 12) {
            // 第一行：日期信息
            HStack(spacing: 15) {
                InfoItem(label: "阳历", value: astrolabe.solarDate, color: .starGold)
                InfoItem(label: "农历", value: astrolabe.lunarDate, color: .mysticPink)
                InfoItem(label: "干支", value: astrolabe.chineseDate, color: .cosmicPurple)
            }
            
            // 第二行：基本信息
            HStack(spacing: 15) {
                InfoItem(label: "性别", value: astrolabe.gender, color: .crystalWhite)
                InfoItem(label: "生肖", value: astrolabe.zodiac, color: .crystalWhite)
                InfoItem(label: "星座", value: astrolabe.sign, color: .crystalWhite)
                InfoItem(label: "五行局", value: astrolabe.fiveElementsClass, color: .starGold)
            }
            
            // 第三行：命身信息（如果有）
            if let soul = astrolabe.soul, let body = astrolabe.body {
                HStack(spacing: 15) {
                    InfoItem(label: "命主", value: soul, color: .starGold)
                    InfoItem(label: "身主", value: body, color: .mysticPink)
                    if let time = astrolabe.time {
                        InfoItem(label: "时辰", value: time, color: .crystalWhite)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - 信息项
struct InfoItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.moonSilver.opacity(0.6))
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 方形星盘
struct SquareChart: View {
    let palaces: [FullPalace]
    let positions: [(row: Int, col: Int)]
    @Binding var selectedIndex: Int?
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(geometry.size.width / 4, geometry.size.height / 4)
            
            ZStack {
                // 背景网格
                ForEach(0..<4) { row in
                    ForEach(0..<4) { col in
                        Rectangle()
                            .stroke(Color.moonSilver.opacity(0.2), lineWidth: 0.5)
                            .frame(width: cellSize, height: cellSize)
                            .position(
                                x: CGFloat(col) * cellSize + cellSize/2,
                                y: CGFloat(row) * cellSize + cellSize/2
                            )
                    }
                }
                
                // 中宫
                VStack(spacing: 4) {
                    Image(systemName: "star.circle")
                        .font(.title)
                        .foregroundColor(.starGold.opacity(0.5))
                    Text("紫微斗数")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(.crystalWhite.opacity(0.7))
                }
                .frame(width: cellSize * 2, height: cellSize * 2)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cosmicPurple.opacity(0.1))
                )
                .position(x: cellSize * 2, y: cellSize * 2)
                
                // 12宫位
                ForEach(0..<min(12, palaces.count), id: \.self) { index in
                    let palace = palaces[index]
                    let position = positions[index]
                    
                    SquarePalaceCell(
                        palace: palace,
                        isSelected: selectedIndex == index
                    )
                    .frame(width: cellSize - 4, height: cellSize - 4)
                    .position(
                        x: CGFloat(position.col) * cellSize + cellSize/2,
                        y: CGFloat(position.row) * cellSize + cellSize/2
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedIndex = selectedIndex == index ? nil : index
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 方形宫位单元格
struct SquarePalaceCell: View {
    let palace: FullPalace
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            // 顶部：宫位名 + 干支
            HStack {
                Text(palace.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(palace.heavenlyStem)\(palace.earthlyBranch)")
                    .font(.system(size: 9))
                    .foregroundColor(.moonSilver.opacity(0.7))
            }
            
            // 命身标记
            if palace.isSoulPalace == true || palace.isBodyPalace {
                HStack(spacing: 4) {
                    if palace.isSoulPalace == true {
                        Text("命")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.starGold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.starGold.opacity(0.2)))
                    }
                    if palace.isBodyPalace {
                        Text("身")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.mysticPink)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.mysticPink.opacity(0.2)))
                    }
                    Spacer()
                }
            }
            
            Spacer()
            
            // 主星显示
            if let majorStars = palace.majorStars, !majorStars.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(majorStars.prefix(2), id: \.name) { star in
                        HStack(spacing: 2) {
                            Text(star.name)
                                .font(.system(size: 10))
                                .foregroundColor(.starGold)
                            if let mutagen = star.mutagen {
                                Text(mutagen)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    if majorStars.count > 2 {
                        Text("+\(majorStars.count - 2)")
                            .font(.system(size: 8))
                            .foregroundColor(.starGold.opacity(0.6))
                    }
                }
            }
            
            // 辅星数量指示
            if let minorStars = palace.minorStars, !minorStars.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "star")
                        .font(.system(size: 7))
                        .foregroundColor(.mysticPink.opacity(0.6))
                    Text("\(minorStars.count)")
                        .font(.system(size: 8))
                        .foregroundColor(.mysticPink.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected ?
                    Color.mysticPink.opacity(0.15) :
                    Color.white.opacity(0.05)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    palace.isSoulPalace == true ? Color.starGold :
                    palace.isBodyPalace ? Color.mysticPink :
                    isSelected ? Color.mysticPink.opacity(0.5) :
                    Color.moonSilver.opacity(0.3),
                    lineWidth: palace.isSoulPalace == true || palace.isBodyPalace ? 2 : 1
                )
        )
    }
}

// MARK: - 宫位完整详情
struct PalaceFullDetail: View {
    let palace: FullPalace
    @Binding var showFull: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // 标题栏
            HStack {
                Text(palace.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.crystalWhite)
                
                Text("(\(palace.heavenlyStem)\(palace.earthlyBranch))")
                    .font(.system(size: 14))
                    .foregroundColor(.moonSilver.opacity(0.7))
                
                Spacer()
                
                Button(action: { showFull.toggle() }) {
                    Image(systemName: showFull ? "chevron.up" : "chevron.down")
                        .foregroundColor(.moonSilver)
                }
            }
            
            // 主星
            if let majorStars = palace.majorStars, !majorStars.isEmpty {
                SquareStarSection(title: "主星", stars: majorStars, color: .starGold)
            }
            
            // 辅星
            if let minorStars = palace.minorStars, !minorStars.isEmpty {
                SquareStarSection(title: "辅星", stars: minorStars, color: .mysticPink)
            }
            
            // 杂曜
            if let adjectiveStars = palace.adjectiveStars, !adjectiveStars.isEmpty {
                SimpleStarSection(title: "杂曜", stars: adjectiveStars, color: .crystalWhite.opacity(0.7))
            }
            
            if showFull {
                // 神煞系统
                if let changsheng12 = palace.changsheng12, !changsheng12.isEmpty {
                    SimpleStarSection(title: "长生十二神", stars: changsheng12, color: .green.opacity(0.7))
                }
                
                if let boshi12 = palace.boshi12, !boshi12.isEmpty {
                    SimpleStarSection(title: "博士十二神", stars: boshi12, color: .blue.opacity(0.7))
                }
                
                if let jiangqian12 = palace.jiangqian12, !jiangqian12.isEmpty {
                    SimpleStarSection(title: "将前十二神", stars: jiangqian12, color: .orange.opacity(0.7))
                }
                
                if let suiqian12 = palace.suiqian12, !suiqian12.isEmpty {
                    SimpleStarSection(title: "岁前十二神", stars: suiqian12, color: .purple.opacity(0.7))
                }
                
                // 运限信息
                if let ages = palace.ages, !ages.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("小限年龄")
                            .font(.caption)
                            .foregroundColor(.moonSilver.opacity(0.6))
                        
                        Text(ages.map { String($0) }.joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundColor(.crystalWhite)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - 星曜区块
struct SquareStarSection: View {
    let title: String
    let stars: [SquareStarInfo]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.moonSilver.opacity(0.6))
            
            SquareFlowLayout(spacing: 8) {
                ForEach(stars, id: \.name) { star in
                    SquareStarChip(star: star, color: color)
                }
            }
        }
    }
}

// MARK: - 简单星曜区块
struct SimpleStarSection: View {
    let title: String
    let stars: [String]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.moonSilver.opacity(0.6))
            
            SquareFlowLayout(spacing: 6) {
                ForEach(stars, id: \.self) { star in
                    Text(star)
                        .font(.system(size: 11))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(color.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                }
            }
        }
    }
}

// MARK: - 星曜标签
struct SquareStarChip: View {
    let star: SquareStarInfo
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(star.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.crystalWhite)
            
            HStack(spacing: 4) {
                if let brightness = star.brightness, !brightness.isEmpty {
                    Text(brightness)
                        .font(.system(size: 9))
                        .foregroundColor(.moonSilver.opacity(0.6))
                }
                
                if let mutagen = star.mutagen, !mutagen.isEmpty {
                    Text(mutagen)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(mutagenColor(mutagen))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func mutagenColor(_ mutagen: String) -> Color {
        switch mutagen {
        case "禄": return .green
        case "权": return .orange
        case "科": return .blue
        case "忌": return .red
        default: return .gray
        }
    }
}

// MARK: - 流式布局
struct SquareFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: frame.minX + bounds.minX, y: frame.minY + bounds.minY), proposal: ProposedViewSize(frame.size))
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)
                
                if currentX + viewSize.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: viewSize))
                
                currentX += viewSize.width + spacing
                lineHeight = max(lineHeight, viewSize.height)
                
                size.width = max(size.width, currentX - spacing)
                size.height = currentY + lineHeight
            }
        }
    }
}