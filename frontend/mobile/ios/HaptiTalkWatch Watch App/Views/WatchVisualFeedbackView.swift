//
//  WatchVisualFeedbackView.swift
//  HaptiTalkWatch Watch App
//
//  Created on 5/15/25.
//

#if os(watchOS)
import SwiftUI
import WatchKit

@available(watchOS 6.0, *)
struct WatchVisualFeedbackView: View {
    @EnvironmentObject var appState: AppState
    @State private var animationOffset: CGFloat = 0
    @State private var animationScale: CGFloat = 1.0
    @State private var animationOpacity: Double = 1.0
    @State private var animationRotation: Double = 0
    @State private var animationPulse: CGFloat = 1.0
    @State private var animationWave: CGFloat = 0
    
    let screenSize = WKInterfaceDevice.current().screenBounds.size
    
    var body: some View {
        ZStack {
            // 🌟 전체화면 배경
            appState.visualPatternColor.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .animation(.easeInOut(duration: 0.5), value: appState.visualPatternColor)
            
            // 🎨 패턴별 시각적 효과 (화면 가득)
            buildPatternVisualEffect()
            
            // 📱 패턴 정보 오버레이 (아이콘 + 의미있는 텍스트) - 🔧 안정적인 중앙 정렬
            VStack(spacing: 6) {
                // 패턴 아이콘 (더 크고 눈에 띄게)
                getPatternIcon()
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 3, x: 1, y: 1)
                    .padding(.bottom, 4)
                
                // 패턴 설명 (더 눈에 띄게)
                Text(getPatternTitle())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 1, y: 1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.7))
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    )
                
                // 🔥 실제 햅틱 메시지 추가
                if !appState.hapticFeedbackMessage.isEmpty {
                    Text(appState.hapticFeedbackMessage)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.2))
                        )
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // 🔧 position 대신 frame으로 안정적인 중앙 정렬
            .opacity(1.0) // 확실히 보이도록
        }
        .onAppear {
            print("🎨 Watch: WatchVisualFeedbackView appeared - 패턴: \(appState.currentVisualPattern)")
            startPatternAnimation()
        }
        .onDisappear {
            print("🎨 Watch: WatchVisualFeedbackView disappeared")
            resetAnimations()
            // 🔥 AppState의 시각적 피드백 상태도 완전히 초기화
            DispatchQueue.main.async {
                appState.showVisualFeedback = false
                appState.currentVisualPattern = ""
                appState.visualAnimationIntensity = 0.0
                appState.hapticFeedbackMessage = ""
                print("🔥 Watch: onDisappear에서 모든 시각적 피드백 상태 완전 초기화")
            }
        }
        .onChange(of: appState.currentVisualPattern) { _, newPattern in
            // 패턴 변경 시 애니메이션 리셋 후 재시작으로 안정성 확보
            resetAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startPatternAnimation()
            }
        }
    }
    
    // 🎨 패턴별 아이콘 반환
    @ViewBuilder
    private func getPatternIcon() -> some View {
        switch appState.currentVisualPattern {
        case "S1": // 속도 조절
            Image(systemName: "speedometer")
        case "L1": // 경청 강화
            Image(systemName: "ear.fill")
        case "F1": // 주제 전환
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
        case "R1": // 호감도 상승
            Image(systemName: "heart.fill")
        case "F2": // 침묵 관리
            Image(systemName: "speaker.slash.fill")
        case "S2": // 음량 조절
            Image(systemName: "speaker.wave.3.fill")
        case "R2": // 관심도 하락
            Image(systemName: "exclamationmark.triangle.fill")
        case "L3": // 질문 제안
            Image(systemName: "questionmark.circle.fill")
        default:
            Image(systemName: "circle.fill")
        }
    }
    
    // 🎨 패턴별 제목 반환 (세션별 동적)
    private func getPatternTitle() -> String {
        let sessionType = appState.sessionType
        
        // 📊 세션 타입별 + 패턴별 제목 매핑 테이블
        let titleMapping: [String: [String: String]] = [
            // 🎤 발표 모드 제목
            "발표": [
                "S1": "속도 조절",
                "L1": "청중 소통 강화", 
                "F1": "관심도 하락",
                "R1": "자신감 상승",
                "F2": "휴지 관리",
                "S2": "음량 조절",
                "R2": "자신감 하락",
                "L3": "설득력 강화"
            ],
            
            // 👔 면접 모드 제목  
            "면접": [
                "S1": "답변 속도 조절",
                "L1": "면접관 경청",
                "F1": "면접 관심도 하락", 
                "R1": "면접 자신감 우수",
                "F2": "면접 침묵 관리",
                "S2": "답변 음량 조절",
                "R2": "면접 자신감 하락", // 🔥 자신감 하락
                "L3": "면접 질문 제안"
            ],
            
            // 💕 소개팅 모드 제목
            "소개팅": [
                "S1": "대화 속도 조절",
                "L1": "상대방 경청",
                "F1": "대화 관심도 하락",
                "R1": "호감도 상승",
                "F2": "대화 침묵 관리", 
                "S2": "대화 음량 조절",
                "R2": "호감도 부족", // 🔥 호감도 부족
                "L3": "대화 흥미도 강화"
            ]
        ]
        
        // 세션 타입에 맞는 제목 찾기
        if let sessionTitles = titleMapping[sessionType],
           let specificTitle = sessionTitles[appState.currentVisualPattern] {
            return specificTitle
        }
        
        // 폴백: 기본 제목
        switch appState.currentVisualPattern {
        case "S1": return "속도 조절"
        case "L1": return "경청 강화"
        case "F1": return "주제 전환"
        case "R1": return "호감도 상승"
        case "F2": return "침묵 관리"
        case "S2": return "음량 조절"
        case "R2": return "자신감 하락"
        case "L3": return "질문 제안"
        default: return "피드백"
        }
    }
    
    // 🎨 패턴별 시각적 효과 빌더 (화면 가득) - 🔧 position 제거하고 중앙 정렬 개선
    @ViewBuilder
    private func buildPatternVisualEffect() -> some View {
        switch appState.currentVisualPattern {
        case "S1": // 속도 조절 - 빠른 펄스 (화면 가득)
            buildSpeedControlEffect()
            
        case "L1": // 경청 강화 - 점진적 증가 (화면 가득)
            buildListeningEffect()
            
        case "F1": // 주제 전환 - 긴 페이드 (화면 가득)
            buildTopicChangeEffect()
            
        case "R1": // 호감도 상승 - 상승 파동 (화면 가득)
            buildLikabilityUpEffect()
            
        case "F2": // 침묵 관리 - 부드러운 펄스 (화면 가득)
            buildSilenceEffect()
            
        case "S2": // 음량 조절 - 변화하는 크기 (화면 가득)
            buildVolumeControlEffect()
            
        case "R2": // 관심도 하락 - 강한 경고 (화면 가득)
            buildInterestDownEffect()
            
        case "L3": // 질문 제안 - 물음표 형태 (화면 가득)
            buildQuestionEffect()
            
        default:
            EmptyView()
        }
    }
    
    // S1: 속도 조절 효과 (빠른 펄스) - 🔧 position 제거
    @ViewBuilder
    private func buildSpeedControlEffect() -> some View {
        ZStack {
            ForEach(0..<4) { index in
                Circle()
                    .fill(appState.visualPatternColor.opacity(0.5 - Double(index) * 0.1))
                    .frame(
                        width: 60 + CGFloat(index) * 40, 
                        height: 60 + CGFloat(index) * 40
                    )
                    .scaleEffect(animationPulse + CGFloat(index) * 0.1)
                    .animation(
                        Animation.easeInOut(duration: 0.12)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.03),
                        value: animationPulse
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // L1: 경청 강화 효과 (점진적 증가) - 🔧 position 제거
    @ViewBuilder
    private func buildListeningEffect() -> some View {
        ZStack {
            Circle()
                .stroke(appState.visualPatternColor, lineWidth: 6 + animationScale * 10)
                .frame(
                    width: 80 + animationScale * 120, 
                    height: 80 + animationScale * 120
                )
                .opacity(1.0 - animationScale * 0.3)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: false),
                    value: animationScale
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // F1: 주제 전환 효과 (긴 페이드) - 🔧 position 제거
    @ViewBuilder
    private func buildTopicChangeEffect() -> some View {
        ZStack {
            VStack(spacing: 10) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(appState.visualPatternColor.opacity(animationOpacity * 0.7))
                        .frame(width: screenSize.width * 0.9, height: 30)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatCount(2, autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: animationOpacity
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // R1: 호감도 상승 효과 (상승 파동) - 🔧 position 제거
    @ViewBuilder
    private func buildLikabilityUpEffect() -> some View {
        ZStack {
            VStack(spacing: 12) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 15)
                        .fill(appState.visualPatternColor.opacity(animationWave * 0.8))
                        .frame(width: screenSize.width * 0.8, height: 20)
                        .offset(y: animationOffset)
                        .animation(
                            Animation.easeInOut(duration: 0.4)
                                .repeatCount(4, autoreverses: false)
                                .delay(Double(index) * 0.08),
                            value: animationOffset
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // F2: 침묵 관리 효과 (부드러운 펄스) - 🔧 position 제거
    @ViewBuilder
    private func buildSilenceEffect() -> some View {
        ZStack {
            Circle()
                .fill(appState.visualPatternColor.opacity(0.4))
                .frame(width: 140, height: 140)
                .scaleEffect(animationPulse)
                .animation(
                    Animation.easeInOut(duration: 1.2).repeatCount(2, autoreverses: true),
                    value: animationPulse
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // S2: 음량 조절 효과 (변화하는 크기) - 🔧 position 제거
    @ViewBuilder
    private func buildVolumeControlEffect() -> some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<7) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(appState.visualPatternColor)
                        .frame(
                            width: 12, 
                            height: 20 + CGFloat(index) * 8 + animationScale * 25
                        )
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: animationScale
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // R2: 관심도 하락 효과 (강한 경고) - 🔧 position 제거
    @ViewBuilder
    private func buildInterestDownEffect() -> some View {
        ZStack {
            Triangle()
                .fill(Color.red.opacity(0.8))
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(animationRotation))
                .scaleEffect(animationScale)
                .animation(
                    Animation.easeInOut(duration: 0.3)
                        .repeatForever(autoreverses: true),
                    value: animationRotation
                )
                .animation(
                    Animation.easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true),
                    value: animationScale
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // L3: 질문 제안 효과 (물음표 형태) - 🔧 position 제거
    @ViewBuilder
    private func buildQuestionEffect() -> some View {
        ZStack {
            Text("?")
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(appState.visualPatternColor)
                .opacity(animationOpacity)
                .scaleEffect(animationScale)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: animationOpacity
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 🎨 애니메이션 시작
    private func startPatternAnimation() {
        switch appState.currentVisualPattern {
        case "S1":
            animationPulse = 1.2
        case "L1":
            animationScale = 1.0
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                animationScale = 0.3
            }
        case "F1":
            animationOpacity = 1.0
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animationOpacity = 0.3
            }
        case "R1":
            animationOffset = 50
            animationWave = 0.5
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) {
                animationOffset = -100
                animationWave = 1.0
            }
        case "F2":
            animationPulse = 1.3
        case "S2":
            animationScale = 0.5
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animationScale = 1.5
            }
        case "R2":
            animationRotation = 0
            animationScale = 0.8
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                animationRotation = 10
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                animationScale = 1.3
            }
        case "L3":
            animationOpacity = 1.0
            animationScale = 1.0
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animationOpacity = 0.4
                animationScale = 1.2
            }
        default:
            break
        }
    }
    
    // 🎨 애니메이션 리셋
    private func resetAnimations() {
        animationOffset = 0
        animationScale = 1.0
        animationOpacity = 1.0
        animationRotation = 0
        animationPulse = 1.0
        animationWave = 0
    }
}

// 🎨 커스텀 Heart 모양
struct Heart: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width * 0.5, y: height * 0.9))
        path.addCurve(
            to: CGPoint(x: width * 0.1, y: height * 0.3),
            control1: CGPoint(x: width * 0.5, y: height * 0.7),
            control2: CGPoint(x: width * 0.1, y: height * 0.5)
        )
        path.addArc(
            center: CGPoint(x: width * 0.25, y: height * 0.25),
            radius: width * 0.15,
            startAngle: .degrees(135),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: width * 0.75, y: height * 0.25),
            radius: width * 0.15,
            startAngle: .degrees(180),
            endAngle: .degrees(45),
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.9),
            control1: CGPoint(x: width * 0.9, y: height * 0.5),
            control2: CGPoint(x: width * 0.5, y: height * 0.7)
        )
        return path
    }
}

// 🎨 커스텀 Triangle 모양
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

struct WatchVisualFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        WatchVisualFeedbackView()
            .environmentObject(AppState())
    }
}
#endif 