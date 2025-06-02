//
//  ContentView.swift
//  HaptiTalkWatch Watch App
//
//  Created by 이은범 on 5/13/25.
//

#if os(watchOS)
import SwiftUI

@available(watchOS 6.0, *)
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            NavigationView {
                MainScreenView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .global)
                    .onChanged { value in
                        let horizontalAmount = abs(value.translation.width)
                        let verticalAmount = abs(value.translation.height)
                        
                        if horizontalAmount > verticalAmount {
                            // 수평 제스처 무시
                        }
                        // 수직 제스처는 기본 동작 허용
                    }
            )
            
            // 🎨 글로벌 시각적 피드백 오버레이
            if appState.showVisualFeedback {
                WatchVisualFeedbackView()
                    .environmentObject(appState)
                    .zIndex(999) // 최상위 레이어
                    .allowsHitTesting(false) // 터치 이벤트 통과
            }
        }
        .onChange(of: appState.showVisualFeedback) { _, newValue in
            if newValue {
                print("🎨 Watch: 글로벌 시각적 피드백 시작 - 패턴: \(appState.currentVisualPattern)")
            } else {
                print("🎨 Watch: 글로벌 시각적 피드백 종료")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
#endif
