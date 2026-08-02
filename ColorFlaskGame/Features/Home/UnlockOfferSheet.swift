import SwiftUI

struct UnlockOfferSheet<Preview: View, Actions: View>: View {
    @Environment(\.gameTheme) private var theme
    let title: String
    let subtitle: String
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            Capsule()
                .fill(theme.primaryAccent.opacity(0.26))
                .frame(width: 64, height: 6)
                .padding(.bottom, DSSpacing.xs)

            VStack(spacing: DSSpacing.xs) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.76)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(DSTypography.caption)
                    .foregroundStyle(theme.textPrimary.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            preview()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DSSpacing.lg) {
                    actions()
                }

                VStack(spacing: DSSpacing.md) {
                    actions()
                }
            }
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.top, DSSpacing.xl)
        .padding(.bottom, DSSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(theme.backgroundPrimary)
    }
}

struct UnlockOfferAction: View {
    @Environment(\.gameTheme) private var theme
    let systemName: String
    let title: String
    let subtitle: String
    let footnote: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DSSpacing.sm) {
                Image(systemName: systemName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(width: GameMetric.iconButtonSize, height: GameMetric.iconButtonSize)
                    .background(
                        Circle()
                            .fill(theme.primaryAccent)
                    )

                VStack(spacing: DSSpacing.xxs) {
                    Text(title)
                        .font(DSTypography.headline)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(subtitle)
                        .font(DSTypography.caption)
                        .foregroundStyle(theme.textPrimary.opacity(0.68))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(footnote)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textPrimary.opacity(0.48))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .fill(theme.surface.opacity(0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .stroke(theme.softAccent.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.62)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}
