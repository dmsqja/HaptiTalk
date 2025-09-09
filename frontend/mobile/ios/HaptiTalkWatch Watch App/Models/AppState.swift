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
    @Published var sessionType: String = "발표"
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
    @Published var shouldCloseSession: Bool = false
    
    // 🎨 시각적 피드백 상태 변수들
    @Published var showVisualFeedback: Bool = false
    @Published var currentVisualPattern: String = ""
    @Published var visualPatternColor: Color = .blue
    @Published var visualAnimationIntensity: Double = 0.0
    
    // 🎨 애니메이션 타이머
    private var animationTimer: Timer?
    
    // 더미 데이터 초기화
    override init() {
        super.init()
        setupWatchConnectivity()
        
        recentSessions = [
            Session(id: UUID(), name: "발표 모드", date: Date().addingTimeInterval(-86400), duration: 1800)
        ]
        
        sessionSummaries = [
            SessionSummary(
                id: UUID(),
                sessionMode: "발표 모드",
                totalTime: "1:32:05",
                mainEmotion: "긍정적",
                likeabilityPercent: "88%",
                coreFeedback: "핵심 메시지 전달이 명확했으며, 청중과의 소통이 매우 효과적이었습니다.",
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
            self.shouldCloseSession = true  // 🔄 세션 화면 자동 종료 트리거
            self.showHapticNotification(message: "세션이 종료되었습니다")
            print("🔄 Watch: 세션 종료됨, 화면 자동 종료 및 플래그 리셋")
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
                
                // 🔥 sessionType 추출 및 업데이트
                if let receivedSessionType = message["sessionType"] as? String {
                    self.sessionType = receivedSessionType
                    print("🔥 Watch: 세션 타입 업데이트됨 - \(receivedSessionType)")
                }
                
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
        case "initializeVisualFeedback":
            // 🔄 시각적 피드백 초기화
            print("🔄 Watch: 시각적 피드백 초기화 수신")
            self.showVisualFeedback = false
            self.currentVisualPattern = ""
            self.visualAnimationIntensity = 0.0
            self.visualPatternColor = .blue
            print("🔄 Watch: 시각적 피드백 상태 초기화 완료")
        case "clearVisualFeedback":
            // 🧹 시각적 피드백 클리어
            print("🧹 Watch: 시각적 피드백 클리어 수신")
            self.showVisualFeedback = false
            self.currentVisualPattern = ""
            self.visualAnimationIntensity = 0.0
            print("🧹 Watch: 시각적 피드백 클리어 완료")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
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
        // 🎯 세션 모드별 동적 시각적 메시지 생성 (기존 message 무시)
        let dynamicMessage = generateSessionSpecificMessage(
            patternId: patternId, 
            category: category, 
            sessionType: sessionType
        )
        
        hapticFeedbackMessage = dynamicMessage
        showHapticFeedback = true
        
        // 🎯 HaptiTalk MVP 햅틱 패턴 (설계 문서 기반)
        triggerMVPHapticPattern(patternId: patternId, pattern: pattern)
        
        // 🎨 시각적 피드백 트리거 (세션 타입 포함)
        triggerVisualFeedback(patternId: patternId, category: category, sessionType: sessionType)
        
        // 🔥 3초 후 자동으로 알림 닫기
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            print("🔥 Watch: 3초 후 시각적 피드백 자동 숨김")
            self.showHapticFeedback = false
            self.stopVisualFeedback()
        }
        
        // 🔥 추가 안전장치: 5초 후 강제 초기화
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.showVisualFeedback {
                print("🚨 Watch: 5초 후 강제 시각적 피드백 초기화")
                self.showHapticFeedback = false
                self.stopVisualFeedback()
                self.hapticFeedbackMessage = ""
            }
        }
    }
    
    // 🎯 HaptiTalk MVP 햅틱 패턴 (설계 문서 기반)
    private func triggerMVPHapticPattern(patternId: String, pattern: String) {
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        
        print("🎯 Watch: MVP 햅틱 패턴 실행 시작 - ID: \(patternId), 패턴: \(pattern)")
        print("🎯 Watch: 햅틱 실행 전 디바이스 상태 확인 완료")
        
        switch patternId {
        case "D1": 
            print("🎯 Watch: D1 패턴 실행 중...")
            playSpeedControlPattern(device: device)      // 전달력: 속도 조절
            print("🎯 Watch: D1 패턴 실행 완료")
        case "C1": 
            print("🎯 Watch: C1 패턴 실행 중...")
            playConfidenceBoostPattern(device: device)   // 자신감: 상승
            print("🎯 Watch: C1 패턴 실행 완료")
        case "C2": 
            print("🎯 Watch: C2 패턴 실행 중...")
            playConfidenceAlertPattern(device: device)   // 자신감: 하락 (안정화)
            print("🎯 Watch: C2 패턴 실행 완료")
        case "F1": 
            print("🎯 Watch: F1 패턴 실행 중...")
            playFillerWordAlertPattern(device: device)   // 필러워드 감지
            print("🎯 Watch: F1 패턴 실행 완료")
        // R1 패턴 제거됨 - 새로운 4개 핵심 패턴 설계(D1, C1, C2, F1)에 포함되지 않음
        default: 
            print("🎯 Watch: 기본 햅틱 패턴 실행 중...")
            playDefaultHaptic(device: device)
            print("🎯 Watch: 기본 햅틱 패턴 실행 완료")
        }
        
        print("🎯 Watch: MVP 햅틱 패턴 실행 완료 - ID: \(patternId)")
        #endif
    }
    
    // 📊 D1: 속도 조절 패턴 (급한 리듬 - 3연타)
    private func playSpeedControlPattern(device: WKInterfaceDevice) {
        print("🎯 Watch: D1 햅틱 실행 - 첫 번째 진동")
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("🎯 Watch: D1 햅틱 실행 - 두 번째 진동")
            device.play(.notification)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            print("🎯 Watch: D1 햅틱 실행 - 세 번째 진동")
            device.play(.notification)
        }
    }
    
    // 💪 C1: 자신감 상승 패턴 (상승 웨이브)
    private func playConfidenceBoostPattern(device: WKInterfaceDevice) {
        print("🎯 Watch: C1 햅틱 실행 - 첫 번째 진동 (click)")
        device.play(.click)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("🎯 Watch: C1 햅틱 실행 - 두 번째 진동 (directionUp)")
            device.play(.directionUp)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎯 Watch: C1 햅틱 실행 - 세 번째 진동 (success)")
            device.play(.success)
        }
    }
    
    // 🧘 C2: 자신감 하락 패턴 (부드러운 경고)
    private func playConfidenceAlertPattern(device: WKInterfaceDevice) {
        print("🎯 Watch: C2 햅틱 실행 - 첫 번째 진동")
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎯 Watch: C2 햅틱 실행 - 두 번째 진동")
            device.play(.notification)
        }
    }
    
    // 🗣️ F1: 필러워드 감지 패턴 (가벼운 지적)
    private func playFillerWordAlertPattern(device: WKInterfaceDevice) {
        print("🎯 Watch: F1 햅틱 실행 - 첫 번째 진동")
        device.play(.click)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🎯 Watch: F1 햅틱 실행 - 두 번째 진동")
            device.play(.click)
        }
    }
    
    // R1 패턴 제거됨 - 새로운 4개 핵심 패턴 설계에 포함되지 않음

    // 🎯 세션 모드별 동적 메시지 생성 (새로운 4개 패턴)
    private func generateSessionSpecificMessage(
        patternId: String, 
        category: String, 
        sessionType: String
    ) -> String {
        let currentSession = sessionType.isEmpty ? "발표" : sessionType
        
        switch patternId {
        case "D1": // 전달력: 말이 빠르다
            return currentSession == "발표" ? 
                "천천히 말해보세요" : 
                "천천히 답변해보세요"
                
        case "C1": // 자신감: 상승
            return currentSession == "발표" ? 
                "훌륭한 발표 자신감이에요!" : 
                "확신감 있는 답변이에요!"
                
        case "C2": // 자신감: 하락
            return currentSession == "발표" ? 
                "더 자신감 있게 발표하세요!" :
                "더 자신감 있게 답변하세요!"
                
        case "F1": // 필러워드 감지
            return currentSession == "발표" ? 
                "\"음\", \"어\" 등을 줄여보세요" : 
                "\"음\", \"어\" 등을 줄여보세요"
        
        default:
            return "📱 피드백이 도착했습니다"
        }
    }
    
    // 🎨 패턴별 시각적 피드백 트리거 (세션 타입 포함)
    private func triggerVisualFeedback(patternId: String, category: String, sessionType: String? = nil) {
        print("🎨 Watch: 시각적 피드백 트리거 시작 - 패턴: \(patternId), 카테고리: \(category), 세션: \(sessionType ?? "기본")")
        print("🎨 Watch: 현재 showVisualFeedback 상태: \(showVisualFeedback)")
        
        // 기존 애니메이션 타이머 정리
        stopAnimationTimer()
        print("🎨 Watch: 기존 애니메이션 타이머 정리 완료")
        
        currentVisualPattern = patternId
        print("🎨 Watch: currentVisualPattern 설정: \(patternId)")
        
        // 새로운 4개 핵심 패턴 카테고리별 색상 설정
        switch category {
        case "delivery":
            visualPatternColor = Color.orange
            print("🎨 Watch: delivery 카테고리 - 오렌지 색상 설정")
        case "confidence":
            visualPatternColor = patternId == "C2" ? Color.purple : Color.green
            print("🎨 Watch: confidence 카테고리 - \(patternId == "C2" ? "보라색" : "초록색") 색상 설정")
        case "filler":
            visualPatternColor = Color.blue
            print("🎨 Watch: filler 카테고리 - 파란색 색상 설정")
        default:
            visualPatternColor = Color.gray
            print("🎨 Watch: 알 수 없는 카테고리 - 회색 색상 설정")
        }
        
        print("🎨 Watch: showVisualFeedback을 true로 설정하기 전...")
        showVisualFeedback = true
        print("🎨 Watch: showVisualFeedback을 true로 설정 완료: \(showVisualFeedback)")
        
        // 🎨 애니메이션 타이머 시작
        startAnimationTimer()
        print("🎨 Watch: 애니메이션 타이머 시작 완료")
        
        print("🎨 Watch: 시각적 피드백 표시 시작 - 색상: \(visualPatternColor)")
        
        // 🔥 패턴별 실제 햅틱 지속시간에 맞춤 시각적 피드백 지속시간
        let duration: Double
        switch patternId {
        case "D1": duration = 3.5
        case "C1": duration = 3.0
        case "C2": duration = 2.5
        case "F1": duration = 4.0
        default: duration = 4.0
        }
        
        print("🎨 Watch: \(duration)초 후 자동 종료 타이머 설정")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            print("🎨 Watch: 시각적 피드백 자동 종료 - 패턴: \(patternId), 지속시간: \(duration)초")
            self.stopVisualFeedback()
        }
    }
    
    // 🎨 애니메이션 타이머 시작
    private func startAnimationTimer() {
        var currentTime: Double = 0.0
        let updateInterval: Double = 0.016 // 60 FPS
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // 사인파를 사용해서 부드러운 애니메이션 생성
                self.visualAnimationIntensity = (sin(currentTime * 2.0) + 1.0) / 2.0
                currentTime += updateInterval
                
                // 애니메이션이 너무 길어지지 않도록 제한
                if currentTime > 100.0 {
                    currentTime = 0.0
                }
            }
        }
    }
    
    // 🎨 애니메이션 타이머 정지
    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
        visualAnimationIntensity = 0.0
    }
    
    // 🎨 시각적 피드백 완전 정지
    private func stopVisualFeedback() {
        stopAnimationTimer()
        showVisualFeedback = false
        currentVisualPattern = ""
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
