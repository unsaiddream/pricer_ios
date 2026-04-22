import SwiftUI

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.35), location: 0.4),
                            .init(color: .clear, location: 0.8),
                        ],
                        startPoint: .init(x: phase, y: 0.5),
                        endPoint: .init(x: phase + 0.8, y: 0.5)
                    )
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.4
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
