//
//  EnhancedChartRenderer.swift
//  PurpleM
//
//  增强版传统星盘 - 完整信息显示
//

import SwiftUI

// MARK: - 增强版星盘渲染器
struct EnhancedChartRenderer: View {
    let jsonData: String
    @State private var astrolabe: FullAstrolabe?
    @State private var selectedPalaceIndex: Int? = nil
    
    // 12宫格位置映射（传统方形布局）
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
        ZStack {
            // 星语时光主题背景
            AnimatedBackground()
            
            if let astrolabe = astrolabe {
                ScrollView {
                    VStack(spacing: 15) {
                        // 基本信息面板
                        EnhancedInfoPanel(astrolabe: astrolabe)
                            .padding(.horizontal)
                        
                        // 增强版方形12宫格 - 使用更大的尺寸
                        EnhancedSquareChart(
                            palaces: astrolabe.palaces,
                            positions: palacePositions,
                            selectedIndex: $selectedPalaceIndex
                        )
                        .frame(height: UIScreen.main.bounds.height * 0.8) // 使用屏幕高度的80%
                        .padding(.horizontal, 5)
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .starGold))
                    .onAppear {
                        parseJSON()
                    }
            }
        }
    }
    
    private func parseJSON() {
        guard let data = jsonData.data(using: .utf8) else { return }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            parseManually(json: json)
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
        // 解析主星
        var majorStars: [SquareStarInfo] = []
        if let stars = dict["majorStars"] as? [[String: Any]] {
            majorStars = stars.map { parseStarInfo($0) }
        }
        
        // 解析辅星
        var minorStars: [SquareStarInfo] = []
        if let stars = dict["minorStars"] as? [[String: Any]] {
            minorStars = stars.map { parseStarInfo($0) }
        }
        
        // 解析杂曜
        let adjectiveStars = dict["adjectiveStars"] as? [String] ?? []
        
        // 解析神煞
        let changsheng12 = dict["changsheng12"] as? [String] ?? []
        let boshi12 = dict["boshi12"] as? [String] ?? []
        let jiangqian12 = dict["jiangqian12"] as? [String] ?? []
        let suiqian12 = dict["suiqian12"] as? [String] ?? []
        
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
            adjectiveStars: adjectiveStars.isEmpty ? nil : adjectiveStars,
            changsheng12: changsheng12.isEmpty ? nil : changsheng12,
            boshi12: boshi12.isEmpty ? nil : boshi12,
            jiangqian12: jiangqian12.isEmpty ? nil : jiangqian12,
            suiqian12: suiqian12.isEmpty ? nil : suiqian12,
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

// MARK: - 增强版信息面板
struct EnhancedInfoPanel: View {
    let astrolabe: FullAstrolabe
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 15) {
                InfoPill(
                    icon: "sun.max",
                    title: "阳历",
                    value: astrolabe.solarDate,
                    color: .starGold
                )
                
                InfoPill(
                    icon: "moon",
                    title: "农历",
                    value: astrolabe.lunarDate,
                    color: .mysticPink
                )
            }
            
            Text("\(astrolabe.chineseDate) | \(astrolabe.gender) | \(astrolabe.zodiac) | \(astrolabe.fiveElementsClass)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.crystalWhite)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - 增强版方形星盘
struct EnhancedSquareChart: View {
    let palaces: [FullPalace]
    let positions: [(row: Int, col: Int)]
    @Binding var selectedIndex: Int?
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / 4
            let cellHeight = geometry.size.height / 4
            
            ZStack {
                // 背景网格
                ForEach(0..<4) { row in
                    ForEach(0..<4) { col in
                        Rectangle()
                            .stroke(Color.moonSilver.opacity(0.2), lineWidth: 0.5)
                            .frame(width: cellWidth, height: cellHeight)
                            .position(
                                x: CGFloat(col) * cellWidth + cellWidth/2,
                                y: CGFloat(row) * cellHeight + cellHeight/2
                            )
                    }
                }
                
                // 中宫
                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.starGold, Color.mysticPink]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("紫微斗数")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.starGold, Color.crystalWhite]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .frame(width: cellWidth * 2 - 2, height: cellHeight * 2 - 2)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cosmicPurple.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.starGold.opacity(0.5), Color.mysticPink.opacity(0.5)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .position(x: cellWidth * 2, y: cellHeight * 2)
                
                // 12宫位
                ForEach(0..<min(12, palaces.count), id: \.self) { index in
                    let palace = palaces[index]
                    let position = positions[index]
                    
                    EnhancedPalaceCell(
                        palace: palace,
                        isSelected: selectedIndex == index,
                        cellWidth: cellWidth,
                        cellHeight: cellHeight
                    )
                    .frame(width: cellWidth - 2, height: cellHeight - 2)
                    .position(
                        x: CGFloat(position.col) * cellWidth + cellWidth/2,
                        y: CGFloat(position.row) * cellHeight + cellHeight/2
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

// MARK: - 增强版宫位单元格
struct EnhancedPalaceCell: View {
    let palace: FullPalace
    let isSelected: Bool
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            palace.isSoulPalace == true ? Color.starGold :
                            palace.isBodyPalace ? Color.mysticPink :
                            isSelected ? Color.crystalWhite :
                            Color.moonSilver.opacity(0.3),
                            lineWidth: palace.isSoulPalace == true || palace.isBodyPalace ? 2 : 1
                        )
                )
            
            VStack(spacing: 0) {
                // 顶部信息栏
                HStack {
                    Text(palace.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.crystalWhite)
                    
                    Spacer()
                    
                    Text("\(palace.heavenlyStem)\(palace.earthlyBranch)")
                        .font(.system(size: 10))
                        .foregroundColor(.moonSilver.opacity(0.8))
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
                
                // 命身标记
                if palace.isSoulPalace == true || palace.isBodyPalace {
                    HStack {
                        if palace.isSoulPalace == true {
                            Label("命", systemImage: "star.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.starGold)
                        }
                        if palace.isBodyPalace {
                            Label("身", systemImage: "person.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.mysticPink)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                }
                
                // 运限信息
                if let ages = palace.ages, !ages.isEmpty {
                    HStack {
                        Text("限: \(ages.first ?? 0)~\(ages.last ?? 0)")
                            .font(.system(size: 9))
                            .foregroundColor(.orange.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                }
                
                // 星耀显示区域（可滚动）
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 3) {
                        // 第一列：主星
                        if let majorStars = palace.majorStars, !majorStars.isEmpty {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(majorStars, id: \.name) { star in
                                    EnhancedStarView(
                                        star: star,
                                        type: .major
                                    )
                                }
                            }
                            .padding(.leading, 2)
                        }
                        
                        // 第二列：辅星
                        if let minorStars = palace.minorStars, !minorStars.isEmpty {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(minorStars, id: \.name) { star in
                                    EnhancedStarView(
                                        star: star,
                                        type: .minor
                                    )
                                }
                            }
                        }
                        
                        // 第三列：杂曜
                        if let adjectiveStars = palace.adjectiveStars, !adjectiveStars.isEmpty {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(adjectiveStars, id: \.self) { star in
                                    Text(star)
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                        }
                        
                        // 第四列：神煞（如果有）
                        VStack(alignment: .leading, spacing: 1) {
                            if let changsheng12 = palace.changsheng12, !changsheng12.isEmpty {
                                ForEach(changsheng12.prefix(3), id: \.self) { star in
                                    Text(star)
                                        .font(.system(size: 8))
                                        .foregroundColor(.green.opacity(0.6))
                                        .lineLimit(1)
                                }
                            }
                            if let boshi12 = palace.boshi12, !boshi12.isEmpty {
                                ForEach(boshi12.prefix(3), id: \.self) { star in
                                    Text(star)
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue.opacity(0.6))
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: cellHeight * 0.6)
                .padding(.top, 2)
                
                Spacer()
                
                // 底部小限信息
                if let ages = palace.ages, ages.count > 2 {
                    Text("小限: \(ages.map { String($0) }.joined(separator: ","))")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.7))
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 2)
                }
            }
        }
    }
}

// MARK: - 增强版星耀视图
struct EnhancedStarView: View {
    let star: SquareStarInfo
    let type: StarType
    
    enum StarType {
        case major, minor, adjective
        
        var color: Color {
            switch self {
            case .major:
                // 紫微系和天府系用不同颜色
                return .starGold
            case .minor:
                return .cyan
            case .adjective:
                return .gray
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 1) {
            // 星耀名称
            Text(star.name)
                .font(.system(size: 10, weight: type == .major ? .medium : .regular))
                .foregroundColor(getStarColor())
                .lineLimit(1)
            
            // 亮度标记
            if let brightness = star.brightness, !brightness.isEmpty {
                Text(brightness)
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.7))
            }
            
            // 四化标记
            if let mutagen = star.mutagen, !mutagen.isEmpty {
                Text(mutagen)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(getMutagenColor(mutagen))
            }
        }
    }
    
    private func getStarColor() -> Color {
        // 主星分类着色
        if type == .major {
            // 紫微系
            if ["紫微", "天机", "太阳", "武曲", "天同", "廉贞"].contains(star.name) {
                return .purple
            }
            // 天府系
            if ["天府", "太阴", "贪狼", "巨门", "天相", "天梁", "七杀", "破军"].contains(star.name) {
                return .yellow
            }
        }
        return type.color
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