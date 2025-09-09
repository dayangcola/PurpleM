//
//  ContentView.swift
//  PurpleM
//
//  使用原始iztro JavaScript算法的紫微斗数应用
//

import SwiftUI

struct ContentView: View {
    @StateObject private var iztroManager = IztroManager()
    @State private var selectedDate = Date()
    @State private var selectedGender = "男"
    @State private var isLunarDate = false
    @State private var showingResult = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    Picker("性别", selection: $selectedGender) {
                        Text("男").tag("男")
                        Text("女").tag("女")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("出生日期时间")) {
                    Toggle("使用农历", isOn: $isLunarDate)
                    
                    DatePicker(
                        "出生日期时间",
                        selection: $selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                }
                
                Section {
                    Button(action: calculateAstrolabe) {
                        if iztroManager.isCalculating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            HStack {
                                Spacer()
                                if iztroManager.isReady {
                                    Text("生成星盘")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                } else {
                                    Text("正在加载...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(iztroManager.isReady && !iztroManager.isCalculating ? Color.blue : Color.gray)
                    .cornerRadius(10)
                    .disabled(!iztroManager.isReady || iztroManager.isCalculating)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("紫微斗数排盘")
            .sheet(isPresented: $showingResult) {
                ResultView(resultData: iztroManager.resultData)
            }
        }
        .onChange(of: iztroManager.resultData) { newValue in
            if !newValue.isEmpty && newValue != "{\"status\":\"ready\"}" {
                showingResult = true
            }
        }
    }
    
    private func calculateAstrolabe() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedDate)
        
        iztroManager.calculate(
            year: components.year ?? 2000,
            month: components.month ?? 1,
            day: components.day ?? 1,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            gender: selectedGender,
            isLunar: isLunarDate
        )
    }
}

struct ResultView: View {
    let resultData: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let data = resultData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // 显示错误信息（如果有）
                        if let error = json["error"] as? String {
                            Text("错误：\(error)")
                                .foregroundColor(.red)
                                .font(.headline)
                        } else {
                            // 显示基本信息
                            if let solarDate = json["solarDate"] as? String {
                                Text("阳历：\(solarDate)")
                                    .font(.headline)
                            }
                            
                            if let lunarDate = json["lunarDate"] as? String {
                                Text("农历：\(lunarDate)")
                                    .font(.headline)
                            }
                            
                            // 显示宫位信息
                            if let palaces = json["palaces"] as? [[String: Any]] {
                                ForEach(0..<palaces.count, id: \.self) { index in
                                    if let palace = palaces[index] as? [String: Any],
                                       let name = palace["name"] as? String {
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(name)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                            
                                            if let majorStars = palace["majorStars"] as? [[String: Any]],
                                               !majorStars.isEmpty {
                                                Text("主星：")
                                                    .font(.subheadline)
                                                ForEach(0..<majorStars.count, id: \.self) { starIndex in
                                                    if let star = majorStars[starIndex] as? [String: Any],
                                                       let starName = star["name"] as? String {
                                                        Text("  • \(starName)")
                                                    }
                                                }
                                            }
                                            
                                            if let isBodyPalace = palace["isBodyPalace"] as? Bool,
                                               isBodyPalace {
                                                Text("【身宫】")
                                                    .foregroundColor(.blue)
                                            }
                                            
                                            if let isSoulPalace = palace["isSoulPalace"] as? Bool,
                                               isSoulPalace {
                                                Text("【命宫】")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        Text("数据解析失败")
                            .foregroundColor(.red)
                            .font(.headline)
                        
                        Text("原始数据：")
                            .font(.caption)
                        
                        Text(resultData)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                    }
                    .padding()
                }
            }
            .navigationTitle("星盘结果")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}