//
//  AppState.swift
//  HaptiTalkWatch Watch App
//
//  Created on 5/13/25.
//

#if os(watchOS)
import Foundation
import SwiftUI
import Combine
import WatchKit
import WatchConnectivity

@available(watchOS 6.0, *)
class AppState: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isConnected: Bool = false
    @Published var connectedDevice: String = "연결 중..."
    @Published var recentSessions: [Session] = []
    
    // 햅틱 피드백 관련 상태
    @Published var showHapticFeedback: Bool = false
    @Published var hapticFeedbackMessage: String = ""
    @Published var sessionType: String = "소개팅"
    @Published var elapsedTime: String = "00:00:00"
    
    // 실시간 분석 데이터
    @Published var currentLikability: Int = 78
    @Published var currentInterest: Int = 92
    @Published var currentSpeakingSpeed: Int = 85
    @Published var currentEmotion: String = "긍정적"
    @Published var currentFeedback: String = ""
    
    // 세션 요약 관련 상태
    @Published var sessionSummaries: [SessionSummary] = []
    
    // 설정 관련 상태
    @Published var hapticIntensity: String = "기본"  // "기본", "강하게" 옵션
    @Published var hapticCount: Int = 2           // 햅틱 피드백 횟수 (1~4회)
    @Published var notificationStyle: String = "전체"  // "아이콘", "전체"
    @Published var isWatchfaceComplicationEnabled: Bool = true
    @Published var isBatterySavingEnabled: Bool = false
    
    // 세션 상태
    @Published var isSessionActive: Bool = false
    @Published var shouldNavigateToSession: Bool = false
    
    // 더미 데이터 초기화
    override init() {
        super.init()
        setupWatchConnectivity()
        
        recentSessions = [
            Session(id: UUID(), name: "소개팅 모드", date: Date().addingTimeInterval(-86400), duration: 1800)
        ]
        
        sessionSummaries = [
            SessionSummary(
                id: UUID(),
                sessionMode: "소개팅 모드",
                totalTime: "1:32:05",
                mainEmotion: "긍정적",
                likeabilityPercent: "88%",
                coreFeedback: "여행 주제에서 높은 호감도를 보였으며, 경청하는 자세가 매우 효과적이었습니다.",
                date: Date().addingTimeInterval(-86400)
            )
        ]
    }
    
    // MARK: - WatchConnectivity Setup
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("Watch: WCSession setup completed")
            
            // 초기 연결 상태 확인
            DispatchQueue.main.async {
                self.updateConnectionStatus()
            }
        } else {
            print("Watch: WCSession is not supported")
        }
    }
    
    private func updateConnectionStatus() {
        let session = WCSession.default
        self.isConnected = session.activationState == .activated && session.isReachable
        
        #if os(watchOS)
        let deviceName = WKInterfaceDevice.current().name
        self.connectedDevice = self.isConnected ? "연결됨: \(deviceName)" : "연결 안됨"
        #endif
        
        print("Watch: Connection status updated - isConnected: \(self.isConnected), device: \(self.connectedDevice)")
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            print("Watch: Session activation completed - state: \(activationState.rawValue)")
            if let error = error {
                print("Watch: Session activation error - \(error.localizedDescription)")
            }
            self.updateConnectionStatus()
            
            // 🚀 Watch에서 먼저 iPhone에 연결 신호 전송
            if activationState == .activated {
                let connectionSignal = [
                    "action": "watchConnected",
                    "watchReady": true,
                    "timestamp": Date().timeIntervalSince1970
                ] as [String : Any]
                
                self.sendToiPhone(message: connectionSignal)
                print("Watch: 📡 iPhone에 연결 신호 전송")
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Watch received message from iPhone: \(message)")
        DispatchQueue.main.async {
            self.handleMessageFromiPhone(message)
            
            // iPhone에 응답 보내기 - Watch 앱이 살아있다는 신호
            let response = [
                "status": "received",
                "action": message["action"] as? String ?? "unknown",
                "timestamp": Date().timeIntervalSince1970,
                "watchAppActive": true
            ] as [String : Any]
            
            self.sendToiPhone(message: response)
            print("Watch: 📡 iPhone에 응답 전송 - \(response)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Watch received message with reply handler from iPhone: \(message)")
        DispatchQueue.main.async {
            self.handleMessageFromiPhone(message)
            
            // iPhone에 직접 응답
            let response = [
                "status": "received",
                "action": message["action"] as? String ?? "unknown", 
                "timestamp": Date().timeIntervalSince1970,
                "watchAppActive": true
            ] as [String : Any]
            
            replyHandler(response)
            print("Watch: 📡 iPhone에 직접 응답 완료 - \(response)")
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("Watch received application context from iPhone: \(applicationContext)")
        DispatchQueue.main.async {
            self.handleMessageFromiPhone(applicationContext)
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("Watch: Reachability changed - isReachable: \(session.isReachable)")
            self.updateConnectionStatus()
        }
    }
    
    // MARK: - Message Handling
    private func handleMessageFromiPhone(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        
        switch action {
        case "startSession":
            if let sessionType = message["sessionType"] as? String {
                self.sessionType = sessionType
                self.isSessionActive = true
                self.shouldNavigateToSession = true  // 🚀 자동 화면 전환 트리거
                self.showHapticNotification(message: "\(sessionType) 세션이 시작되었습니다")
                print("🚀 Watch: 세션 시작됨, 화면 전환 트리거 - \(sessionType)")
            }
        case "stopSession":
            self.isSessionActive = false
            self.shouldNavigateToSession = false  // 🔄 세션 화면 전환 플래그 리셋
            self.showHapticNotification(message: "세션이 종료되었습니다")
            print("🔄 Watch: 세션 종료됨, 화면 전환 플래그 리셋")
        case "hapticFeedback":
            if let feedbackMessage = message["message"] as? String {
                self.showHapticNotification(message: feedbackMessage)
                
                // 실시간 분석 데이터 파싱
                self.parseAnalysisData(from: feedbackMessage)
            }
        case "hapticFeedbackWithPattern":
            // 🎯 HaptiTalk 설계 문서 기반 패턴별 햅틱 처리
            if let feedbackMessage = message["message"] as? String,
               let pattern = message["pattern"] as? String,
               let category = message["category"] as? String,
               let patternId = message["patternId"] as? String {
                
                print("🎯 Watch: 패턴 햅틱 수신 [\(patternId)/\(category)]: \(feedbackMessage)")
                self.showHapticNotificationWithPattern(
                    message: feedbackMessage,
                    pattern: pattern,
                    category: category,
                    patternId: patternId
                )
            }
        case "realtimeAnalysis":
            // 실시간 분석 데이터 업데이트
            if let likability = message["likability"] as? Int {
                self.currentLikability = likability
            }
            if let interest = message["interest"] as? Int {
                self.currentInterest = interest
            }
            if let speakingSpeed = message["speakingSpeed"] as? Int {
                self.currentSpeakingSpeed = speakingSpeed
            }
            if let emotion = message["emotion"] as? String {
                self.currentEmotion = emotion
            }
            if let feedback = message["feedback"] as? String {
                self.currentFeedback = feedback
                if !feedback.isEmpty {
                    self.showHapticNotification(message: feedback)
                }
            }
        default:
            break
        }
    }
    
    // 햅틱 피드백 메시지에서 분석 데이터 파싱
    private func parseAnalysisData(from message: String) {
        // "호감도: 78%, 관심도: 92%" 형태의 메시지 파싱
        if message.contains("호감도:") && message.contains("관심도:") {
            let components = message.components(separatedBy: ", ")
            
            for component in components {
                if component.contains("호감도:") {
                    let likabilityStr = component.replacingOccurrences(of: "호감도: ", with: "").replacingOccurrences(of: "%", with: "")
                    if let likability = Int(likabilityStr) {
                        self.currentLikability = likability
                    }
                } else if component.contains("관심도:") {
                    let interestStr = component.replacingOccurrences(of: "관심도: ", with: "").replacingOccurrences(of: "%", with: "")
                    if let interest = Int(interestStr) {
                        self.currentInterest = interest
                    }
                }
            }
        } else {
            // 일반 피드백 메시지
            self.currentFeedback = message
        }
    }
    
    // iPhone으로 메시지 전송
    func sendToiPhone(message: [String: Any]) {
        let session = WCSession.default
        print("Watch attempting to send message to iPhone: \(message)")
        print("Session state - isReachable: \(session.isReachable)")
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { (response: [String: Any]?) in
                if let response = response {
                    print("iPhone responded: \(response)")
                }
            }) { (error: Error?) in
                if let error = error {
                    print("iPhone message error: \(error.localizedDescription)")
                }
            }
        } else {
            print("iPhone is not reachable, using applicationContext")
            do {
                try session.updateApplicationContext(message)
                print("Sent message via applicationContext")
            } catch {
                print("Failed to update applicationContext: \(error.localizedDescription)")
            }
        }
    }
    
    // 연결 상태 관리 함수
    func disconnectDevice() {
        isConnected = false
        // 실제 구현에서는 여기에 Bluetooth 연결 해제 로직이 들어갈 수 있습니다
    }
    
    func reconnectDevice() {
        isConnected = true
        // 실제 구현에서는 여기에 Bluetooth 재연결 로직이 들어갈 수 있습니다
    }
    
    // 햅틱 테스트 함수
    func testHaptic() {
        // UI 업데이트를 위해 메인 스레드에서 시작
        DispatchQueue.main.async {
            // 설정된 햅틱 횟수만큼 반복
            self.playHapticSequence(count: self.hapticCount)
        }
    }
    
    private func playHapticSequence(count: Int, currentIndex: Int = 0) {
        guard currentIndex < count else { return }
        
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        
        // 강도에 따른 햅틱 피드백 결정
        if self.hapticIntensity == "기본" {
            // 기본 강도 - directionUp 햅틱 사용
            device.play(.directionUp)
            
            // 매우 짧은 간격으로 추가 햅틱 제공
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                device.play(.notification)
            }
        } else {
            // 강한 강도 - 3중 연타 햅틱
            device.play(.notification)
            
            // 더 강한 느낌을 위해 추가 햅틱 제공
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                device.play(.directionUp)
            }
        }
        #endif
        
        // 다음 햅틱을 0.7초 후에 실행 (명확하게 구분될 수 있도록 충분한 간격 필요)
        if currentIndex < count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.playHapticSequence(count: count, currentIndex: currentIndex + 1)
            }
        }
    }
    
    // 햅틱 피드백 알림 표시 함수
    func showHapticNotification(message: String) {
        hapticFeedbackMessage = message
        showHapticFeedback = true
        
        // 메시지 내용에 따라 다른 햅틱 패턴 적용
        triggerHapticFeedback(for: message)
        
        // 5초 후 자동으로 알림 닫기 (필요시)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.showHapticFeedback = false
        }
    }
    
    // 메시지에 따른 햅틱 피드백 발생 함수
    private func triggerHapticFeedback(for message: String) {
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        
        // 🎯 메시지 유형에 따른 다른 햅틱 패턴
        if message.contains("🚀") || message.contains("⏰") {
            // 🚨 경고 - 강한 3번 연타
            playWarningHaptic(device: device)
        } else if message.contains("💕") || message.contains("🎉") || message.contains("✨") {
            // 🎉 긍정 - 부드러운 2번 펄스
            playPositiveHaptic(device: device)
        } else if message.contains("😊") || message.contains("📈") || message.contains("⚡") {
            // 😊 중성 - 기본 1번 알림
            playNeutralHaptic(device: device)
        } else if message.contains("💡") || message.contains("💭") {
            // 💡 제안 - 가벼운 2번 탭
            playSuggestionHaptic(device: device)
        } else {
            // 🔔 기본 - 표준 알림
            playDefaultHaptic(device: device)
        }
        #endif
    }
    
    // 🚨 경고용 햅틱 (강한 3번 연타)
    private func playWarningHaptic(device: WKInterfaceDevice) {
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            device.play(.directionUp)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            device.play(.notification)
        }
    }
    
    // 🎉 긍정용 햅틱 (부드러운 2번 펄스)
    private func playPositiveHaptic(device: WKInterfaceDevice) {
        device.play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            device.play(.success)
        }
    }
    
    // 😊 중성용 햅틱 (기본 1번 알림)
    private func playNeutralHaptic(device: WKInterfaceDevice) {
        device.play(.directionUp)
    }
    
    // 💡 제안용 햅틱 (가벼운 2번 탭)
    private func playSuggestionHaptic(device: WKInterfaceDevice) {
        device.play(.click)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            device.play(.click)
        }
    }
    
    // 🔔 기본 햅틱 (표준 알림)
    private func playDefaultHaptic(device: WKInterfaceDevice) {
        device.play(.notification)
    }
    
    // 세션 요약 저장 함수
    func saveSessionSummary(summary: SessionSummary) {
        sessionSummaries.insert(summary, at: 0)
        // 실제 구현에서는 여기에 데이터 저장 로직이 들어갈 수 있습니다
    }
    
    // 설정 저장 함수
    func saveSettings() {
        // 실제 구현에서는 여기에 설정 저장 로직이 들어갈 수 있습니다
        // UserDefaults 또는 다른 영구 저장소에 저장
    }
    
    // 🎯 HaptiTalk 설계 문서 기반 패턴별 햅틱 피드백
    func showHapticNotificationWithPattern(
        message: String,
        pattern: String,
        category: String,
        patternId: String
    ) {
        hapticFeedbackMessage = message
        showHapticFeedback = true
        
        // 🎯 설계 문서의 8개 기본 MVP 패턴 적용
        triggerMVPHapticPattern(patternId: patternId, pattern: pattern)
        
        // 5초 후 자동으로 알림 닫기
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.showHapticFeedback = false
        }
    }
    
    // 🎯 HaptiTalk MVP 햅틱 패턴 (설계 문서 기반)
    private func triggerMVPHapticPattern(patternId: String, pattern: String) {
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        
        switch patternId {
        case "S1":  // 속도 조절 패턴 - 빠른 3회 연속 진동 (100ms 간격)
            playSpeedControlPattern(device: device)
        case "L1":  // 경청 강화 패턴 - 점진적 강도 증가 3회 진동
            playListeningPattern(device: device)
        case "F1":  // 주제 전환 패턴 - 400ms 긴 단일 진동
            playTopicChangePattern(device: device)
        case "R1":  // 호감도 상승 패턴 - 점진적 증가 파동형 3회
            playLikabilityUpPattern(device: device)
        case "F2":  // 침묵 관리 패턴 - 부드러운 2회 탭 (300ms 간격)
            playSilenceManagementPattern(device: device)
        case "S2":  // 음량 조절 패턴 - 강도 변화 2회 진동
            playVolumeControlPattern(device: device, pattern: pattern)
        case "R2":  // 관심도 하락 패턴 - 강한 2회 경고 진동 (150ms 간격)
            playInterestDownPattern(device: device)
        case "L3":  // 질문 제안 패턴 - 2회 짧은 탭 + 1회 긴 진동
            playQuestionSuggestionPattern(device: device)
        default:
            // 기본 패턴 - 표준 알림
            playDefaultHaptic(device: device)
        }
        #endif
    }
    
    // 📊 S1: 속도 조절 패턴 (메타포: 빠른 심장 박동)
    private func playSpeedControlPattern(device: WKInterfaceDevice) {
        // 100ms 진동 x 3회, 100ms 간격, 중간 강도
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            device.play(.notification)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            device.play(.notification)
        }
    }
    
    // 📊 L1: 경청 강화 패턴 (메타포: 점진적 주의 집중)
    private func playListeningPattern(device: WKInterfaceDevice) {
        // 200ms 진동 x 3회, 점진적 강도 증가, 150ms 간격
        device.play(.click)  // 약함
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            device.play(.directionUp)  // 중간
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            device.play(.notification)  // 강함
        }
    }
    
    // 📊 F1: 주제 전환 패턴 (메타포: 페이지 넘기기)
    private func playTopicChangePattern(device: WKInterfaceDevice) {
        // 400ms 긴 단일 진동, 높은 강도
        device.play(.success)
    }
    
    // 📊 R1: 호감도 상승 패턴 (메타포: 상승하는 파동)
    private func playLikabilityUpPattern(device: WKInterfaceDevice) {
        // 200ms 진동 x 3회, 점진적 증가, 50ms 간격
        device.play(.click)  // 낮음
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            device.play(.directionUp)  // 중간
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            device.play(.success)  // 높음
        }
    }
    
    // 📊 F2: 침묵 관리 패턴 (메타포: 부드러운 알림)
    private func playSilenceManagementPattern(device: WKInterfaceDevice) {
        // 150ms 진동 x 2회, 약간 증가하는 강도, 300ms 간격
        device.play(.click)  // 약함
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            device.play(.directionUp)  // 중간
        }
    }
    
    // 📊 S2: 음량 조절 패턴 (메타포: 음파 증폭/감소)
    private func playVolumeControlPattern(device: WKInterfaceDevice, pattern: String) {
        if pattern.contains("loud") {
            // 음량 낮춤: 강→약 (300ms 각각, 50ms 간격)
            device.play(.notification)  // 강함
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                device.play(.click)  // 약함
            }
        } else {
            // 음량 높임: 약→강 (300ms 각각, 50ms 간격)
            device.play(.click)  // 약함
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                device.play(.notification)  // 강함
            }
        }
    }
    
    // 📊 R2: 관심도 하락 패턴 (메타포: 경고 알림)
    private func playInterestDownPattern(device: WKInterfaceDevice) {
        // 100ms 진동 x 2회, 강한 강도, 150ms 간격
        device.play(.notification)  // 강함
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            device.play(.notification)  // 강함
        }
    }
    
    // 📊 L3: 질문 제안 패턴 (메타포: 물음표 형태)
    private func playQuestionSuggestionPattern(device: WKInterfaceDevice) {
        // 80ms 진동 x 2회 + 300ms 긴 진동, 중간-높은 강도
        device.play(.click)  // 짧음
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            device.play(.click)  // 짧음
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            device.play(.success)  // 길고 강함
        }
    }
}

struct Session: Identifiable {
    var id: UUID
    var name: String
    var date: Date
    var duration: TimeInterval // 초 단위
}

struct SessionSummary: Identifiable {
    var id: UUID
    var sessionMode: String
    var totalTime: String
    var mainEmotion: String
    var likeabilityPercent: String
    var coreFeedback: String
    var date: Date
}
#endif 