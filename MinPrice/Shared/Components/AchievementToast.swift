import SwiftUI

/// Тост-ачивка — показывается из тёмного бэкграунда поверх всего контента
/// когда пользователь пробил milestone в SavingsWalletStore.
/// Конфетти + share + dismiss. Эмоциональный пик приложения.
struct AchievementToast: View {
    let milestone: SavingsWalletStore.Milestone
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var confettiTrigger = 0

    var body: some View {
        ZStack {
            // Затемнение фона
            Color.black.opacity(appeared ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            ConfettiBurst(trigger: confettiTrigger)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(milestone.emoji)
                    .font(.system(size: 64))
                    .scaleEffect(appeared ? 1.0 : 0.3)
                    .rotationEffect(.degrees(appeared ? 0 : -25))
                    .shadow(color: Color.savingsGreen.opacity(0.4), radius: 14, x: 0, y: 6)

                VStack(spacing: 6) {
                    Text("Достижение разблокировано!")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .kerning(1.0)
                        .foregroundStyle(Color.savingsGreen)

                    Text(milestone.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color.appForeground)

                    Text(milestone.subtitle)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.appMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                HStack(spacing: 10) {
                    ShareLink(item: shareText) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .bold))
                            Text("Поделиться")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(LinearGradient.brandPrimary, in: Capsule())
                        .shadow(color: Color.appPrimary.opacity(0.30), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)

                    Button("Спасибо") { dismiss() }
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.appMuted)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.appCard, in: Capsule())
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.6))
                        .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(28)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.savingsGreen.opacity(0.30), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1.0 : 0.85)
            .opacity(appeared ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                appeared = true
            }
            confettiTrigger += 1
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.22)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }

    private var shareText: String {
        "\(milestone.emoji) \(milestone.title)!\n\(milestone.subtitle)\n\nminprice.kz"
    }
}

// MARK: - Confetti

/// Простое конфетти на чистом SwiftUI — без внешних либ.
/// 60 кружочков-эмодзи разлетаются от центра экрана с физикой.
private struct ConfettiBurst: View {
    let trigger: Int

    private static let pieces: [String] = ["🎉", "💸", "💰", "✨", "🪙", "🛍️"]

    @State private var particles: [Particle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Text(p.emoji)
                        .font(.system(size: p.size))
                        .position(p.currentPos)
                        .opacity(p.opacity)
                        .rotationEffect(.degrees(p.rotation))
                }
            }
            .onChange(of: trigger) { _ in
                spawn(in: geo.size)
            }
            .onAppear { spawn(in: geo.size) }
        }
    }

    private func spawn(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.40)
        let count = 60
        var newParticles: [Particle] = []
        for i in 0..<count {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = Double.random(in: 100...360)
            let dx = CGFloat(cos(angle) * distance)
            let dy = CGFloat(sin(angle) * distance) - CGFloat.random(in: 30...90)
            let p = Particle(
                id: i,
                emoji: Self.pieces.randomElement() ?? "🎉",
                size: CGFloat.random(in: 18...28),
                start: center,
                end: CGPoint(x: center.x + dx, y: center.y + dy + 250),
                rotation: 0,
                rotationEnd: Double.random(in: -540...540)
            )
            newParticles.append(p)
        }
        particles = newParticles
        // Анимируем все частицы за один проход
        withAnimation(.easeOut(duration: 1.6)) {
            for i in particles.indices {
                particles[i].currentPos = particles[i].end
                particles[i].rotation = particles[i].rotationEnd
                particles[i].opacity = 0
            }
        }
        // Очистка через 2 сек чтобы не висели в памяти
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            particles = []
        }
    }

    fileprivate struct Particle: Identifiable {
        let id: Int
        let emoji: String
        let size: CGFloat
        var currentPos: CGPoint
        let end: CGPoint
        var rotation: Double
        let rotationEnd: Double
        var opacity: Double = 1.0

        init(id: Int, emoji: String, size: CGFloat, start: CGPoint, end: CGPoint, rotation: Double, rotationEnd: Double) {
            self.id = id
            self.emoji = emoji
            self.size = size
            self.currentPos = start
            self.end = end
            self.rotation = rotation
            self.rotationEnd = rotationEnd
        }
    }
}
