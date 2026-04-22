import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var dotPhase: Int = 0

    private let timer = Timer.publish(every: 0.38, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Логотип
                ZStack {
                    // Внешнее кольцо пульс
                    Circle()
                        .stroke(Color.appPrimary.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 112, height: 112)
                        .scaleEffect(ringScale)
                        .opacity(logoOpacity)

                    // Фон иконки
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appPrimary, Color.appPrimary.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 86, height: 86)
                        .shadow(color: Color.appPrimary.opacity(0.35), radius: glowRadius, x: 0, y: 6)

                    // Знак тенге
                    Text("₸")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Spacer().frame(height: 28)

                // Название
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("min")
                            .font(.custom("JetBrainsMono-Bold", size: 28))
                            .foregroundStyle(Color.appForeground)
                        Text("price")
                            .font(.custom("JetBrainsMono-Bold", size: 28))
                            .foregroundStyle(Color.appPrimary)
                        Text(".kz")
                            .font(.custom("JetBrainsMono-Medium", size: 20))
                            .foregroundStyle(Color.appMuted)
                            .baselineOffset(-2)
                    }

                    Text("Лучшие цены города")
                        .font(.custom("JetBrainsMono-Regular", size: 13))
                        .foregroundStyle(Color.appMuted)
                        .kerning(0.3)
                }
                .opacity(textOpacity)

                Spacer()

                // Точки загрузки
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(dotPhase == i ? Color.appPrimary : Color.appBorder)
                            .frame(width: 6, height: 6)
                            .scaleEffect(dotPhase == i ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dotPhase)
                    }
                }
                .opacity(textOpacity)
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                logoScale = 1.0
                logoOpacity = 1.0
                ringScale = 1.15
                glowRadius = 18
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                textOpacity = 1.0
            }
        }
        .onReceive(timer) { _ in
            dotPhase = (dotPhase + 1) % 3
        }
    }
}
