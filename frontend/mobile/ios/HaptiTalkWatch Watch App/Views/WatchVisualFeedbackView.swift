//
//  WatchVisualFeedbackView.swift
//  HaptiTalkWatch Watch App
//
//  Created on 5/15/25.
//

#if os(watchOS)
import SwiftUI
import WatchKit

// 🎨 자신감 상승 애니메이션 스타일 옵션 (전문적 스타일만)
enum ConfidenceAnimationStyle: String, CaseIterable {
    case levelUpBar = "성취 바"           // 기본값 - 전문적 성취감
    case chartRise = "차트 상승"          // 데이터 상승 표현
    case sparkleStars = "별 반짝임"       // 화려한 축하 효과
    case firework = "파이어워크"          // 폭발적 성취감
}

@available(watchOS 6.0, *)
struct WatchVisualFeedbackView: View {
    @EnvironmentObject var appState: AppState
    
    // 🎨 애니메이션 스타일 설정 (기본값: 성취 바 - 발표/면접 전용)
    @State private var confidenceAnimationStyle: ConfidenceAnimationStyle = .levelUpBar
    
    // 🎨 애니메이션 스타일 변경 방법:
    // ================================================================================
    // 
    // 💡 **쉬운 변경 방법:**
    // 위의 .heartGlow 부분을 다른 스타일로 바꾸면 됩니다!
    //
         // 📋 **발표/면접 전용 전문적 스타일들:**
     // 
     // 1️⃣ .levelUpBar   - 🎯 성취 바 (기본, 전문적 성취감)  
     //    → "EXCELLENT!" 텍스트와 함께 바가 채워지는 성취감 효과
     //
     // 2️⃣ .chartRise    - 📈 차트 상승 (비즈니스 스타일)
     //    → 차트 바가 올라가면서 화살표가 위로 향하는 전문적 효과
     //
     // 3️⃣ .sparkleStars - ✨ 별 반짝임 (특별한 순간 강조)
     //    → 별이 빛나면서 주변에 반짝임이 퍼지는 중요한 순간 효과
     //
     // 4️⃣ .firework     - 🎆 파이어워크 (큰 성취 달성)
     //    → 중앙에서 폭발하면서 파티클이 사방으로 퍼지는 큰 성취 효과
     //
     // 💻 **변경 예시:**
     // @State private var confidenceAnimationStyle: ConfidenceAnimationStyle = .chartRise
    //
    // ================================================================================
    
    // 🎨 애니메이션 상태 변수들
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
            
            // 🎨 아이콘과 애니메이션을 정확히 같은 위치에 배치
            VStack(spacing: 12) {
                Spacer()
                
                // 🎨 아이콘과 애니메이션이 겹쳐지는 중앙 영역
                ZStack {
                    // 패턴별 시각적 효과 (배경 애니메이션)
                    buildPatternVisualEffect()
                        .zIndex(0) // 배경
                    
                    // 패턴 아이콘 (전경에서 항상 보임) - 흰색 고정으로 명확하게 표시
                    getPatternIcon()
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white) // 흰색으로 고정
                        .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 1) // 더 강한 검은 그림자
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 0) // 추가 검은 그림자로 윤곽 강화
                        .scaleEffect(animationScale * 0.1 + 0.95) // 애니메이션과 연동
                        .animation(.easeInOut(duration: 0.8), value: animationScale)
                        .zIndex(10) // 더 높은 zIndex
                }
                
                // 패턴 제목 추가
                Text(getPatternTitle())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    .opacity(animationOpacity)
                    .animation(.easeInOut(duration: 1.0), value: animationOpacity)
                
                // 간결한 패턴 메시지
                if !appState.hapticFeedbackMessage.isEmpty {
                    Text(appState.hapticFeedbackMessage)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.4))
                                .blur(radius: 0.5)
                        )
                        .opacity(animationOpacity)
                        .animation(.easeInOut(duration: 1.0), value: animationOpacity)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false) // 터치 차단하여 애니메이션 방해 방지
        }
        .onAppear {
            print("🎨 Watch: WatchVisualFeedbackView appeared - 패턴: \(appState.currentVisualPattern)")
            print("🎨 Watch: appState.showVisualFeedback: \(appState.showVisualFeedback)")
            print("🎨 Watch: appState.visualPatternColor: \(appState.visualPatternColor)")
            print("🎨 Watch: appState.hapticFeedbackMessage: \(appState.hapticFeedbackMessage)")
            startPatternAnimation()
        }
        .onDisappear {
            print("🎨 Watch: WatchVisualFeedbackView disappeared")
            resetAnimations()
            // �� AppState의 시각적 피드백 상태도 완전히 초기화
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
    
    // 🎨 패턴별 아이콘 반환 (4개 핵심 패턴만)
    @ViewBuilder
    private func getPatternIcon() -> some View {
        switch appState.currentVisualPattern {
        // ✅ 활성화된 4개 핵심 패턴 - 더 직관적인 아이콘 (대조적 디자인)
        case "D1": // 전달력: 말이 빠르다 💨
            Image(systemName: "speedometer")
        case "C1": // 자신감: 확신도 상승 - 상승 트렌드 아이콘
            Image(systemName: "chart.line.uptrend.xyaxis")
        case "C2": // 자신감: 안정감 강화 - 하락 트렌드 아이콘 (C1과 대조)
            Image(systemName: "chart.line.downtrend.xyaxis")
        case "F1": // 필러워드: 감지
            Image(systemName: "exclamationmark.bubble")
            
        // 🔒 비활성화된 패턴들 (주석 처리)
        /*
        case "L1": // 경청 강화
            Image(systemName: "ear.fill")
        case "F1": // 주제 전환
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
        case "F2": // 침묵 관리
            Image(systemName: "speaker.slash.fill")
        case "L3": // 질문 제안
            Image(systemName: "questionmark.circle.fill")
        */
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
                "D1": "말하기 속도 조절",
                "C1": "자신감 상승", 
                "C2": "자신감 하락",
                "F1": "필러워드 감지"
            ],
            
            // 👔 면접 모드 제목  
            "면접": [
                "D1": "답변이 빠르다",
                "C1": "면접 자신감 상승",
                "C2": "면접 자신감 하락",
                "F1": "필러워드 감지"
            ]
        ]
        
        // 세션 타입에 맞는 제목 찾기
        if let sessionTitles = titleMapping[sessionType],
           let specificTitle = sessionTitles[appState.currentVisualPattern] {
            return specificTitle
        }
        
        // 폴백: 새로운 4개 핵심 패턴만
        switch appState.currentVisualPattern {
        // ✅ 새로운 4개 핵심 패턴
        case "D1": return "말하기 속도 조절"
        case "C1": return "자신감 상승"
        case "C2": return "자신감 하락"
        case "F1": return "필러워드 감지"
        default: return "피드백"
        }
    }
    
    // 🎨 새로운 4개 패턴별 시각적 효과 빌더
    @ViewBuilder
    private func buildPatternVisualEffect() -> some View {
        switch appState.currentVisualPattern {
        // ✅ 새로운 4개 핵심 패턴 - 개선된 애니메이션
        case "D1": // 전달력: 말이 빠르다 - 빠름 경고 효과
            buildSpeechTooFastEffect()
            
        case "C1": // 자신감: 확신도 상승 - 우아한 상승 효과
            buildConfidenceUpEffect()
            
        case "C2": // 자신감: 안정감 강화 - 부드러운 안정화 효과
            buildStabilityEffect()
            
        case "F1": // 필러워드: 감지 - 가벼운 지적 효과
            buildFillerWordEffect()
            
        default:
            EmptyView()
        }
    }
    
    // D1: 말이 빠르다 효과 - 큰 속도계 디자인 - zIndex 설정
    @ViewBuilder
    private func buildSpeechTooFastEffect() -> some View {
        ZStack {
            // 속도계 눈금들 (회전하는 대시보드 느낌) - 크기 조정
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * 45.0
                let rotationValue = appState.visualAnimationIntensity * 360.0
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange.opacity(0.7))
                    .frame(width: 4, height: 25)
                    .offset(y: -50) 
                    .rotationEffect(.degrees(angle + rotationValue))
                    .scaleEffect(1.0 + (0.3 * appState.visualAnimationIntensity))
                    .zIndex(1) // 아이콘보다 아래
            }
            
            // 중앙 빠른 펄스 (심장박동 같은 빠른 리듬) - 크기 조정 - 더 자연스럽게 - 아이콘 가리지 않게
            Circle()
                .fill(Color.orange.opacity(0.4)) // opacity 줄임
                .frame(width: 30, height: 30)
                .scaleEffect(1.0 + (1.8 * appState.visualAnimationIntensity))
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: appState.visualAnimationIntensity)
                .zIndex(2) // 아이콘보다 아래
                
            // 속도 표시 바늘 (빠르게 움직임) - 크기 조정 - 자연스러운 움직임 - 아이콘 가리지 않게
            let needleAngle = -45 + (90 * appState.visualAnimationIntensity)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.red.opacity(0.6)) // opacity 줄임
                .frame(width: 5, height: 35)
                .offset(y: -18)
                .rotationEffect(.degrees(needleAngle))
                .animation(
                    .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                    value: needleAngle
                )
                .zIndex(3) // 아이콘보다 아래
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // C1: 자신감 상승 효과 - 폭발적인 에너지 상승 (덜 화려하게 조정) - zIndex 설정
    @ViewBuilder
    private func buildConfidenceUpEffect() -> some View {
        ZStack {
            // 바깥쪽 원형 에너지 파동 - 수량 줄임 (4개 → 2개)
            ForEach(0..<2, id: \.self) { wave in
                Circle()
                    .stroke(Color.green.opacity(0.5), lineWidth: 2) // opacity 줄임
                    .frame(width: 60 + CGFloat(wave) * 25, height: 60 + CGFloat(wave) * 25)
                    .scaleEffect(1.0 + (appState.visualAnimationIntensity * 0.6)) // 강도 줄임
                    .opacity(1.0 - appState.visualAnimationIntensity * 0.7)
                    .animation(
                        .easeOut(duration: 1.0).delay(Double(wave) * 0.3),
                        value: appState.visualAnimationIntensity
                    )
                    .zIndex(1) // 아이콘보다 아래
            }
            
            // 중앙에서 폭발하는 별들 - 5개로 조정 - 크기 역방향
            ForEach(0..<5, id: \.self) { index in
                let angle = Double(index) * 72.0 // 72도씩 5개
                let explosionValue = appState.visualAnimationIntensity
                let distance = 45.0 * explosionValue // 거리 줄임
                
                Image(systemName: "star.fill")
                    .font(.callout) // 크기 줄임
                    .foregroundColor(.yellow.opacity(0.7 - explosionValue * 0.3)) // opacity 줄임
                    .offset(
                        x: cos(angle * .pi / 180) * distance,
                        y: sin(angle * .pi / 180) * distance
                    )
                    .scaleEffect(0.5 + (1.0 * explosionValue)) // 작게 시작해서 크게 끝남 (역방향)
                    .rotationEffect(.degrees(explosionValue * 90)) // 회전량 줄임
                    .zIndex(2) // 아이콘보다 아래
            }
            
            // 상승하는 에너지 바들 - 수량 줄임 (5개 → 3개)
            ForEach(0..<3, id: \.self) { index in
                let waveDelay = Double(index) * 0.25
                let waveValue = (appState.visualAnimationIntensity + waveDelay).truncatingRemainder(dividingBy: 1.0)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.green.opacity(0.7), .yellow.opacity(0.6)]), // opacity 줄임
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 4, height: 35 * (1.0 - waveValue)) // 크기 줄임
                    .offset(y: -25 * waveValue) // 높이 줄임
                    .opacity(1.0 - waveValue)
                    .offset(x: Double(index - 1) * 20) // 간격 조정
                    .zIndex(3) // 아이콘보다 아래
            }
            
            // 바깥쪽 성취 반짝임들 - 수량 대폭 줄임 (12개 → 6개)
            ForEach(0..<6, id: \.self) { spark in
                let sparkAngle = Double(spark) * 60.0 // 60도씩 6개
                let sparkValue = appState.visualAnimationIntensity
                let sparkDistance = 35.0 + (10.0 * sparkValue) // 거리와 크기 줄임
                
                Circle()
                    .fill(Color.yellow.opacity(0.6 - sparkValue * 0.3)) // opacity 줄임
                    .frame(width: 3, height: 3) // 크기 줄임
                    .offset(
                        x: cos(sparkAngle * .pi / 180) * sparkDistance,
                        y: sin(sparkAngle * .pi / 180) * sparkDistance
                    )
                    .scaleEffect(1.5 * (1.0 - sparkValue * 0.5)) // 스케일 줄임
                    .zIndex(4) // 아이콘보다 아래
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 🎨 옵션 1: 성취 바 효과 (기본)
    @ViewBuilder
    private func buildLevelUpBarEffect() -> some View {
        ZStack {
            VStack(spacing: 8) {
                // "EXCELLENT!" 텍스트 (발표/면접에 더 적합)
                Text("EXCELLENT!")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                    .opacity(animationOpacity)
                    .scaleEffect(animationScale)
                    .animation(
                        Animation.easeOut(duration: 0.6)
                            .repeatCount(3, autoreverses: true),
                        value: animationScale
                    )
                
                // 레벨업 바
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: screenSize.width * 0.8, height: 20)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.yellow, .orange, .red]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: screenSize.width * 0.8 * animationWave, height: 20)
                        .animation(
                            Animation.easeOut(duration: 2.5)
                                .repeatCount(1, autoreverses: false),
                            value: animationWave
                        )
                }
                
                // 자신감 상승 표시
                Text("자신감 ↗")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                    .offset(y: animationOffset)
                    .opacity(animationOpacity)
                    .animation(
                        Animation.easeOut(duration: 1.5),
                        value: animationOffset
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 🎨 옵션 2: 별 반짝임 효과 (컴파일 최적화를 위해 서브뷰로 분리)
    @ViewBuilder
    private func buildSparkleStarsEffect() -> some View {
        ZStack {
            // 중앙 별
            centralStarView
            
            // 주변 작은 별들
            surroundingStarsView
            
            // 반짝임 효과
            sparkleParticlesView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 🎨 중앙 별 뷰 (분리)
    @ViewBuilder
    private var centralStarView: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 40, weight: .bold))
            .foregroundColor(.yellow)
            .scaleEffect(animationScale)
            .rotationEffect(.degrees(animationRotation))
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatCount(3, autoreverses: true),
                value: animationScale
            )
    }
    
    // 🎨 주변 별들 뷰 (분리 - 단순화)
    @ViewBuilder
    private var surroundingStarsView: some View {
        ForEach(0..<8) { index in
            singleStarView(for: index)
        }
    }
    
    // 🎨 개별 별 뷰 (더 단순화)
    @ViewBuilder
    private func singleStarView(for index: Int) -> some View {
        let starSize = 8 + index % 3 * 4
        let starColor = index % 2 == 0 ? Color.yellow : Color.white
        let angle = Double(index) * .pi / 4
        let radius = 50 + animationPulse * 30
        
        Image(systemName: "star.fill")
            .font(.system(size: CGFloat(starSize), weight: .medium))
            .foregroundColor(starColor)
            .offset(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
            .opacity(animationOpacity)
            .animation(
                Animation.easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.1),
                value: animationPulse
            )
    }
    
    // 🎨 반짝임 파티클 뷰 (분리 - 단순화)
    @ViewBuilder
    private var sparkleParticlesView: some View {
        ForEach(0..<12) { index in
            sparkleParticle(for: index)
        }
    }
    
    // 🎨 개별 반짝임 파티클 (더 단순화)
    @ViewBuilder
    private func sparkleParticle(for index: Int) -> some View {
        let positions: [(CGFloat, CGFloat)] = [
            (-60, -40), (30, -70), (-40, 50), (70, -20),
            (-80, 10), (40, 60), (-30, -60), (80, 30),
            (-50, -10), (20, -50), (-70, 40), (60, -30)
        ]
        
        let position = positions[index % positions.count]
        
        Circle()
            .fill(Color.white)
            .frame(width: 4, height: 4)
            .offset(x: position.0, y: position.1)
            .opacity(animationWave)
            .animation(
                Animation.linear(duration: 0.5)
                    .repeatCount(6, autoreverses: true)
                    .delay(Double(index) * 0.05),
                value: animationWave
            )
    }
    
    // 🎨 옵션 3: 차트 상승 효과
    @ViewBuilder
    private func buildChartRiseEffect() -> some View {
        ZStack {
            VStack(spacing: 4) {
                // 상승 화살표
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.green)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatCount(2, autoreverses: false),
                        value: animationOffset
                    )
                
                // 차트 바들
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.blue, .green]),
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                            .frame(
                                width: 16,
                                height: 20 + CGFloat(index) * 10 + animationScale * 30
                            )
                            .animation(
                                Animation.easeOut(duration: 0.8)
                                    .repeatCount(2, autoreverses: false)
                                    .delay(Double(index) * 0.15),
                                value: animationScale
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 🎨 옵션 4: 파이어워크 효과
    @ViewBuilder
    private func buildFireworkEffect() -> some View {
        ZStack {
            // 중앙 폭발
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [.yellow, .orange, .red, .clear]),
                    center: .center,
                    startRadius: 5,
                    endRadius: 80
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(animationPulse)
                .opacity(animationOpacity)
                .animation(
                    Animation.easeOut(duration: 1.2)
                        .repeatCount(2, autoreverses: false),
                    value: animationPulse
                )
            
            // 파이어워크 파티클들
            ForEach(0..<16) { index in
                Circle()
                    .fill(index % 4 == 0 ? .yellow : 
                          index % 4 == 1 ? .orange :
                          index % 4 == 2 ? .red : .pink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(
                        x: cos(Double(index) * .pi / 8) * animationOffset,
                        y: sin(Double(index) * .pi / 8) * animationOffset
                    )
                    .opacity(animationWave)
                    .animation(
                        Animation.easeOut(duration: 2.0)
                            .repeatCount(1, autoreverses: false)
                            .delay(Double(index) * 0.02),
                        value: animationOffset
                    )
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(animationPulse)
                .animation(
                    Animation.easeInOut(duration: 1.2).repeatCount(2, autoreverses: true),
                    value: animationPulse
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // S2: 음량 조절 효과 - 음파 파동 애니메이션
    @ViewBuilder
    private func buildVolumeControlEffect() -> some View {
        ZStack {
            // 외부로 퍼져나가는 음파 링들
            ForEach(0..<4) { index in
                Circle()
                    .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(animationPulse + CGFloat(index) * 0.3)
                    .opacity(1.0 - animationPulse * 0.5 - CGFloat(index) * 0.2)
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                        value: animationPulse
                    )
            }
            
            // 중앙 음량 바 이퀄라이저
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(
                            width: 6, 
                            height: 15 + CGFloat(index) * 5 + animationScale * 15
                        )
                        .animation(
                            Animation.easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.08),
                            value: animationScale
                        )
                }
            }
            .scaleEffect(1.2)
            
            // 중심 음량 시각 요소 (애니메이션과 조화)
            ZStack {
                // 스피커 베이스
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 8, height: 6)
                
                // 음파 표시 링
                ForEach(0..<2) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                        .frame(width: 4 + CGFloat(index) * 3, height: 2)
                        .offset(x: 8 + CGFloat(index) * 2)
                        .scaleEffect(animationPulse * 0.3 + 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: animationPulse
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 🎨 애니메이션 시작 (4개 핵심 패턴만)
    private func startPatternAnimation() {
        print("🎨 Watch: startPatternAnimation 시작 - 패턴: \(appState.currentVisualPattern)")
        
        switch appState.currentVisualPattern {
        // ✅ 새로운 4개 핵심 패턴
        case "D1": // 전달력: 말이 빠르다
            print("🎨 Watch: D1 시각적 애니메이션 시작")
            // 빠른 속도 경고 애니메이션 설정
            appState.visualAnimationIntensity = 1.0
            
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                appState.visualAnimationIntensity = 0.8
            }
            print("🎨 Watch: D1 애니메이션 설정 완료")
            
        case "C1": // 자신감: 확신도 상승
            print("🎨 Watch: C1 시각적 애니메이션 시작")
            // 폭발적인 에너지 상승 애니메이션 설정
            appState.visualAnimationIntensity = 0.0
            
            withAnimation(.easeOut(duration: 1.5).repeatCount(2, autoreverses: false)) {
                appState.visualAnimationIntensity = 1.0
            }
            print("🎨 Watch: C1 애니메이션 설정 완료")
            
        case "C2": // 자신감: 하락
            print("🎨 Watch: C2 시각적 애니메이션 시작")
            // 한번만 실행되는 하락 애니메이션 설정
            appState.visualAnimationIntensity = 0.0
            
            withAnimation(.easeInOut(duration: 2.5)) {
                appState.visualAnimationIntensity = 1.0
            }
            
            // 애니메이션 완료 후에도 값 유지
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                appState.visualAnimationIntensity = 1.0
            }
            print("🎨 Watch: C2 애니메이션 설정 완료")
            
        case "F1": // 필러워드: 감지
            print("🎨 Watch: F1 시각적 애니메이션 시작")
            // 톡톡 경고 애니메이션 설정
            appState.visualAnimationIntensity = 0.0
            
            withAnimation(.easeOut(duration: 1.2).repeatCount(2, autoreverses: false)) {
                appState.visualAnimationIntensity = 1.0
            }
            print("🎨 Watch: F1 애니메이션 설정 완료")
            
        // R1 패턴 제거됨 - 새로운 4개 핵심 패턴 설계에 포함되지 않음
            
        default:
            print("🎨 Watch: 알 수 없는 패턴: \(appState.currentVisualPattern)")
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
    
    // 🎨 자신감 상승 애니메이션 스타일별 시작
    private func startConfidenceAnimation() {
        switch confidenceAnimationStyle {
        case .levelUpBar:
            // 레벨업 바 효과
            animationScale = 1.0
            animationOpacity = 1.0
            animationWave = 0.0
            animationOffset = 20
            
            withAnimation(.easeOut(duration: 0.6).repeatCount(3, autoreverses: true)) {
                animationScale = 1.2
            }
            withAnimation(.easeOut(duration: 2.5).repeatCount(1, autoreverses: false)) {
                animationWave = 1.0
            }
            withAnimation(.easeOut(duration: 1.5)) {
                animationOffset = -30
                animationOpacity = 0.8
            }
            
        case .sparkleStars:
            // 별 반짝임 효과
            animationScale = 1.0
            animationRotation = 0
            animationPulse = 1.0
            animationOpacity = 1.0
            animationWave = 0.0
            
            withAnimation(.easeInOut(duration: 1.0).repeatCount(3, autoreverses: true)) {
                animationScale = 1.3
                animationRotation = 45
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animationPulse = 1.5
            }
            withAnimation(.linear(duration: 0.5).repeatCount(6, autoreverses: true)) {
                animationWave = 1.0
            }
            
        case .chartRise:
            // 차트 상승 효과
            animationOffset = 50
            animationScale = 0.5
            
            withAnimation(.easeOut(duration: 1.5).repeatCount(2, autoreverses: false)) {
                animationOffset = -20
            }
            withAnimation(.easeOut(duration: 0.8).repeatCount(2, autoreverses: false).delay(0.2)) {
                animationScale = 1.5
            }
            
        case .firework:
            // 파이어워크 효과
            animationPulse = 0.5
            animationOpacity = 1.0
            animationOffset = 0
            animationWave = 0.0
            
            withAnimation(.easeOut(duration: 1.2).repeatCount(2, autoreverses: false)) {
                animationPulse = 2.0
                animationOpacity = 0.3
            }
            withAnimation(.easeOut(duration: 2.0).repeatCount(1, autoreverses: false).delay(0.3)) {
                animationOffset = 120
                animationWave = 1.0
            }
        }
    }

        // C2: 자신감 하락 효과 - 랜덤 위치에서 떨어지는 화살표들
    @ViewBuilder
    private func buildStabilityEffect() -> some View {
        ZStack {
            // 랜덤 위치에서 떨어지는 하락 화살표들 (더 많이)
            ForEach(0..<8, id: \.self) { index in
                ConfidenceDropArrow(
                    index: index,
                    animationIntensity: appState.visualAnimationIntensity
                )
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 개별 호흡 원 뷰 (복잡한 표현식 분리) - 프레임에 맞게 조정
    @ViewBuilder
    private func breathingCircleView(for index: Int) -> some View {
        let indexAngle = Double(index) * .pi / 2
        let animatedValue = appState.visualAnimationIntensity * 2.0 * .pi
        let breathingValue = sin(animatedValue + indexAngle)
        let scale = 0.8 + (0.4 * breathingValue) // 더 크게
        let opacity = 0.3 + (0.2 * breathingValue)
        
        Circle()
            .stroke(
                Color.purple.opacity(opacity),
                lineWidth: 2.5
            )
            .frame(width: 80 + CGFloat(index) * 15, height: 80 + CGFloat(index) * 15) // 더 크고 계층적으로
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: appState.visualAnimationIntensity)
    }
    
    // 개별 명상 파동 뷰 (복잡한 표현식 분리) - 프레임에 맞게 조정
    @ViewBuilder
    private func meditationWaveView(for index: Int) -> some View {
        let waveDelay = Double(index) * 0.4
        let waveValue = (appState.visualAnimationIntensity + waveDelay).truncatingRemainder(dividingBy: 1.0)
        let waveScale = 0.4 + (0.8 * waveValue) // 더 큰 파동
        let waveOpacity = 0.5 * (1 - waveValue)
        
        Circle()
            .fill(RadialGradient(
                gradient: Gradient(colors: [
                    .purple.opacity(waveOpacity),
                    .clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 50 // 더 넓은 반지름
            ))
            .frame(width: 100, height: 100) // 더 큰 프레임
            .scaleEffect(waveScale)
            .opacity(1.0 - waveValue * 0.6)
    }
    
    // 중앙 광채 뷰 (복잡한 표현식 분리) - 프레임에 맞게 조정 - 아이콘 가리지 않게
    @ViewBuilder
    private var centralGlowView: some View {
        let animatedScale = 1.0 + (0.3 * sin(appState.visualAnimationIntensity * 3.0 * .pi))
        
        // 바깥쪽 부드러운 후광 - 크기 조정 - 아이콘 가리지 않게
        Circle()
            .fill(RadialGradient(
                gradient: Gradient(colors: [
                    .clear,
                    .purple.opacity(0.05), // opacity 줄임
                    .purple.opacity(0.15), // opacity 줄임
                    .clear
                ]),
                center: .center,
                startRadius: 15,
                endRadius: 40
            ))
            .frame(width: 80, height: 80)
            .scaleEffect(animatedScale * 0.8)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: appState.visualAnimationIntensity)
            
        // 내부 평온한 빛 - 크기 조정 - 아이콘 가리지 않게
        Circle()
            .fill(RadialGradient(
                gradient: Gradient(colors: [
                    .white.opacity(0.2), // opacity 줄임
                    .purple.opacity(0.1), // opacity 줄임
                    .clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 20
            ))
            .frame(width: 35, height: 35)
            .scaleEffect(animatedScale)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: appState.visualAnimationIntensity)
    }
    
    // F1: 필러워드 감지 효과 - 톡톡 경고 신호 (아이콘 주변으로 확장) - zIndex 설정
    @ViewBuilder
    private func buildFillerWordEffect() -> some View {
        ZStack {
            // 바깥쪽 경고 링들 (더 큰 범위)
            ForEach(0..<4, id: \.self) { ring in
                Circle()
                    .stroke(
                        Color.red.opacity(0.7),
                        lineWidth: 3
                    )
                    .frame(width: 50 + CGFloat(ring) * 20, height: 50 + CGFloat(ring) * 20)
                    .scaleEffect(1.0 + (appState.visualAnimationIntensity * 0.3))
                    .opacity(appState.visualAnimationIntensity < 0.5 ? 0.8 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.3).delay(Double(ring) * 0.1),
                        value: appState.visualAnimationIntensity
                    )
                    .zIndex(1) // 아이콘보다 아래
            }
            
            // 중앙 이중 펄스 (더 큰 톡톡 효과) - 아이콘 가리지 않게
            ForEach(0..<2, id: \.self) { pulse in
                Circle()
                    .fill(Color.blue.opacity(0.3)) // opacity 줄임
                    .frame(width: 20 + CGFloat(pulse) * 10, height: 20 + CGFloat(pulse) * 10)
                    .scaleEffect(
                        appState.visualAnimationIntensity < 0.2 ? 2.0 :
                        (appState.visualAnimationIntensity > 0.3 && appState.visualAnimationIntensity < 0.5) ? 2.0 : 1.0
                    )
                    .opacity(appState.visualAnimationIntensity < 0.5 ? 0.4 : 0.15) // opacity 줄임
                    .animation(
                        .easeInOut(duration: 0.15).delay(Double(pulse) * 0.1),
                        value: appState.visualAnimationIntensity
                    )
                    .zIndex(3) // 아이콘보다 아래
            }
            
            // 경고 삼각형들 (중앙 기준 랜덤 위치) - 순차적으로 나타났다가 사라짐
            ForEach(0..<5, id: \.self) { index in
                // 고정된 랜덤 위치들 (중앙 기준)
                let randomPositions: [(x: Double, y: Double)] = [
                    (x: -25, y: -32),  // 왼쪽 위
                    (x: 38, y: -18),   // 오른쪽 위
                    (x: -42, y: 15),   // 왼쪽 아래
                    (x: 28, y: 35),    // 오른쪽 아래
                    (x: 8, y: -40)     // 위쪽 중앙
                ]
                
                let warningValue = appState.visualAnimationIntensity
                let triangleDelay = Double(index) * 0.15 // 순차적 지연
                let adjustedValue = max(0, min(1.0, warningValue - triangleDelay)) // 각각 다른 타이밍
                let appearPhase = adjustedValue < 0.2 ? adjustedValue / 0.2 : 1.0 // 나타나는 단계 (더 빠르게)
                let fadePhase = adjustedValue > 0.2 ? max(0, 1.0 - (adjustedValue - 0.2) / 0.7) : 1.0 // 사라지는 단계 (더 천천히)
                let overallOpacity = appearPhase * fadePhase
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body) // 더 큰 폰트
                    .foregroundColor(.red.opacity(overallOpacity * 0.9))
                    .offset(
                        x: randomPositions[index].x,
                        y: randomPositions[index].y
                    )
                    .scaleEffect(0.5 + (overallOpacity * 1.0)) // 더 크게: 0.5~1.5 범위
                    .opacity(overallOpacity)
                    .animation(.easeInOut(duration: 0.6), value: adjustedValue) // 더 부드럽게
                    .zIndex(5) // 아이콘보다 아래
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 🎨 자신감 하락 화살표 컴포넌트 (한번만 떨어짐)
struct ConfidenceDropArrow: View {
    let index: Int
    let animationIntensity: Double
    
    @State private var hasStarted = false
    @State private var finalPosition: CGFloat = 0
    @State private var finalOpacity: Double = 0
    @State private var finalScale: CGFloat = 0.6
    
    private let arrowPositions: [(x: Double, y: Double)] = [
        (x: -42, y: -48),    // 왼쪽 끝 위
        (x: 15, y: -52),     // 오른쪽 중간 위
        (x: -8, y: -45),     // 중앙 약간 왼쪽
        (x: 38, y: -39),     // 오른쪽 위
        (x: -25, y: -33),    // 왼쪽 중간
        (x: 48, y: -46),     // 오른쪽 끝 위
        (x: 3, y: -38),      // 중앙 약간 오른쪽
        (x: -35, y: -42)     // 왼쪽 중상단
    ]
    
    var body: some View {
        let arrowDelay = Double(index) * 0.15
        let adjustedValue = max(0, min(1.0, animationIntensity - arrowDelay))
        
        if adjustedValue > 0 || hasStarted {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.gray) // 회색으로 변경
                .offset(
                    x: arrowPositions[index].x,
                    y: arrowPositions[index].y + finalPosition
                )
                .scaleEffect(finalScale)
                .opacity(finalOpacity)
                .onChange(of: adjustedValue) { newValue in
                    if newValue > 0 && !hasStarted {
                        hasStarted = true
                        animateArrow()
                    }
                }
        }
    }
    
    private func animateArrow() {
        // 나타나는 애니메이션 (더 빨리 선명하게)
        withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.15)) {
            finalOpacity = 1.0    // 빠르게 나타남
            finalScale = 1.2      // 중간 크기
        }
        
        // 떨어지는 애니메이션 (더 오래)
        withAnimation(.easeIn(duration: 2.0).delay(Double(index) * 0.15)) {
            finalPosition = 85.0  // 천천히 떨어짐
            finalScale = 1.6      // 최종 크기
        }
        
        // 사라지는 애니메이션 (더 늦게, 더 천천히)
        withAnimation(.easeOut(duration: 1.0).delay(Double(index) * 0.15 + 1.5)) {
            finalOpacity = 0.0    // 천천히 사라짐
        }
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


// 🎨 개발자 테스트용 유틸리티
extension WatchVisualFeedbackView {
    
    // 🛠️ 애니메이션 미리보기용 함수 (개발/테스트용)
    static func previewWithStyle(_ style: ConfidenceAnimationStyle) -> some View {
        WatchVisualFeedbackView()
            .environmentObject({
                let appState = AppState()
                appState.showVisualFeedback = true
                appState.currentVisualPattern = "C1"  // 새로운 4개 핵심 패턴 중 C1 사용
                appState.visualPatternColor = .green
                return appState
            }())
            .onAppear {
                // 스타일 설정은 내부적으로 처리됨
            }
    }
    
    // 🔧 애니메이션 스타일 변경 도우미 함수
    mutating func changeConfidenceStyle(to style: ConfidenceAnimationStyle) {
        self.confidenceAnimationStyle = style
        print("🎨 자신감 애니메이션 스타일 변경: \(style.rawValue)")
    }
}

struct WatchVisualFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 성취 바 효과 (기본)
            WatchVisualFeedbackView.previewWithStyle(.levelUpBar)
                .previewDisplayName("🎯 성취 바")
                
            // 차트 상승 효과
            WatchVisualFeedbackView.previewWithStyle(.chartRise)
                .previewDisplayName("📈 차트 상승")
                
            // 별 반짝임 효과
            WatchVisualFeedbackView.previewWithStyle(.sparkleStars)
                .previewDisplayName("✨ 별 반짝임")
                
            // 파이어워크 효과
            WatchVisualFeedbackView.previewWithStyle(.firework)
                .previewDisplayName("🎆 파이어워크")
        }
    }
}
#endif 