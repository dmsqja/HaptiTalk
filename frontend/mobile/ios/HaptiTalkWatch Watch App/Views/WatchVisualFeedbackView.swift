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
            
            // 📱 패턴 정보 오버레이 (아이콘 + 의미있는 텍스트) - 더 눈에 띄게
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
            .position(x: screenSize.width / 2, y: screenSize.height * 0.68) // 🔧 위치 조정
            .opacity(1.0) // 확실히 보이도록
        }
        .onAppear {
            print("🎨 Watch: WatchVisualFeedbackView appeared - 패턴: \(appState.currentVisualPattern)")
            startPatternAnimation()
        }
        .onDisappear {
            print("🎨 Watch: WatchVisualFeedbackView disappeared")
            resetAnimations()
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
    
    // 🎨 패턴별 제목 반환
    private func getPatternTitle() -> String {
        switch appState.currentVisualPattern {
        case "S1": return "속도 조절"
        case "L1": return "경청 강화"
        case "F1": return "주제 전환"
        case "R1": return "호감도 상승"
        case "F2": return "침묵 관리"
        case "S2": return "음량 조절"
        case "R2": return "관심도 하락"
        case "L3": return "질문 제안"
        default: return "피드백"
        }
    }
    
    // 🎨 패턴별 시각적 효과 빌더 (화면 가득)
    @ViewBuilder
    private func buildPatternVisualEffect() -> some View {
        let centerX = screenSize.width / 2
        let centerY = screenSize.height / 2
        
        switch appState.currentVisualPattern {
        case "S1": // 속도 조절 - 빠른 펄스 (화면 가득)
            buildSpeedControlEffect(centerX: centerX, centerY: centerY)
            
        case "L1": // 경청 강화 - 점진적 증가 (화면 가득)
            buildListeningEffect(centerX: centerX, centerY: centerY)
            
        case "F1": // 주제 전환 - 긴 페이드 (화면 가득)
            buildTopicChangeEffect(centerX: centerX, centerY: centerY)
            
        case "R1": // 호감도 상승 - 상승 파동 (화면 가득)
            buildLikabilityUpEffect(centerX: centerX, centerY: centerY)
            
        case "F2": // 침묵 관리 - 부드러운 펄스 (화면 가득)
            buildSilenceEffect(centerX: centerX, centerY: centerY)
            
        case "S2": // 음량 조절 - 변화하는 크기 (화면 가득)
            buildVolumeControlEffect(centerX: centerX, centerY: centerY)
            
        case "R2": // 관심도 하락 - 강한 경고 (화면 가득)
            buildInterestDownEffect(centerX: centerX, centerY: centerY)
            
        case "L3": // 질문 제안 - 물음표 형태 (화면 가득)
            buildQuestionEffect(centerX: centerX, centerY: centerY)
            
        default:
            EmptyView()
        }
    }
    
    // S1: 속도 조절 효과 (빠른 펄스) - 화면 가득
    @ViewBuilder
    private func buildSpeedControlEffect(centerX: CGFloat, centerY: CGFloat) -> some View {
        ForEach(0..<4) { index in
            Circle()
                .fill(appState.visualPatternColor.opacity(0.5 - Double(index) * 0.1))
                .frame(
                    width: 60 + CGFloat(index) * 40, 
                    height: 60 + CGFloat(index) * 40
                )
                .scaleEffect(animationPulse + CGFloat(index) * 0.1)
                .position(x: centerX, y: centerY)
                .animation(
                    Animation.easeInOut(duration: 0.12)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.03),
                    value: animationPulse
                )
        }
    }
    
    // L1: 경청 강화 효과 (점진적 증가) - 화면 가득
    @ViewBuilder
    private func buildListeningEffect(centerX: CGFloat, centerY: CGFloat) -> some View {
        Circle()
            .stroke(appState.visualPatternColor, lineWidth: 6 + animationScale * 10)
            .frame(
                width: 80 + animationScale * 120, 
                height: 80 + animationScale * 120
            )
            .opacity(1.0 - animationScale * 0.3)
            .position(x: centerX, y: centerY)
    }
    
    // F1: 주제 전환 효과 (긴 페이드) - 화면 가득
    @ViewBuilder
    private func buildTopicChangeEffect(centerX: CGFloat, centerY: CGFloat) -> some View {
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
        .position(x: centerX, y: centerY)
    }
    
    // R1: 호감도 상승 효과 (상승 파동) - 화면 가득
    @ViewBuilder
    private func buildLikabilityUpEffect(centerX: CGFloat, centerY: CGFloat) -> some View {
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
        .position(x: centerX, y: centerY)
    }
    
    // F2: 침묵 관리 효과 (부드러운 펄스) - 화면 가득
    @ViewBuilder
    private func buildSilenceEffect(centerX: CGFloat, centerY: CGFloat) -> some View {
        Circle()
            .fill(appState.visualPatternColor.opacity(0.4))
            .frame(width: 140, height: 140)
            .scaleEffect(animationPulse)
            .position(x: centerX, y: centerY)
            .animation(
                Animation.easeInOut(duration: 1.2).repeatCount(2, autoreverses: true),
                value: animationPulse
            )
    }
    
    // S2: 음량 조절 효과 (변화하는 크기) - 화면 가득
    @ViewBuilder
    private func buildVolumeControlEffect(centerX: CGFloat, centerY: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<7) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(appState.visualPatternColor)
                    .frame(
                        width: 12, 
                        height: 30 + CGFloat(index) * animationScale * 15
                    )
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatCount(3, autoreverses: true)
                            .delay(Double(index) * 0.08),
                        value: animationScale
                    )
            }
        }
        .position(x: centerX, y: centerY)
    }
    
    // R2: 관심도 하락 효과 (강한 경고) - 화면 가득
    @ViewBuilder
    private func buildInterestDownEffect(centerX: CGFloat, centerY: CGFloat) -> some View {
        ZStack {
            // 배경 경고 원들 (화면 가득)
            ForEach(0..<4) { index in
                Circle()
                    .stroke(Color.red.opacity(0.6), lineWidth: 4)
                    .frame(
                        width: 100 + CGFloat(index) * 50, 
                        height: 100 + CGFloat(index) * 50
                    )
                    .opacity(0.9 - Double(index) * 0.2)
                    .scaleEffect(animationScale)
                    .position(x: centerX, y: centerY)
                    .animation(
                        Animation.easeOut(duration: 0.2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.05),
                        value: animationScale
                    )
            }
            
            // 중앙 경고 삼각형
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.red)
                .scaleEffect(animationPulse)
                .position(x: centerX, y: centerY)
                .animation(
                    Animation.easeInOut(duration: 0.1)
                        .repeatForever(autoreverses: true),
                    value: animationPulse
                )
        }
    }
    
    // L3: 질문 제안 효과 (물음표 형태) - 화면 가득
    @ViewBuilder
    private func buildQuestionEffect(centerX: CGFloat, centerY: CGFloat) -> some View {
        VStack(spacing: 25) {
            // 물음표 상단 곡선 (더 크게)
            Circle()
                .stroke(appState.visualPatternColor, lineWidth: 8)
                .frame(width: 80, height: 80)
                .scaleEffect(animationPulse)
                .opacity(animationOpacity)
                .animation(
                    Animation.easeInOut(duration: 0.3)
                        .repeatCount(4, autoreverses: true),
                    value: animationPulse
                )
            
            // 물음표 하단 점 (더 크게)
            Circle()
                .fill(appState.visualPatternColor)
                .frame(width: 20, height: 20)
                .scaleEffect(animationScale)
                .opacity(animationOpacity)
                .animation(
                    Animation.easeInOut(duration: 0.8).delay(0.6),
                    value: animationScale
                )
        }
        .position(x: centerX, y: centerY)
    }
    
    // 🎬 패턴별 애니메이션 시작
    private func startPatternAnimation() {
        let intensity = appState.visualAnimationIntensity
        
        switch appState.currentVisualPattern {
        case "S1": // 빠른 펄스
            withAnimation {
                animationPulse = 0.8 + intensity * 0.4
            }
            
        case "L1": // 점진적 증가
            withAnimation(.easeInOut(duration: 1.0)) {
                animationScale = intensity
            }
            
        case "F1": // 긴 페이드
            withAnimation {
                animationOpacity = intensity
            }
            
        case "R1": // 상승 파동
            withAnimation {
                animationOffset = -20
                animationWave = intensity
            }
            
        case "F2": // 부드러운 펄스
            withAnimation {
                animationPulse = 1.0 + intensity * 0.3
            }
            
        case "S2": // 변화하는 크기
            withAnimation {
                animationScale = intensity
            }
            
        case "R2": // 강한 경고
            withAnimation {
                animationPulse = 0.9 + intensity * 0.2
                animationScale = 1.0 + intensity * 0.5
                animationOpacity = intensity
            }
            
        case "L3": // 물음표 형태
            withAnimation {
                animationPulse = 1.0 + intensity * 0.2
                animationScale = intensity
                animationOpacity = intensity
            }
            
        default:
            break
        }
    }
    
    // 🔄 애니메이션 리셋
    private func resetAnimations() {
        animationOffset = 0
        animationScale = 1.0
        animationOpacity = 1.0
        animationRotation = 0
        animationPulse = 1.0
        animationWave = 0
    }
}

struct WatchVisualFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        WatchVisualFeedbackView()
            .environmentObject(AppState())
    }
}
#endif 