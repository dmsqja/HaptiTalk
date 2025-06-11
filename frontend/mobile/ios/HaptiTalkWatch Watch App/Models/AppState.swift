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
    @Published var connectedDevice: String = "연결 안됨"
    private var pairedDeviceName: String? = nil // 페어링된 iPhone 모델명 저장 변수
    @Published var recentSessions: [Session] = []
    
    // 햅틱 피드백 관련 상태
    @Published var showHapticFeedback: Bool = false
    @Published var hapticFeedbackMessage: String = ""
    @Published var sessionType: String = "소개팅"
    @Published var elapsedTime: String = "00:00:00"
    
    // 세션뷰의 햅틱 구독 관리용 변수
    private var sessionViewHapticCancellable: AnyCancellable?
    
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
    @Published var shouldShowSessionSummary: Bool = false  // 세션 요약 화면 표시 플래그
    
    // 🎨 시각적 피드백 상태 변수들
    @Published var showVisualFeedback: Bool = false
    @Published var currentVisualPattern: String = ""
    @Published var visualPatternColor: Color = .blue
    @Published var visualAnimationIntensity: Double = 0.0
    
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
        if self.isConnected {
            // 연결된 상태에서는 기기 이름 요청
            // iPhone의 응답이 있을 떄 그때 connectedDevice가 업데이트됨
            // 처음 연결시에는 "연결 안됨"으로 유지
            if self.pairedDeviceName == nil {
                requestDeviceNameFromiPhone()
            } else {
                // 이미 기기 이름을 받았다면 사용
                self.connectedDevice = self.pairedDeviceName ?? "연결 안됨"
                print("Watch: ✅ 연결된 기기 타입 설정: \(self.connectedDevice)")
            }
        } else {
            // 연결되지 않은 상태
            self.connectedDevice = "연결 안됨"
            self.pairedDeviceName = nil // 연결이 끊기면 저장된 기기 이름 초기화
        }
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
    // 이 함수는 사용하지 않음 - 비활성화
    private func getConnectedDeviceType() -> String {
        // iPhone에 기기 모델명 요청 - 연결시 자동 요청으로 변경
        // requestDeviceNameFromiPhone()
        
        // 기본값 수정 (연결 안됨 메시지로)
        return self.pairedDeviceName ?? "연결 안됨"
    }
    
    // iPhone에게 기기 모델명 요청
    private func requestDeviceNameFromiPhone() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            print("Watch: ⚠️ iPhone이 도달 불가능한 상태, 기기 이름 요청 불가")
            return
        }
        
        let message = [
            "action": "requestDeviceModelName",
            "timestamp": Int(Date().timeIntervalSince1970)
        ] as [String : Any]
        
        // replyHandler와 errorHandler를 명시적으로 구현한 sendMessage 사용
        WCSession.default.sendMessage(message, replyHandler: { reply in
            print("Watch: ✅ iPhone으로부터 응답 받음: \(reply)")
            
            if let deviceName = reply["deviceName"] as? String {
                print("Watch: 📱 기기 이름 수신: \(deviceName)")
                
                // 중요: UI 업데이트는 반드시 메인 스레드에서 수행
                DispatchQueue.main.async {
                    // 기기 이름 업데이트 및 UI 갱신
                    self.pairedDeviceName = deviceName
                    self.connectedDevice = deviceName
                    
                    print("Watch: ✅ 기기 이름 업데이트 (메인 스레드): \(deviceName)")
                    
                    // UI가 확실히 갱신되도록 상태 업데이트
                    if !self.isConnected {
                        self.isConnected = true
                    }
                }
            }
        }, errorHandler: { error in
            print("Watch: ❌ 기기 이름 요청 오류: \(error.localizedDescription)")
        })
        
        print("Watch: 📤 iPhone에 기기 모델명 요청 전송")
    }
    
    private func handleMessageFromiPhone(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        
        switch action {
        // 필요 없어진 deviceNameResponse 케이스 제거
        // 이제 디바이스 이름은 직접 getConnectedDeviceType()에서 제공
            
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
            // 🔥 세션 요약 화면으로 자동 전환
            self.shouldShowSessionSummary = true
            self.showHapticNotification(message: "세션이 종료되었습니다. 결과 화면으로 전환합니다.")
            print("🔄 Watch: 세션 종료됨, 세션 요약 화면으로 전환 플래그 설정")
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
            print("Watch: Unhandled action from iPhone: \(action)")
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
        
        // 🎨 시각적 피드백 트리거
        triggerVisualFeedback(patternId: patternId, category: category)
        
        // 5초 후 자동으로 알림 닫기
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.showHapticFeedback = false
            self.showVisualFeedback = false
        }
    }
    
    // 🎯 HaptiTalk MVP 햅틱 패턴 (설계 문서 기반)
    private func triggerMVPHapticPattern(patternId: String, pattern: String) {
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        
        print("🎯 Watch: MVP 햅틱 패턴 실행 시작 - ID: \(patternId), 패턴: \(pattern)")
        
        switch patternId {
        case "S1":  // 속도 조절 패턴 - 빠른 3회 연속 진동 (100ms 간격)
            playSpeedControlPattern(device: device)
        case "L1":  // 경청 강화 패턴 - 점진적 강도 증가 3회 진동
            playListeningPattern(device: device)
        case "F1":  // 주제 전환 패턴 - 더 긴 진동으로 수정
            playTopicChangePattern(device: device)
        case "R1":  // 호감도 상승 패턴 - 점진적 증가 파동형 3회
            playLikabilityUpPattern(device: device)
        case "F2":  // 침묵 관리 패턴 - 부드러운 2회 탭 (300ms 간격)
            playSilenceManagementPattern(device: device)
        case "S2":  // 음량 조절 패턴 - 강도 변화 2회 진동
            playVolumeControlPattern(device: device, pattern: pattern)
        case "R2":  // 관심도 하락 패턴 - 모든 단계를 강하게 수정
            playInterestDownPattern(device: device)
        case "L3":  // 질문 제안 패턴 - 2회 짧은 탭 + 1회 긴 진동
            playQuestionSuggestionPattern(device: device)
        default:
            // 기본 패턴 - 표준 알림
            print("🎯 Watch: 기본 햅틱 패턴 실행")
            playDefaultHaptic(device: device)
        }
        
        print("🎯 Watch: MVP 햅틱 패턴 실행 완료 - ID: \(patternId)")
        #endif
    }
    
    // 📊 S1: 속도 조절 패턴 (메타포: 빠른 심장 박동) - 🔥 확실한 간격 보장
    private func playSpeedControlPattern(device: WKInterfaceDevice) {
        print("🎯 Watch: S1 속도조절 패턴 실행 시작 - 3회 진동 예정")
        
        // 첫 번째 강한 진동
        device.play(.notification)
        print("🔥 S1: 1/3 진동 실행 완료")
        
        // 두 번째 강한 진동 (0.8초 후 - 매우 긴 간격)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            device.play(.notification)
            print("🔥 S1: 2/3 진동 실행 완료")
        }
        
        // 세 번째 강한 진동 (1.6초 후 - 매우 긴 간격)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            device.play(.notification)
            print("🔥 S1: 3/3 진동 실행 완료 - 패턴 완료!")
        }
    }
    
    // 📊 L1: 경청 강화 패턴 (메타포: 점진적 주의 집중) - 🔥 확실한 간격 보장
    private func playListeningPattern(device: WKInterfaceDevice) {
        print("🎯 Watch: L1 경청강화 패턴 실행 시작 - 4단계 예정")
        
        // 1단계: 매우 약한 단일 탭
        device.play(.click)
        print("🔥 L1: 1/4 매우 약함 실행 완료")
        
        // 2단계: 약간 강한 단일 탭 (1.0초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            device.play(.directionUp)
            print("🔥 L1: 2/4 약간 강함 실행 완료")
        }
        
        // 3단계: 강한 단일 탭 (2.0초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            device.play(.notification)
            print("🔥 L1: 3/4 강함 실행 완료")
        }
        
        // 4단계: 매우 강한 더블 탭 (3.0초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            device.play(.notification)
            print("🔥 L1: 4/4-1 매우 강함 첫번째")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                device.play(.notification)
                print("🔥 L1: 4/4-2 매우 강함 두번째 - 패턴 완료!")
            }
        }
    }
    
    // 📊 F1: 주제 전환 패턴 (메타포: 페이지 넘기기) - 🔥 더 긴 진동으로 수정
    private func playTopicChangePattern(device: WKInterfaceDevice) {
        print("🎯 Watch: F1 주제전환 패턴 실행 시작 - 2회 매우 긴 진동 예정")
        
        // 첫 번째 매우 긴 진동 (더 강하고 길게)
        device.play(.notification)
        print("🔥 F1: 1/2 매우 긴 진동 실행 완료")
        
        // 긴 휴지 후 두 번째 매우 긴 진동 (1.5초 후 - 매우 긴 간격)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            device.play(.notification)
            print("🔥 F1: 2/2 매우 긴 진동 실행 완료 - 패턴 완료!")
        }
    }
    
    // 📊 R1: 호감도 상승 패턴 (메타포: 상승하는 파동) - 🔥 확실한 간격 보장
    private func playLikabilityUpPattern(device: WKInterfaceDevice) {
        print("🎯 Watch: R1 호감도상승 패턴 실행 시작 - 4단계 상승 예정")
        
        // 1단계: 매우 부드러운 시작
        device.play(.click)
        print("🔥 R1: 1/4 부드러운 시작 실행 완료")
        
        // 2단계: 중간 상승 (0.7초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            device.play(.directionUp)
            print("🔥 R1: 2/4 중간 상승 실행 완료")
        }
        
        // 3단계: 행복한 진동 (1.4초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            device.play(.success)
            print("🔥 R1: 3/4 행복한 진동 실행 완료")
        }
        
        // 4단계: 지속되는 행복감 더블 탭 (2.1초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            device.play(.success)
            print("🔥 R1: 4/4-1 행복감 첫번째")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                device.play(.success)
                print("🔥 R1: 4/4-2 행복감 두번째 - 패턴 완료!")
            }
        }
    }
    
    // 📊 F2: 침묵 관리 패턴 (메타포: 부드러운 알림) - 🔥 간격 단축
    private func playSilenceManagementPattern(device: WKInterfaceDevice) {
        print("🎯 Watch: F2 침묵관리 패턴 실행 시작 - 2회 중간 강도 탭 예정")
        
        // 첫 번째 중간 강도 진동 (더 강하게)
        device.play(.directionUp)
        print("🔥 F2: 1/2 중간 강도 진동 실행 완료")
        
        // 짧은 침묵 후 두 번째 중간 강도 진동 (1.2초 후 - 간격 단축)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            device.play(.directionUp)
            print("🔥 F2: 2/2 중간 강도 진동 실행 완료 - 패턴 완료!")
        }
    }
    
    // 📊 S2: 음량 조절 패턴 (메타포: 음파 증폭/감소) - 🔥 확실한 간격 보장
    private func playVolumeControlPattern(device: WKInterfaceDevice, pattern: String) {
        print("🎯 Watch: S2 음량조절 패턴 실행 시작 - 3단계 강도 변화 예정")
        
        // 매우 약한 시작 (단일)
        device.play(.click)
        print("🔥 S2: 1/3 매우 약한 단일 탭 실행 완료")
        
        // 중간 강도 (0.8초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            device.play(.directionUp)
            print("🔥 S2: 2/3 중간 강도 탭 실행 완료")
        }
        
        // 매우 강한 마지막 (1.6초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            device.play(.notification)
            print("🔥 S2: 3/3 매우 강한 탭 실행 완료 - 패턴 완료!")
        }
    }
    
    // 📊 R2: 관심도 하락 패턴 (메타포: 경고 알림) - 🔥 더 확실한 7회 진동
    private func playInterestDownPattern(device: WKInterfaceDevice) {
        print("🎯 Watch: R2 관심도하락 패턴 실행 시작 - 총 7회 확실한 경고 예정")
        
        // 1회 강한 경고
        device.play(.notification)
        print("🔥 R2: 1/7 강한 경고 실행 완료")
        
        // 2회 매우 강한 경고 (0.5초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            device.play(.notification)
            print("🔥 R2: 2/7 매우 강한 경고 실행 완료")
        }
        
        // 3회 매우 강한 경고 (1.0초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            device.play(.notification)
            print("🔥 R2: 3/7 매우 강한 경고 실행 완료")
        }
        
        // 4회 더블 경고 시작 (1.5초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            device.play(.notification)
            print("🔥 R2: 4/7 더블 경고 첫번째")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                device.play(.notification)
                print("🔥 R2: 5/7 더블 경고 두번째")
            }
        }
        
        // 5회 트리플 경고 시작 (2.2초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            device.play(.notification)
            print("🔥 R2: 6/7 트리플 경고 첫번째")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                device.play(.notification)
                print("🔥 R2: 7/7 트리플 경고 두번째 - 패턴 완료!")
            }
        }
    }
    
    // 📊 L3: 질문 제안 패턴 (메타포: 물음표 형태) - 🔥 더 강한 진동으로 수정
    private func playQuestionSuggestionPattern(device: WKInterfaceDevice) {
        print("🎯 Watch: L3 질문제안 패턴 실행 시작 - 물음표 형태 4단계 예정")
        
        // 첫 번째 중간 강도 점 (더 강하게)
        device.play(.directionUp)
        print("🔥 L3: 1/4 중간 강도 점 실행 완료")
        
        // 두 번째 중간 강도 점 (0.6초 후, 더 강하게)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            device.play(.directionUp)
            print("🔥 L3: 2/4 중간 강도 점 실행 완료")
        }
        
        // 긴 휴지 후 물음표 마침표 - 매우 강한 더블 진동 (1.8초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            device.play(.notification)
            print("🔥 L3: 3/4-1 물음표 마침표 첫번째")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                device.play(.notification)
                print("🔥 L3: 3/4-2 물음표 마침표 두번째")
            }
        }
        
        // 질문의 여운 - 중간 강도 (2.8초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            device.play(.success)
            print("🔥 L3: 4/4 질문의 여운 (중간 강도) 실행 완료 - 패턴 완료!")
        }
    }
    
    // 🎨 패턴별 시각적 피드백 트리거
    private func triggerVisualFeedback(patternId: String, category: String) {
        print("🎨 Watch: 시각적 피드백 트리거 시작 - 패턴: \(patternId), 카테고리: \(category)")
        
        currentVisualPattern = patternId
        
        // 카테고리별 기본 색상 설정
        switch category {
        case "speaker":
            visualPatternColor = Color.orange
        case "listener":
            visualPatternColor = Color.blue
        case "flow":
            visualPatternColor = Color.green
        case "reaction":
            visualPatternColor = Color.pink
        default:
            visualPatternColor = Color.gray
        }
        
        // 패턴별 애니메이션 강도 설정
        switch patternId {
        case "S1": // 속도 조절 - 빠른 펄스
            visualAnimationIntensity = 1.0
        case "L1": // 경청 강화 - 점진적 증가
            visualAnimationIntensity = 0.8
        case "F1": // 주제 전환 - 긴 페이드
            visualAnimationIntensity = 0.6
        case "R1": // 호감도 상승 - 상승 파동
            visualAnimationIntensity = 0.9
        case "F2": // 침묵 관리 - 부드러운 펄스
            visualAnimationIntensity = 0.4
        case "S2": // 음량 조절 - 변화하는 크기
            visualAnimationIntensity = 0.7
        case "R2": // 관심도 하락 - 강한 경고
            visualAnimationIntensity = 1.0
        case "L3": // 질문 제안 - 물음표 형태
            visualAnimationIntensity = 0.5
        default:
            visualAnimationIntensity = 0.5
        }
        
        showVisualFeedback = true
        print("🎨 Watch: 시각적 피드백 표시 시작 - 색상: \(visualPatternColor), 강도: \(visualAnimationIntensity)")
        
        // 🔥 패턴별 실제 햅틱 지속시간에 맞춤 시각적 피드백 지속시간
        let duration: Double
        switch patternId {
        case "S1": // 속도 조절: 3회 진동, 0.8+1.6=2.4초 + 여유 0.6초
            duration = 3.5
        case "L1": // 경청 강화: 4단계, 1.0+2.0+3.0=6.0초 + 여유 1.0초
            duration = 7.5
        case "F1": // 주제 전환: 2회 긴 진동, 1.5초 + 여유 1.0초
            duration = 3.0
        case "R1": // 호감도 상승: 4단계, 0.7+1.4+2.1=4.2초 + 여유 0.8초
            duration = 5.5
        case "F2": // 침묵 관리: 2회, 1.2초 + 여유 0.8초
            duration = 2.5
        case "S2": // 음량 조절: 3단계, 0.8+1.6=2.4초 + 여유 0.6초
            duration = 3.5
        case "R2": // 관심도 하락: 7회 진동, 총 약 3.0초 + 여유 1.0초
            duration = 4.5
        case "L3": // 질문 제안: 4단계, 0.6+1.8+2.8=5.2초 + 여유 0.8초
            duration = 6.5
        default:
            duration = 4.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            print("🎨 Watch: 시각적 피드백 자동 종료 - 패턴: \(patternId), 지속시간: \(duration)초")
            self.showVisualFeedback = false
        }
    }
    
    // MARK: - 세션뷰 햅틱 구독 관리
    /// 세션뷰에서 햅틱 피드백 이벤트를 처리하기 위한 구독 설정
    func setupSessionViewHapticSubscription(messageHandler: @escaping (String) -> Void) {
        // 기존 구독 취소
        sessionViewHapticCancellable?.cancel()
        
        // 햅틱 피드백 이벤트 구독
        sessionViewHapticCancellable = $showHapticFeedback
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // 햅틱 메시지 처리하기 위한 콜백 호출
                messageHandler(self.hapticFeedbackMessage)
                
                // 햅틱 피드백 플래그 초기화
                self.showHapticFeedback = false
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