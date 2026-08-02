import SwiftUI

struct UnlockOfferSheet<Preview: View, Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Capsule()
                .fill(GameColor.controlAccent.opacity(0.26))
                .frame(width: 64, height: 6)

            VStack(spacing: DSSpacing.xs) {
                Text(title)
                    .font(DSTypography.title)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(subtitle)
                    .font(DSTypography.caption)
                    .foregroundStyle(GameColor.glassStroke.opacity(0.78))
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
        .padding(.top, DSSpacing.lg)
        .padding(.bottom, DSSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(GameColor.potionBackground)
    }
}

struct UnlockOfferAction: View {
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
                    .foregroundStyle(.white)
                    .frame(width: GameMetric.iconButtonSize, height: GameMetric.iconButtonSize)
                    .background(
                        Circle()
                            .fill(GameColor.controlAccent)
                    )

                VStack(spacing: DSSpacing.xxs) {
                    Text(title)
                        .font(DSTypography.headline)
                        .foregroundStyle(GameColor.glassStroke)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(subtitle)
                        .font(DSTypography.caption)
                        .foregroundStyle(GameColor.glassStroke.opacity(0.68))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(footnote)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(GameColor.glassStroke.opacity(0.48))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .fill(GameColor.controlSurface.opacity(0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .stroke(GameColor.glassStroke.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.62)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}
