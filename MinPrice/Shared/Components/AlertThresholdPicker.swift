import SwiftUI

/// Sheet выбора порога снижения для price-alert уведомлений.
/// Доступные значения: 3, 5, 10, 15, 20, 30%. По умолчанию 5%.
/// Чем выше порог — тем меньше уведомлений (только сильные движения).
struct AlertThresholdPicker: View {
    @Binding var threshold: Int
    @Environment(\.dismiss) private var dismiss

    private let options = PriceAlertManager.availableThresholds

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Порог уведомлений")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.appForeground)
                Text("Уведомим когда цена в избранном упадёт\nне меньше чем на")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 14)

            // Большое число — выбранный порог
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("−\(threshold)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .kerning(-2)
                    .foregroundStyle(Color.savingsGreen)
                    .contentTransition(.numericText())
                Text("%")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Color.savingsGreen.opacity(0.6))
            }

            // Сегментированный picker
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { opt in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            threshold = opt
                        }
                        HapticManager.selection()
                    } label: {
                        Text("\(opt)%")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(threshold == opt ? .white : Color.appForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                threshold == opt ? Color.savingsGreen : Color.appCard,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(threshold == opt ? Color.clear : Color.appBorder, lineWidth: 0.6)
                            )
                            .shadow(
                                color: threshold == opt ? Color.savingsGreen.opacity(0.30) : .clear,
                                radius: 6, x: 0, y: 2
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            // Контекст: понимание частоты
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .bold))
                Text(hint)
                    .font(.system(size: 12, design: .rounded))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color.appMuted)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            Button { dismiss() } label: {
                Text("Готово")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient.brandPrimary, in: Capsule())
                    .shadow(color: Color.appPrimary.opacity(0.30), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var hint: String {
        switch threshold {
        case ...3:    return "Будет много уведомлений — даже на мелкие колебания"
        case 4...7:   return "Сбалансированный вариант — уведомления только о заметных скидках"
        case 8...15:  return "Только сильные снижения — реже, но важнее"
        default:      return "Только большие распродажи — крайне редко"
        }
    }
}
