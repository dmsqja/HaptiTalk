#if os(watchOS)
import SwiftUI

@available(watchOS 6.0, *)
struct HapticFeedbackNotificationView: View {
    let sessionType: String
    let elapsedTime: String
    let message: String
    let currentTime: String
    
    @State private var secondsRemaining: Int = 5
    @State private var isVisible: Bool = true
    @Environment(\.presentationMode) var presentationMode
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // 상단 시간 표시
                HStack {
                    Spacer()
                    Text(currentTime)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white)
                        .padding(.top, 5)
                        .padding(.trailing, 10)
                }
                
                // 상단 세션 정보
                HStack {
                    ZStack {
                        Capsule()
                            .fill(Color(.sRGB, red: 0.25, green: 0.32, blue: 0.71, opacity: 1.0)) // #3F51B5 (앱 primaryColor와 일치)
                            .frame(width: 55, height: 20)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 8))
                            
                            Text(sessionType)
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.white)
                    }
                    .padding(.leading, 10)
                    .padding(.top, 5)
                    
                    Spacer()
                    
                    Text(elapsedTime)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.gray)
                        .padding(.trailing, 10)
                }
                .padding(.bottom, 10)
                
                // 알림 컨테이너
                VStack {
                    Spacer(minLength: 15)
                    
                    // 아이콘
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .padding()
                    
                    // 메시지
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 15)
                    
                    Spacer()
                    
                    // 확인 버튼
                    Button(action: {
                        withAnimation {
                            isVisible = false
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text("확인")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 15)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 타이머 텍스트
                    Text("\(secondsRemaining)초 후 사라집니다")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 5)
                        .padding(.bottom, 15)
                }
                .frame(width: 150, height: 193)
                .background(Color.indigo.opacity(0.95))
                .cornerRadius(16)
            }
        }
        .onReceive(timer) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                withAnimation {
                    isVisible = false
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

#Preview {
    HapticFeedbackNotificationView(
        sessionType: "소개팅",
        elapsedTime: "00:15:38",
        message: "상대방의 호감도가 상\n승했습니다.\n현재 대화 주제를 이어\n가세요.",
        currentTime: "16:05"
    )
}
#endif 