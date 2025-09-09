#if os(watchOS)
import SwiftUI

@available(watchOS 6.0, *)
struct SessionSummaryView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appState: AppState
    
    let sessionMode: String
    let totalTime: String
    let mainEmotion: String
    let likeabilityPercent: String
    let coreFeedback: String
    @State private var currentTime: String = ""
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    init(sessionMode: String = "발표 모드", 
         totalTime: String = "1:32:05", 
         mainEmotion: String = "긍정적", 
         likeabilityPercent: String = "88%", 
         coreFeedback: String = "핵심 메시지 전달이 명확했으며, 청중과의 소통이 매우 효과적이었습니다.") {
        self.sessionMode = sessionMode
        self.totalTime = totalTime
        self.mainEmotion = mainEmotion
        self.likeabilityPercent = likeabilityPercent
        self.coreFeedback = coreFeedback
        
        // 현재 시간 초기화
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        self._currentTime = State(initialValue: formatter.string(from: Date()))
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 헤더 (세션 완료 및 모드)
                    VStack(spacing: 4) {
                        Text("세션 완료")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(sessionMode)
                            .font(.system(size: 11))
                            .foregroundColor(Color(.gray))
                    }
                    .padding(.top, 15)
                    
                    // 세션 통계 정보
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 92)
                        
                        VStack(spacing: 10) {
                            // 총 시간
                            HStack {
                                Text("총 시간")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(.sRGB, red: 0.88, green: 0.88, blue: 0.88, opacity: 1.0)) // #E0E0E0
                                
                                Spacer()
                                
                                Text(totalTime)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            // 주요 감정
                            HStack {
                                Text("주요 감정")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(.sRGB, red: 0.88, green: 0.88, blue: 0.88, opacity: 1.0)) // #E0E0E0
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "face.smiling.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                    
                                    Text(mainEmotion)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // 호감도
                            HStack {
                                Text("호감도")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(.sRGB, red: 0.88, green: 0.88, blue: 0.88, opacity: 1.0)) // #E0E0E0
                                
                                Spacer()
                                
                                Text(likeabilityPercent)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                    
                    // 핵심 피드백
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.sRGB, red: 0.25, green: 0.32, blue: 0.71, opacity: 0.15)) // #3F51B5 with opacity
                            .frame(height: 88.5)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("핵심 피드백")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(.sRGB, red: 0.56, green: 0.79, blue: 0.98, opacity: 1.0)) // #90CAF9
                            
                            Text(coreFeedback)
                                .font(.system(size: 10))
                                .foregroundColor(Color(.sRGB, red: 0.88, green: 0.88, blue: 0.88, opacity: 1.0)) // #E0E0E0
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 10)
                    
                    Spacer(minLength: 30)
                    
                    // 홈으로 돌아가기 버튼이 제거됨
                    Spacer(minLength: 20)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 10)
                .padding(.top, -30)
            }
        }
        .onReceive(timer) { _ in
            updateCurrentTime()
        }
    }
    
    private func updateCurrentTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentTime = formatter.string(from: Date())
    }
    
    private func saveSessionIfNeeded() {
        // 이미 저장된 세션이 있는지 확인하고, 없는 경우에만 저장
        let alreadySaved = appState.sessionSummaries.contains { summary in
            summary.sessionMode == sessionMode &&
            summary.totalTime == totalTime &&
            Date().timeIntervalSince(summary.date) < 60 // 최근 1분 이내에 저장된 세션인지 확인
        }
        
        if !alreadySaved {
            let summary = SessionSummary(
                id: UUID(),
                sessionMode: sessionMode,
                totalTime: totalTime,
                mainEmotion: mainEmotion,
                likeabilityPercent: likeabilityPercent,
                coreFeedback: coreFeedback,
                date: Date()
            )
            appState.saveSessionSummary(summary: summary)
        }
    }
}

#Preview {
    SessionSummaryView()
        .environmentObject(AppState())
}
#endif 
