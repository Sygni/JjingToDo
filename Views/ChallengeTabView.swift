//
//  ChallengeTabView.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/21/25.
//

import SwiftUI

struct ChallengeTabView: View {
    @State private var showMemoAlert = false
    @State private var currentType: String = "하기"
    @State private var memoText: String = ""

    //Animation effect
    @State private var showPoint = false
    
    // 20250429 Challenge 기능 추가 시작
    @StateObject private var challengeViewModel = ChallengeViewModel()
    @State private var showAddChallenge = false
    @State private var newChallengeTitle = ""
    
    let chugumiBackground = Color(hex: "#79e5cb").opacity(0.15)
    
    var body: some View {
        ZStack{
            chugumiBackground.ignoresSafeArea()
            
            //ScrollView {
                VStack(spacing: 8) {
                    // 🧘‍♀️ 추구미 영역 (ChugumiZone)
                    VStack() {
                        Text("🧘‍♀️ 추구미를 존중했나요? 🏋️‍♀️")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                        //.font(Font(UIFont(name: "HelveticaNeue", size: 22)!))
                            .foregroundColor(.primary)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.mint, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        //.overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#79e5cb"), lineWidth: 1))
                            .padding(.top, 16)
                        
                        HStack(spacing: 32) {
                            ChugumiBunnyButton(
                                imageName: "bunny_hold",
                                label: "참기",
                                type: "참기"
                            ) { selectedType in
                                currentType = selectedType
                                showMemoAlert = true
                            }
                            
                            ChugumiBunnyButton(
                                imageName: "bunny_do",
                                label: "하기",
                                type: "하기"
                            ) { selectedType in
                                currentType = selectedType
                                showMemoAlert = true
                            }
                        }
                    }
                    .padding()
                    
                    // 포인트 애니메이션
                    if showPoint {
                        Text("🎁 +160 🎉")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#79e5cb"))
                            .scaleEffect(showPoint ? 1.3 : 0.2) // 팡!
                            .opacity(showPoint ? 1 : 0.2)         // 서서히 사라짐
                            .offset(y: showPoint ? -70 : -150) // 살짝 위로 뜸
                            .onAppear {
                                // 초기 팡!
                                /*withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                 showPoint = true
                                 }*/
                                withAnimation(.interpolatingSpring(stiffness: 200, damping: 5)) {
                                    showPoint = true
                                }
                                // 사라지는 부분
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    withAnimation(.easeOut(duration: 0.6)) {
                                        showPoint = false
                                    }
                                }
                            }
                    }
                    
                    // 20250429 Challenge 기능 추가 시작
                    // ✨ 루틴 챌린지 영역 (ChallengeZone)
                    VStack(spacing: 8) {
                        HStack {
                            Text("🔥꾸준함이 재능을 이긴다💪")
                                .font(.title3)
                                .foregroundColor(.yellow)
                                .bold()
                            
                            Spacer()
                           
                            Button(action: {
                                showAddChallenge = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .sheet(isPresented: $showAddChallenge) {
                                AddChallengeView(
                                    title: $newChallengeTitle,
                                    onSave: {
                                        challengeViewModel.addChallenge(title: newChallengeTitle)
                                        newChallengeTitle = ""
                                        showAddChallenge = false
                                    },
                                    onCancel: {
                                        newChallengeTitle = ""
                                        showAddChallenge = false
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                        
                        ChallengeListInTabView(viewModel: challengeViewModel)
                            .frame(maxHeight: .infinity)   // 남은 공간 차지
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.clear)
                            //.shadow(radius: 3)
                    )
                    
                }
                .padding(.horizontal, 16)
                
                Spacer(minLength: 0)
            //}
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .alert("추구미 기록", isPresented: $showMemoAlert) {
            TextField("메모를 입력하세요 (선택)", text: $memoText)
            Button("확인") {
                ChugumiManager.shared.addChugumiAction(type: currentType, memo: memoText.isEmpty ? nil : memoText)
                memoText = "" // 초기화
                showPoint = true
                
                // 일정 시간 후 사라지게
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showPoint = false
                }
            }
            Button("취소", role: .cancel) {
                memoText = ""
            }
        } message: {
            Text("오늘의 나를 기록해볼까요?")
        }
    }
}
