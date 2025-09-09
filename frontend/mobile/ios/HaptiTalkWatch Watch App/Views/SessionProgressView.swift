//
//  SessionProgressView.swift
//  HaptiTalkWatch Watch App
//
//  Created on 5/15/25.
//

#if os(watchOS)
import SwiftUI
import WatchKit

@available(watchOS 6.0, *)
struct SessionProgressView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appState: AppState
    @State private var sessionTimer: TimeInterval = 0
    @State private var sessionMode: String = "발표"
    @State private var formattedTime: String = "00:00:00"
    @State private var showHapticNotification: Bool = false
    @State private var hapticNotificationMessage: String = ""
    @State private var currentTime: String = ""
    @State private var showSessionSummary: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 햅틱 피드백 구독은 이제 AppState에서 관리됨
    
    var recommendedTopics = ["핵심 포인트 강조", "시선 접촉", "목소리 강약", "자료 활용", "질의응답 준비"]
    
    // AppState에서 실시간 데이터 가져오기 - 발표 위주로 변경
    var confidenceState: String { 
        // 감정 상태를 발표 자신감으로 매핑
        switch appState.currentEmotion {
        case "긍정적": return "높음"
        case "부정적": return "낮음"
        case "중립적": return "보통"
        case "흥미로운": return "높음"
        case "집중적": return "매우 높음"
        default: return "보통"
        }
    }
    var confidenceColor: Color {
        switch confidenceState {
        case "매우 높음": return Color.purple
        case "높음": return Color.green
        case "보통": return Color.yellow
        case "낮음": return Color.red
        default: return Color.gray
        }
    }
    var speakingSpeed: Double { Double(appState.currentSpeakingSpeed) / 100.0 }
    var feedbackMessage: String { appState.currentFeedback }
    var showFeedback: Bool { !appState.currentFeedback.isEmpty }
    var likeabilityPercent: String { "\(appState.currentLikability)%" }
    var coreFeedback: String { 
        if !appState.currentFeedback.isEmpty {
            return appState.currentFeedback
        } else {
            return "핵심 메시지 전달이 명확했으며, 청중과의 소통이 매우 효과적이었습니다."
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 시각적 피드백 오버레이 추가
            if appState.showVisualFeedback {
                WatchVisualFeedbackView()
                    .transition(.opacity)
                    .zIndex(10) // 다른 UI 요소보다 위에 표시
            }
            
            // 일반 세션 UI 표시
            mainSessionContent
        }
        .fullScreenCover(isPresented: $showSessionSummary) {
            SessionSummaryView(
                sessionMode: sessionMode + " 모드",
                totalTime: formattedTime,
                mainEmotion: confidenceState,
                likeabilityPercent: likeabilityPercent,
                coreFeedback: coreFeedback
            )
        }
        .onReceive(timer) { _ in
            updateTimer()
            updateCurrentTime()
        }
        .onChange(of: appState.showHapticFeedback) { _, newValue in
            if newValue {
                showHapticNotification(message: appState.hapticFeedbackMessage)
                // 시각적 피드백은 AppState에서 자동으로 관리됨
                appState.showHapticFeedback = false
            }
        }
        // 🔥 세션 종료 시 자동으로 결과 화면으로 전환
        .onChange(of: appState.shouldShowSessionSummary) { _, newValue in
            if newValue {
                // 약간의 지연 후 화면 전환 (패스트 클릭 방지와 행/ 대비)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // 세션 요약 화면으로 전환
                    showSessionSummary = true
                    // 플래그 리셉
                    appState.shouldShowSessionSummary = false
                    print("🔥 Watch: 세션 요약 화면으로 자동 전환")
                }
            }
        }
        .onChange(of: appState.showVisualFeedback) { _, newValue in
            // 시각적 피드백 상태 변화 감지 및 로깅
            if newValue {
                print("🎨 Watch: 시각적 피드백 시작 - 패턴: \(appState.currentVisualPattern)")
                
                // 시각적 피드백 자동 종료 타이머 설정 (5초)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    if appState.showVisualFeedback {
                        withAnimation {
                            appState.showVisualFeedback = false
                        }
                    }
                }
            } else {
                print("🎨 Watch: 시각적 피드백 종료")
            }
        }
        .onChange(of: appState.shouldCloseSession) { _, shouldClose in
            if shouldClose {
                print("🔄 Watch: 세션 자동 종료 요청 감지, 화면 닫기")
                presentationMode.wrappedValue.dismiss()
                // 플래그 리셋
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    appState.shouldCloseSession = false
                    print("🔄 Watch: 세션 종료 플래그 리셋 완료")
                }
            }
        }
        .onAppear {
            initializeSession()
        }
    }
    
    private func updateTimer() {
        sessionTimer += 1
        
        let hours = Int(sessionTimer) / 3600
        let minutes = (Int(sessionTimer) % 3600) / 60
        let seconds = Int(sessionTimer) % 60
        
        formattedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func updateCurrentTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentTime = formatter.string(from: Date())
    }
    
    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
    
    private func showHapticNotification(message: String) {
        hapticNotificationMessage = message
        showHapticNotification = true
        
        // 5초 후 자동으로 닫기
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.showHapticNotification = false
        }
    }
    
    private func saveSessionSummary() {
        // 세션 요약 정보 생성
        let summary = SessionSummary(
            id: UUID(),
            sessionMode: sessionMode + " 모드",
            totalTime: formattedTime,
            mainEmotion: confidenceState,
            likeabilityPercent: likeabilityPercent,
            coreFeedback: coreFeedback,
            date: Date()
        )
        
        // AppState에 세션 요약 저장
        appState.saveSessionSummary(summary: summary)
    }
    
    private func initializeSession() {
        print("🚀 Watch: SessionProgressView 화면 진입, 세션 초기화 시작")
        
        // 1. AppState에서 세션 정보 가져오기
        sessionMode = appState.sessionType
        
        // 2. 타이머 초기화 (만약 이미 진행 중이 아니라면)
        if sessionTimer == 0 {
            sessionTimer = 0
            formattedTime = "00:00:00"
            print("🕐 Watch: 세션 타이머 초기화 완료")
        }
        
        // 3. 세션 시작 환영 메시지 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            showHapticNotification(message: "🎙️ \(sessionMode) 세션이 시작되었습니다!")
            print("📳 Watch: 세션 시작 환영 메시지 표시")
        }
        
        // 4. iPhone에 Watch 앱 진입 완료 신호 전송
        let sessionStartedMessage = [
            "action": "watchSessionStarted",
            "sessionType": sessionMode,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        appState.sendToiPhone(message: sessionStartedMessage)
        print("📡 Watch: iPhone에 세션 진입 완료 신호 전송")
        
        // 5. 햅틱 이벤트 구독 설정
        setupHapticSubscriptions()
        
        print("✅ Watch: 세션 초기화 완료")
    }
    
    private var mainSessionContent: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                // 상단 시간 및 모드 표시
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.sRGB, red: 0.25, green: 0.32, blue: 0.71, opacity: 1.0)) // #3F51B5 (앱 primaryColor와 일치)
                            .frame(width: 55, height: 21.5)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .resizable()
                                .frame(width: 12, height: 8)
                                .foregroundColor(.white)
                            
                            Text(sessionMode)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    Text(formattedTime)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(.sRGB, red: 0.88, green: 0.88, blue: 0.88, opacity: 1.0)) // #E0E0E0
                }
                .padding(.top, 5)
                
                // 감정 상태 및 말하기 속도 표시
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 67)
                    
                    VStack(spacing: 8) {
                        // 발표 자신감
                        HStack {
                            Text("발표 자신감")
                                .font(.system(size: 10))
                                .foregroundColor(Color(.sRGB, red: 0.88, green: 0.88, blue: 0.88, opacity: 1.0)) // #E0E0E0
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .resizable()
                                    .frame(width: 12, height: 10)
                                    .foregroundColor(confidenceColor)
                                
                                Text(confidenceState)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(confidenceColor)
                            }
                        }
                        
                        // 말하기 속도
                        VStack(spacing: 4) {
                            Text("말하기 속도")
                                .font(.system(size: 10))
                                .foregroundColor(Color(.sRGB, red: 0.88, green: 0.88, blue: 0.88, opacity: 1.0)) // #E0E0E0
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 4)
                                    .cornerRadius(2)
                                
                                Rectangle()
                                    .fill(Color(.sRGB, red: 0.25, green: 0.32, blue: 0.71, opacity: 1.0)) // #3F51B5
                                    .frame(width: {
                                        return WKInterfaceDevice.current().screenBounds.width * 0.75 * speakingSpeed
                                    }(), height: 4)
                                    .cornerRadius(2)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.top, 10)
                
                // 피드백 메시지
                if showFeedback {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.sRGB, red: 0.25, green: 0.32, blue: 0.71, opacity: 0.15)) // #3F51B5 with opacity
                            .frame(height: 44)
                        
                        Text(feedbackMessage)
                            .font(.system(size: 10))
                            .foregroundColor(Color(.sRGB, red: 0.56, green: 0.79, blue: 0.98, opacity: 1.0)) // #90CAF9
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(.top, 10)
                }
                
                // 추천 발표 포인트
                VStack(alignment: .leading, spacing: 4) {
                    Text("추천 발표 포인트")
                        .font(.system(size: 10))
                        .foregroundColor(Color(.sRGB, red: 0.62, green: 0.62, blue: 0.62, opacity: 1.0)) // #9E9E9E
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(recommendedTopics, id: \.self) { topic in
                                Text(topic)
                                    .font(.system(size: 9))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.sRGB, red: 0.3, green: 0.69, blue: 0.31, opacity: 0.3)) // #4CAF50 with opacity
                                            .stroke(Color(.sRGB, red: 0.3, green: 0.69, blue: 0.31, opacity: 1.0), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .padding(.top, 10)
                
                Spacer()
                
                // 종료 버튼 제거됨
                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .buttonStyle(PlainButtonStyle())
            .padding(.top, -10)
        }
        .padding(.top, -10)
    }
}

// 햅틱 이벤트 구독 설정 메소드 추가
extension SessionProgressView {
    private func setupHapticSubscriptions() {
        // AppState에서 햅틱 피드백 이벤트 구독 설정
        appState.setupSessionViewHapticSubscription { [self] message in
            // 햅틱 알림 표시
            showHapticNotification(message: message)
            
            // 시각적 피드백 표시 (햅틱과 동시에)
            if !appState.currentVisualPattern.isEmpty {
                withAnimation {
                    appState.showVisualFeedback = true
                }
            }
        }
    }
}

struct SessionProgressView_Previews: PreviewProvider {
    static var previews: some View {
        SessionProgressView()
            .environmentObject(AppState())
    }
}
#endif 