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
        
        if let sessionType = args["sessionType"] as? String {
          watchMessage["sessionType"] = sessionType
        }
        
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
  
  // iPhone 모델명 가져오기 (기기 ID를 사람이 읽을 수 있는 모델명으로 변환)
  private func getDeviceModelName() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return identifier }
      return identifier + String(UnicodeScalar(UInt8(value)))
    }
    
    print("iOS: 🔍 현재 기기 식별자 초기값: \(identifier)")
    
    // 기기 식별자를 모델명으로 변환
    var modelName: String
    switch identifier {
      // 초기 iPhone 모델
      case "iPhone1,1": modelName = "iPhone"
      case "iPhone1,2": modelName = "iPhone 3G"
      case "iPhone2,1": modelName = "iPhone 3GS"
      
      // iPhone 4 시리즈
      case "iPhone3,1": modelName = "iPhone 4"
      case "iPhone3,2": modelName = "iPhone 4 GSM Rev A"
      case "iPhone3,3": modelName = "iPhone 4 CDMA"
      case "iPhone4,1": modelName = "iPhone 4S"
      
      // iPhone 5 시리즈
      case "iPhone5,1": modelName = "iPhone 5 (GSM)"
      case "iPhone5,2": modelName = "iPhone 5 (GSM+CDMA)"
      case "iPhone5,3": modelName = "iPhone 5C (GSM)"
      case "iPhone5,4": modelName = "iPhone 5C (Global)"
      case "iPhone6,1": modelName = "iPhone 5S (GSM)"
      case "iPhone6,2": modelName = "iPhone 5S (Global)"
      
      // iPhone 6 시리즈
      case "iPhone7,1": modelName = "iPhone 6 Plus"
      case "iPhone7,2": modelName = "iPhone 6"
      case "iPhone8,1": modelName = "iPhone 6s"
      case "iPhone8,2": modelName = "iPhone 6s Plus"
      case "iPhone8,4": modelName = "iPhone SE (1세대)"
      
      // iPhone 7 시리즈
      case "iPhone9,1": modelName = "iPhone 7"
      case "iPhone9,2": modelName = "iPhone 7 Plus"
      case "iPhone9,3": modelName = "iPhone 7"
      case "iPhone9,4": modelName = "iPhone 7 Plus"
      
      // iPhone 8 & X 시리즈
      case "iPhone10,1": modelName = "iPhone 8"
      case "iPhone10,2": modelName = "iPhone 8 Plus"
      case "iPhone10,3": modelName = "iPhone X Global"
      case "iPhone10,4": modelName = "iPhone 8"
      case "iPhone10,5": modelName = "iPhone 8 Plus"
      case "iPhone10,6": modelName = "iPhone X GSM"
      
      // iPhone XS & XR 시리즈
      case "iPhone11,2": modelName = "iPhone XS"
      case "iPhone11,4": modelName = "iPhone XS Max"
      case "iPhone11,6": modelName = "iPhone XS Max Global"
      case "iPhone11,8": modelName = "iPhone XR"
      
      // iPhone 11 시리즈
      case "iPhone12,1": modelName = "iPhone 11"
      case "iPhone12,3": modelName = "iPhone 11 Pro"
      case "iPhone12,5": modelName = "iPhone 11 Pro Max"
      case "iPhone12,8": modelName = "iPhone SE (2세대)"
      
      // iPhone 12 시리즈
      case "iPhone13,1": modelName = "iPhone 12 Mini"
      case "iPhone13,2": modelName = "iPhone 12"
      case "iPhone13,3": modelName = "iPhone 12 Pro"
      case "iPhone13,4": modelName = "iPhone 12 Pro Max"
      
      // iPhone 13 시리즈
      case "iPhone14,2": modelName = "iPhone 13 Pro"
      case "iPhone14,3": modelName = "iPhone 13 Pro Max"
      case "iPhone14,4": modelName = "iPhone 13 Mini"
      case "iPhone14,5": modelName = "iPhone 13"
      case "iPhone14,6": modelName = "iPhone SE (3세대)"
      
      // iPhone 14 시리즈
      case "iPhone14,7": modelName = "iPhone 14"
      case "iPhone14,8": modelName = "iPhone 14 Plus"
      case "iPhone15,2": modelName = "iPhone 14 Pro"
      case "iPhone15,3": modelName = "iPhone 14 Pro Max"
      
      // iPhone 15 시리즈
      case "iPhone15,4": modelName = "iPhone 15"
      case "iPhone15,5": modelName = "iPhone 15 Plus"
      case "iPhone16,1": modelName = "iPhone 15 Pro"
      case "iPhone16,2": modelName = "iPhone 15 Pro Max"
      
      // iPhone 16 시리즈
      case "iPhone17,1": modelName = "iPhone 16 Pro"
      case "iPhone17,2": modelName = "iPhone 16 Pro Max"
      case "iPhone17,3": modelName = "iPhone 16"
      case "iPhone17,4": modelName = "iPhone 16 Plus"
      case "iPhone17,5": modelName = "iPhone 16e"
      default: 
        modelName = "iPhone"
        print("iOS: ⚠️ 알 수 없는 기기 식별자: \(identifier). 기본값 사용.")
    }
    
    print("iOS: 💻 변환된 모델명: \(modelName)")
    return modelName
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

  // MARK: - 워치로부터 메시지 수신 처리
  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    print("Received message from watch with replyHandler: \(message)")

    // 워치로부터 받은 메시지 처리
    if let action = message["action"] as? String {
      switch action {
      case "requestDeviceModelName":
        // 디바이스 이름을 가져와서 워치에 전송
        let deviceModel = getDeviceModelName()
        print("iOS: 🔍 현재 기기 식별자: \(UIDevice.current.model)")
        print("iOS: 📱 기본 이름 비교: UIDevice.name = \(UIDevice.current.name), 모델명 = \(deviceModel)")
        
        // 응답 데이터 준비
        let response = [
          "deviceName": deviceModel
        ]
        
        // 직접 replyHandler를 통해 응답
        replyHandler(response)
        print("iOS: 📤 기기 모델명 응답 전송 완료: \(deviceModel)")
      default:
        // 알 수 없는 액션 처리
        replyHandler(["error": "Unknown action: \(action)"])
        print("iOS: ⚠️ 알 수 없는 워치 메시지 액션: \(action)")
      }
    } else {
      // 액션이 없는 메시지 처리
      replyHandler(["error": "No action specified"])
      print("iOS: ⚠️ 액션이 지정되지 않은 워치 메시지")
    }
  }
  
  // 기존 didReceiveMessage 메서드도 유지 (replyHandler가 없는 메시지용)
  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    print("Received message from watch without replyHandler: \(message)")
    
    // Flutter로 메시지 전달
    DispatchQueue.main.async { [weak self] in
      self?.watchChannel?.invokeMethod("watchMessage", arguments: message)
    }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
    print("Received application context from watch: \(applicationContext)")
    
    // applicationContext를 통한 기기 이름 요청 처리
    if let action = applicationContext["action"] as? String, action == "requestDeviceName" {
      // iPhone의 모델명 가져오기
      let deviceModel = getDeviceModelName()
      print("iOS: 📱 applicationContext를 통한 기기 이름 요청 받음. 응답: \(deviceModel)")
      
      // 워치에 디바이스 이름 응답 전송
      let response = [
        "action": "deviceNameResponse",
        "deviceName": deviceModel
      ]
      
      // 응답도 applicationContext로 전송
      do {
        try session.updateApplicationContext(response)
        print("iOS: 📱 기기 이름 응답 전송 성공 (applicationContext 사용)")
      } catch {
        print("iOS: ❌ 기기 이름 응답 전송 실패 - \(error.localizedDescription)")
      }
    }
    
    // Flutter로 메시지 전달
    DispatchQueue.main.async { [weak self] in
      self?.watchChannel?.invokeMethod("watchMessage", arguments: applicationContext)
    }
  }
}