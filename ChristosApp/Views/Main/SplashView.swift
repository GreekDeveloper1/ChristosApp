import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var showMain = false

    var body: some View {
        ZStack {
            LinearGradient.appBackground.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Animated logo
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.appAccent.opacity(0.25 - Double(i) * 0.07), lineWidth: 1.5)
                            .frame(width: CGFloat(100 + i * 44), height: CGFloat(100 + i * 44))
                            .scaleEffect(ringScale)
                            .opacity(ringOpacity)
                            .animation(
                                .spring(response: 0.8, dampingFraction: 0.5)
                                    .delay(Double(i) * 0.12),
                                value: ringScale
                            )
                    }

                    ZStack {
                        Circle()
                            .fill(LinearGradient.accentGradient)
                            .frame(width: 90, height: 90)
                            .shadow(color: Color.appAccent.opacity(0.6), radius: 24)

                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                }

                VStack(spacing: 8) {
                    Text("Christos App")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextPrimary)

                    Text("Universal Remote Hub")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.appAccentSecondary)
                        .tracking(2)
                        .textCase(.uppercase)
                }
                .opacity(logoOpacity)

                Spacer()

                Text("Made by Christos Papavas")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appTextSecondary)
                    .opacity(logoOpacity)
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
                ringScale = 1.0
                ringOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showMain = true
                }
            }
        }
        .fullScreenCover(isPresented: $showMain) {
            ContentView()
        }
    }
}
