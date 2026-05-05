import SwiftUI

/// Hero-карточка на главной — "сэкономлено с minprice".
/// Большой счётчик + прогресс-бар к следующему milestone + share.
/// Это лицо приложения: первое что видит пользователь, главный value-prop.
struct SavingsHero: View {
    @ObservedObject private var wallet = SavingsWalletStore.shared

    @State private var sparkleX: CGFloat = -120
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Group {
            if wallet.hasAnySavings {
                savingsCard
            } else {
                introCard
            }
        }
    }

    // MARK: - Saved state

    private var savingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("СЭКОНОМЛЕНО С MINPRICE")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .kerning(0.8)
                    }
                    .foregroundStyle(.white.opacity(0.88))

                    Text(formatPriceTg(wallet.totalSaved))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.55, dampingFraction: 0.7), value: wallet.totalSaved)
                        .scaleEffect(pulseScale)
                }
                Spacer(minLength: 8)
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.22), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 0.5))
                }
            }

            // Прогресс к следующему milestone
            progressSection
        }
        .padding(16)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.savingsGreen.opacity(0.30), radius: 14, x: 0, y: 8)
        .onAppear {
            // Бесконечно мигрирующий sparkle-блик создаёт ощущение жизни
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                sparkleX = 400
            }
        }
        .onChange(of: wallet.totalSaved) { _ in
            // Лёгкий пульс при инкременте — глаз цепляет
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                pulseScale = 1.08
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    pulseScale = 1.0
                }
            }
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        if let next = wallet.nextMilestone {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(next.emoji) \(next.title)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer()
                    Text("\(formatPriceTg(wallet.totalSaved)) / \(formatPriceTg(Double(next.rawValue)))")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.22))
                        Capsule().fill(.white)
                            .frame(width: geo.size.width * CGFloat(wallet.progressToNext))
                    }
                }
                .frame(height: 6)
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Все цели достигнуты — вы легенда minprice 👑")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
        }
    }

    private var heroBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.savingsGreen,
                    Color.savingsGreen.opacity(0.92),
                    Color.appPrimary,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Лёгкая стеклянная подсветка сверху
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top, endPoint: .center
            )
            // Sparkle-блик который ползёт по карточке
            Image(systemName: "sparkles")
                .font(.system(size: 90))
                .foregroundStyle(.white.opacity(0.10))
                .offset(x: sparkleX, y: -8)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Empty state

    private var introCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.22))
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text("Кошелёк экономии")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Покупайте через minprice — мы посчитаем сколько вы сэкономили")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.savingsGreen.opacity(0.22), radius: 10, x: 0, y: 5)
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                sparkleX = 400
            }
        }
    }

    // MARK: - Share

    private var shareText: String {
        let formatted = formatPriceTg(wallet.totalSaved)
        return "Я сэкономил \(formatted) с minprice.kz — приложением для сравнения цен в супермаркетах Казахстана 💸\n\nПопробуй: https://minprice.kz"
    }
}
