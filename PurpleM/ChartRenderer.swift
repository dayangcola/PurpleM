//
//  ChartRenderer.swift
//  PurpleM
//
//  星盘渲染组件 - 12宫格展示
//

import SwiftUI

// MARK: - 星盘数据模型
struct AstrolabeData: Codable {
    let success: Bool
    let solarDate: String
    let lunarDate: String
    let chineseDate: String
    let gender: String
    let zodiac: String
    let sign: String
    let fiveElementsClass: String
    let palaces: [Palace]
}

struct Palace: Codable {
    let index: Int
    let name: String
    let heavenlyStem: String
    let earthlyBranch: String
    let isBodyPalace: Bool
    let isSoulPalace: Bool
    let majorStars: [Star]
    let minorStars: [Star]
    let adjectiveStars: [String]
}

struct Star: Codable {
    let name: String
    let brightness: String?
    let mutagen: String?
}

// MARK: - 星盘渲染视图
struct ChartRenderer: View {
    let jsonData: String
    @State private var astrolabe: AstrolabeData?
    @State private var selectedPalaceIndex: Int? = nil
    
    var body: some View {
        if let astrolabe = astrolabe {
            VStack(spacing: 0) {
                // 基本信息栏
                ChartInfoBar(astrolabe: astrolabe)
                    .padding()
                
                // 12宫格星盘
                GeometryReader { geometry in
                    let size = min(geometry.size.width, geometry.size.height)
                    
                    ZStack {
                        // 背景装饰
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.starGold.opacity(0.2),
                                        Color.mysticPink.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .frame(width: size * 0.95, height: size * 0.95)
                        
                        // 12宫位圆形布局
                        ForEach(0..<12, id: \.self) { index in
                            if index < astrolabe.palaces.count {
                                let palace = astrolabe.palaces[index]
                                let angle = Double(index) * 30 - 90
                                let radius = size * 0.35
                                let x = size/2 + radius * cos(angle * .pi / 180)
                                let y = size/2 + radius * sin(angle * .pi / 180)
                                
                                PalaceCell(
                                    palace: palace,
                                    isSelected: selectedPalaceIndex == index
                                )
                                .position(x: x, y: y)
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        selectedPalaceIndex = selectedPalaceIndex == index ? nil : index
                                    }
                                }
                            }
                        }
                        
                        // 中心标题
                        VStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.title2)
                                .foregroundColor(.starGold)
                            Text("紫微斗数")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundColor(.crystalWhite)
                        }
                        .position(x: size/2, y: size/2)
                    }
                    .frame(width: size, height: size)
                }
                
                // 选中宫位详情
                if let index = selectedPalaceIndex,
                   index < astrolabe.palaces.count {
                    PalaceDetailView(palace: astrolabe.palaces[index])
                        .padding()
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
        } else {
            // 解析JSON数据
            Color.clear.onAppear {
                parseJSON()
            }
        }
    }
    
    private func parseJSON() {
        guard let data = jsonData.data(using: .utf8) else { return }
        
        do {
            let decoder = JSONDecoder()
            astrolabe = try decoder.decode(AstrolabeData.self, from: data)
        } catch {
            print("JSON解析错误: \(error)")
            // 尝试手动解析
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                parseManually(json: json)
            }
        }
    }
    
    private func parseManually(json: [String: Any]) {
        // 手动解析JSON构建数据模型
        var palaces: [Palace] = []
        
        if let palacesArray = json["palaces"] as? [[String: Any]] {
            for palaceDict in palacesArray {
                let index = palaceDict["index"] as? Int ?? 0
                let name = palaceDict["name"] as? String ?? ""
                let heavenlyStem = palaceDict["heavenlyStem"] as? String ?? ""
                let earthlyBranch = palaceDict["earthlyBranch"] as? String ?? ""
                let isBodyPalace = palaceDict["isBodyPalace"] as? Bool ?? false
                let isSoulPalace = palaceDict["isSoulPalace"] as? Bool ?? false
                
                var majorStars: [Star] = []
                if let majorStarsArray = palaceDict["majorStars"] as? [[String: Any]] {
                    for starDict in majorStarsArray {
                        let star = Star(
                            name: starDict["name"] as? String ?? "",
                            brightness: starDict["brightness"] as? String,
                            mutagen: starDict["mutagen"] as? String
                        )
                        majorStars.append(star)
                    }
                }
                
                var minorStars: [Star] = []
                if let minorStarsArray = palaceDict["minorStars"] as? [[String: Any]] {
                    for starDict in minorStarsArray {
                        let star = Star(
                            name: starDict["name"] as? String ?? "",
                            brightness: starDict["brightness"] as? String,
                            mutagen: starDict["mutagen"] as? String
                        )
                        minorStars.append(star)
                    }
                }
                
                let palace = Palace(
                    index: index,
                    name: name,
                    heavenlyStem: heavenlyStem,
                    earthlyBranch: earthlyBranch,
                    isBodyPalace: isBodyPalace,
                    isSoulPalace: isSoulPalace,
                    majorStars: majorStars,
                    minorStars: minorStars,
                    adjectiveStars: []
                )
                
                palaces.append(palace)
            }
        }
        
        astrolabe = AstrolabeData(
            success: json["success"] as? Bool ?? true,
            solarDate: json["solarDate"] as? String ?? "",
            lunarDate: json["lunarDate"] as? String ?? "",
            chineseDate: json["chineseDate"] as? String ?? "",
            gender: json["gender"] as? String ?? "",
            zodiac: json["zodiac"] as? String ?? "",
            sign: json["sign"] as? String ?? "",
            fiveElementsClass: json["fiveElementsClass"] as? String ?? "",
            palaces: palaces
        )
    }
}

// MARK: - 信息栏
struct ChartInfoBar: View {
    let astrolabe: AstrolabeData
    
    var body: some View {
        VStack(spacing: 12) {
            // 日期信息
            HStack(spacing: 20) {
                Label(astrolabe.solarDate, systemImage: "sun.max")
                    .font(.caption)
                    .foregroundColor(.starGold)
                
                Label(astrolabe.lunarDate, systemImage: "moon")
                    .font(.caption)
                    .foregroundColor(.mysticPink)
            }
            
            // 基本信息
            HStack(spacing: 15) {
                InfoChip(text: astrolabe.gender, icon: "person")
                InfoChip(text: astrolabe.zodiac, icon: "hare")
                InfoChip(text: astrolabe.sign, icon: "star")
                InfoChip(text: astrolabe.fiveElementsClass, icon: "flame")
            }
        }
        .padding()
        .background(
            Color.white.opacity(0.05)
                .cornerRadius(15)
        )
    }
}

// MARK: - 信息标签
struct InfoChip: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundColor(.crystalWhite)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - 宫位单元格
struct PalaceCell: View {
    let palace: Palace
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            // 宫位名称
            Text(palace.name)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            
            // 干支
            Text("\(palace.heavenlyStem)\(palace.earthlyBranch)")
                .font(.system(size: 8))
                .foregroundColor(.moonSilver.opacity(0.7))
            
            // 命身标记
            if palace.isSoulPalace || palace.isBodyPalace {
                Text(palace.isSoulPalace ? "命" : "身")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(palace.isSoulPalace ? .starGold : .mysticPink)
            }
            
            // 主星显示
            if !palace.majorStars.isEmpty {
                Text(palace.majorStars.first?.name ?? "")
                    .font(.system(size: 9))
                    .foregroundColor(.starGold)
                    .lineLimit(1)
            }
            
            // 星星数量指示
            if palace.majorStars.count + palace.minorStars.count > 1 {
                HStack(spacing: 1) {
                    ForEach(0..<min(3, palace.majorStars.count + palace.minorStars.count), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 5))
                            .foregroundColor(.starGold.opacity(0.6))
                    }
                }
            }
        }
        .frame(width: 70, height: 70)
        .background(
            Circle()
                .fill(
                    isSelected ?
                    LinearGradient(
                        gradient: Gradient(colors: [Color.mysticPink.opacity(0.3), Color.cosmicPurple.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Circle()
                .stroke(
                    palace.isSoulPalace ? Color.starGold :
                    palace.isBodyPalace ? Color.mysticPink :
                    isSelected ? Color.mysticPink.opacity(0.5) :
                    Color.moonSilver.opacity(0.2),
                    lineWidth: palace.isSoulPalace || palace.isBodyPalace ? 2 : 1
                )
        )
        .scaleEffect(isSelected ? 1.1 : 1.0)
    }
}

// MARK: - 宫位详情视图
struct PalaceDetailView: View {
    let palace: Palace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text(palace.name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.crystalWhite)
                
                Text("(\(palace.heavenlyStem)\(palace.earthlyBranch))")
                    .font(.system(size: 14))
                    .foregroundColor(.moonSilver.opacity(0.7))
                
                Spacer()
                
                if palace.isSoulPalace {
                    Label("命宫", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.starGold)
                }
                
                if palace.isBodyPalace {
                    Label("身宫", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.mysticPink)
                }
            }
            
            // 主星
            if !palace.majorStars.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("主星")
                        .font(.caption)
                        .foregroundColor(.moonSilver.opacity(0.6))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(palace.majorStars, id: \.name) { star in
                                StarBadge(star: star, type: .major)
                            }
                        }
                    }
                }
            }
            
            // 辅星
            if !palace.minorStars.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("辅星")
                        .font(.caption)
                        .foregroundColor(.moonSilver.opacity(0.6))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(palace.minorStars, id: \.name) { star in
                                StarBadge(star: star, type: .minor)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            Color.white.opacity(0.05)
                .cornerRadius(15)
        )
    }
}

// MARK: - 星耀徽章
struct StarBadge: View {
    let star: Star
    let type: StarType
    
    enum StarType {
        case major, minor
        
        var color: Color {
            switch self {
            case .major: return .starGold
            case .minor: return .mysticPink
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(star.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.crystalWhite)
            
            if let brightness = star.brightness, !brightness.isEmpty {
                Text(brightness)
                    .font(.system(size: 9))
                    .foregroundColor(.moonSilver.opacity(0.6))
            }
            
            if let mutagen = star.mutagen, !mutagen.isEmpty {
                Text(mutagen)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(type.color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(type.color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}