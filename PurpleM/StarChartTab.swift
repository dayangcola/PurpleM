//
//  StarChartTab.swift  
//  PurpleM
//
//  Tab1: 星盘展示 - 集成现有的星盘功能
//

import SwiftUI

struct StarChartTab: View {
    @ObservedObject var iztroManager: IztroManager
    
    var body: some View {
        NavigationView {
            ZStack {
                // 使用现有的星语时光界面
                ModernZiWeiView()
                    .navigationBarHidden(true)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct StarChartTab_Previews: PreviewProvider {
    static var previews: some View {
        StarChartTab(iztroManager: IztroManager())
    }
}