//
//  MainScreenView.swift
//  HaptiTalkWatch Watch App
//
//  Created on 5/13/25.
//

#if os(watchOS)
import SwiftUI

@available(watchOS 6.0, *)
struct MainScreenView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSessionModeSelection = false
    @State private var showConnectionStatus = false
    @State private var showSessionProgress = false
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                // 앱 아이콘 및 상태 - 가운데 정렬
                VStack(spacing: 2) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.sRGB, red: 0.25, green: 0.32, blue: 0.71, opacity: 1.0)) // #3F51B5
                            .frame(width: 40, height: 40)
                        
                        Text("H")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // 연결 상태
                if appState.isConnected {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(.sRGB, red: 0.3, green: 0.69, blue: 0.31, opacity: 1.0)) // #4CAF50
                            .frame(width: 6, height: 6)
                        
                        Text(appState.connectedDevice)
                            .font(.system(size: 11))
                            .foregroundColor(Color(.sRGB, red: 0.3, green: 0.69, blue: 0.31, opacity: 1.0)) // #4CAF50
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        
                        Text("연결 안됨")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Spacer()
                
                // 세션 시작 버튼
                Button(action: {
                    if appState.isConnected {
                        // 세션 모드 선택 화면으로 이동
                        showSessionModeSelection = true
                    } else {
                        // 연결되지 않은 경우 연결 상태 화면으로 이동
                        showConnectionStatus = true
                    }
                }) {
                    Text("세션 시작")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.sRGB, red: 0.25, green: 0.32, blue: 0.71, opacity: 1.0)) // #3F51B5
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                // 설정 버튼 - 세션 모드 자리에 배치
                Button(action: {
                    showSettings = true
                }) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text("설정")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(.sRGB, red: 0.13, green: 0.13, blue: 0.13, opacity: 1.0)) // #212121
                    )
                }
                .padding(.bottom, 5)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .sheet(isPresented: $showSessionModeSelection) {
            SessionModeSelectionView(onModeSelected: { mode in
                showSessionProgress = true
            })
        }
        .sheet(isPresented: $showConnectionStatus) {
            ConnectionStatusView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showSessionProgress) {
            SessionProgressView()
        }
        // 🚀 iPhone에서 세션 시작 메시지를 받으면 자동으로 세션 화면으로 전환
        .onChange(of: appState.shouldNavigateToSession) { shouldNavigate in
            if shouldNavigate {
                print("🚀 Watch: 자동 세션 화면 전환 시작")
                showSessionProgress = true
                // 플래그 리셋 (한 번만 실행되도록)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    appState.shouldNavigateToSession = false
                    print("🔄 Watch: 자동 전환 플래그 리셋 완료")
                }
            }
        }
    }
}

struct MainScreenView_Previews: PreviewProvider {
    static var previews: some View {
        MainScreenView()
            .environmentObject(AppState())
    }
}
#endif 
