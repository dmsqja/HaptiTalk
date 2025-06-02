import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var watchChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Method Channel 설정
    let controller = window?.rootViewController as! FlutterViewController
    watchChannel = FlutterMethodChannel(name: "com.haptitalk/watch", 
                                       binaryMessenger: controller.binaryMessenger)
    
    watchChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call: call, result: result)
    }
    
    // WatchConnectivity 설정
    setupWatchConnectivity()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupWatchConnectivity() {
    if WCSession.isSupported() {
      let session = WCSession.default
      print("=== iOS WCSession 초기 상태 ===")
      print("활성화 상태: \(session.activationState.rawValue)")
      print("워치 앱 설치됨: \(session.isWatchAppInstalled)")
      print("페어링 상태: \(session.isPaired)")
      print("통신 가능 상태: \(session.isReachable)")
      print("===========================")
      
      session.delegate = self
      session.activate()
      print("iOS: WCSession setup completed")
      
      // 초기 연결 상태를 Flutter에 알림
      DispatchQueue.main.async { [weak self] in
        self?.notifyWatchConnectionStatus()
      }
    } else {
      print("iOS: WatchConnectivity not supported")
    }
  }
  
  private func notifyWatchConnectionStatus() {
    let session = WCSession.default
    
    // ⚠️ isWatchAppInstalled는 Apple 버그로 인해 부정확할 수 있음
    // Watch의 실제 응답으로만 연결 상태 판단
    let status = [
      "isSupported": WCSession.isSupported(),
      "isPaired": session.isPaired,
      "isWatchAppInstalled": session.isPaired, // 🔧 임시로 isPaired 값 사용
      "isReachable": session.isReachable,
      "activationState": session.activationState.rawValue
    ] as [String : Any]
    
    watchChannel?.invokeMethod("watchConnectionStatus", arguments: status)
    print("iOS: ⚠️ isWatchAppInstalled 우회 - Notified connection status - \(status)")
  }
  
  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startSession":
      if let args = call.arguments as? [String: Any],
         let sessionType = args["sessionType"] as? String {
        sendToWatch(message: ["action": "startSession", "sessionType": sessionType])
        result("Session started")
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "sessionType is required", details: nil))
      }
    case "stopSession":
      sendToWatch(message: ["action": "stopSession"])
      result("Session stopped")
    case "sendHapticFeedback":
      if let args = call.arguments as? [String: Any],
         let message = args["message"] as? String {
        sendToWatch(message: ["action": "hapticFeedback", "message": message])
        result("Haptic sent")
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "message is required", details: nil))
      }
    case "sendHapticFeedbackWithPattern":
      // 🎯 HaptiTalk 설계 문서 기반 패턴별 햅틱 전송
      if let args = call.arguments as? [String: Any],
         let message = args["message"] as? String,
         let pattern = args["pattern"] as? String,
         let category = args["category"] as? String,
         let patternId = args["patternId"] as? String {
        
        var watchMessage: [String: Any] = [
          "action": "hapticFeedbackWithPattern",
          "message": message,
          "pattern": pattern,
          "category": category,
          "patternId": patternId
        ]
        
        if let timestamp = args["timestamp"] as? Int64 {
          watchMessage["timestamp"] = timestamp
        }
        
        sendToWatch(message: watchMessage)
        result("Pattern haptic sent")
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "message, pattern, category, patternId are required", details: nil))
      }
    case "sendRealtimeAnalysis":
      if let args = call.arguments as? [String: Any] {
        var message: [String: Any] = ["action": "realtimeAnalysis"]
        message["likability"] = args["likability"]
        message["interest"] = args["interest"]
        message["speakingSpeed"] = args["speakingSpeed"]
        message["emotion"] = args["emotion"]
        message["feedback"] = args["feedback"]
        message["elapsedTime"] = args["elapsedTime"]
        sendToWatch(message: message)
        result("Realtime analysis sent")
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "analysis data is required", details: nil))
      }
    case "isWatchConnected":
      let session = WCSession.default
      let isConnected = session.isPaired && session.isWatchAppInstalled
      result(isConnected)
    case "testConnection":
      let session = WCSession.default
      let status = [
        "isSupported": WCSession.isSupported(),
        "isPaired": session.isPaired,
        "isWatchAppInstalled": session.isPaired, // 🔧 isWatchAppInstalled 우회
        "isReachable": session.isReachable,
        "activationState": session.activationState.rawValue
      ] as [String : Any]
      result(status)
    case "forceReconnect":
      // WCSession 강제 재시작
      forceWatchReconnection()
      result("Reconnection attempted")
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func sendToWatch(message: [String: Any]) {
    let session = WCSession.default
    print("iOS: Attempting to send message - \(message)")
    
    // 기본적인 연결 상태만 체크 (isWatchAppInstalled 제외)
    guard session.activationState == .activated,
          session.isPaired else {
      print("iOS: Session not ready - activationState: \(session.activationState.rawValue), isPaired: \(session.isPaired)")
      return
    }
    
    // isWatchAppInstalled가 부정확할 수 있으므로 실제 전송을 시도
    print("iOS: 🚀 Watch 앱 설치 상태 무시하고 메시지 전송 시도")
    
    if session.isReachable {
      session.sendMessage(message, replyHandler: { response in
        print("iOS: ✅ Watch가 응답함! 실제로 연결됨 - \(response)")
      }) { error in
        print("iOS: ❌ 메시지 전송 실패 - \(error.localizedDescription)")
        
        // 메시지 전송 실패 시 applicationContext로 재시도
        self.sendViaApplicationContext(message)
      }
    } else {
      print("iOS: Watch가 reachable하지 않음, applicationContext로 전송")
      sendViaApplicationContext(message)
    }
  }
  
  private func sendViaApplicationContext(_ message: [String: Any]) {
    do {
      try WCSession.default.updateApplicationContext(message)
      print("iOS: Sent via applicationContext")
    } catch {
      print("iOS: Failed to update applicationContext - \(error.localizedDescription)")
    }
  }
  
  private func forceWatchReconnection() {
    print("iOS: 🔄 WCSession 강제 재연결 시작")
    
    let session = WCSession.default
    
    // 기존 세션 상태 로그
    print("iOS: 현재 상태 - activated: \(session.activationState.rawValue), paired: \(session.isPaired), installed: \(session.isWatchAppInstalled), reachable: \(session.isReachable)")
    
    // 강제 재활성화 (이미 활성화되어 있어도 다시 시도)
    if WCSession.isSupported() {
      session.activate()
      print("iOS: ✅ WCSession 재활성화 완료")
      
      // 5초 후 상태 다시 확인
      DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
        self?.notifyWatchConnectionStatus()
        print("iOS: 🔍 재연결 후 상태 확인 완료")
      }
    }
  }
}

// MARK: - WCSessionDelegate
extension AppDelegate: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    DispatchQueue.main.async { [weak self] in
      print("iOS: Session activation completed - state: \(activationState.rawValue)")
      if let error = error {
        print("iOS: Session activation error - \(error.localizedDescription)")
      }
      self?.notifyWatchConnectionStatus()
    }
  }
  
  func sessionDidBecomeInactive(_ session: WCSession) {
    print("Watch session became inactive")
  }
  
  func sessionDidDeactivate(_ session: WCSession) {
    print("Watch session deactivated")
    // 재활성화
    session.activate()
  }
  
  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async { [weak self] in
      print("iOS: Reachability changed - isReachable: \(session.isReachable)")
      self?.notifyWatchConnectionStatus()
    }
  }
  
  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    print("Received message from watch: \(message)")
    DispatchQueue.main.async { [weak self] in
      self?.watchChannel?.invokeMethod("watchMessage", arguments: message)
    }
  }
  
  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
    print("Received application context from watch: \(applicationContext)")
    DispatchQueue.main.async { [weak self] in
      self?.watchChannel?.invokeMethod("watchMessage", arguments: applicationContext)
    }
  }
}
