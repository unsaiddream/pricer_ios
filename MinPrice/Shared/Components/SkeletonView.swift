import SwiftUI

// MARK: - Shimmer modifier
// Правильный shimmer — диагональный градиент-полоса проходит по содержимому,
// маскируется через .mask чтобы блик отображался ТОЛЬКО на форме контента,
// а не вылазил за границы (как было раньше).

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let band = geo.size.width * 0.3
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.55), location: 0.5),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(width: band)
                    .offset(x: -band + (geo.size.width + band * 2) * phase)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

private let skeletonColor = Color.appBorder.opacity(0.6)

// MARK: - Card skeleton (used in HomeView grid)

struct SkeletonProductCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(skeletonColor)
                .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(height: 14)
                RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(width: 80, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(height: 12)
                RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(width: 100, height: 12)
            }
            .padding(10)
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shimmer()
    }
}

// MARK: - Row skeleton (used in Search, Discounts, Catalog)

struct SkeletonProductRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(skeletonColor)
                .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(height: 13)
                RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(width: 120, height: 11)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(width: 60, height: 14)
                RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(width: 40, height: 11)
            }
        }
        .padding(.vertical, 6)
        .shimmer()
    }
}

// MARK: - Grid skeleton (2-col)

private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct SkeletonCardGrid: View {
    var count: Int = 6

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonProductCard()
            }
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Product detail skeleton

struct SkeletonProductDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(skeletonColor)
                .frame(maxWidth: .infinity)
                .frame(height: 260)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(height: 18)
                    RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(width: 100, height: 14)
                }

                RoundedRectangle(cornerRadius: 12).fill(skeletonColor).frame(height: 72)

                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 6).fill(skeletonColor).frame(width: 30, height: 30)
                            RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(height: 14)
                            Spacer()
                            RoundedRectangle(cornerRadius: 4).fill(skeletonColor).frame(width: 70, height: 14)
                        }
                    }
                }
                .padding(14)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
        }
        .shimmer()
    }
}

// MARK: - Pagination indicator (used at bottom of paginated lists)

/// Пилюля "загружаю ещё..." вместо голого ProgressView внизу списка.
/// Дизайн консистентный с тостами — appCard + appBorder + spinner.
struct PaginationLoader: View {
    var text: String = "Загружаю ещё..."

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(Color.appPrimary)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.appCard, in: Capsule())
        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - List skeleton

struct SkeletonRowList: View {
    var count: Int = 8

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                SkeletonProductRow()
                if i < count - 1 {
                    Divider().overlay(Color.appBorder)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
