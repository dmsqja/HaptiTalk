//
//  SessionModeSelectionView.swift
//  HaptiTalkWatch Watch App
//
//  Created on 5/13/25.
//

#if os(watchOS)
import SwiftUI

@available(watchOS 6.0, *)
struct SessionModeSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    var onModeSelected: ((_ mode: String) -> Void)?
    
    let sessionModes = ["발표", "면접(인터뷰)"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                Text("세션 모드 선택")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 5)
                
                ForEach(sessionModes, id: \.self) { mode in
                    Button(action: {
                        // 선택한 모드로 세션 시작
                        presentationMode.wrappedValue.dismiss()
                        onModeSelected?(mode)
                    }) {
                        Text(mode)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color(.sRGB, red: 0.13, green: 0.13, blue: 0.13, opacity: 1.0)) // #212121
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(Color.black)
    }
}

@available(watchOS 6.0, *)
struct SessionModeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionModeSelectionView()
    }
}
#endif 