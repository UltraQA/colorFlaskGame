import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    header
                    progressCard
                    actionArea
                }
                .padding(DSSpacing.lg)
            }
        }
        .navigationTitle("Color Flask")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("Sort colors. Fill flasks.")
                .font(DSTypography.largeTitle)
                .foregroundStyle(DSColor.textPrimary)

            Text("A clean SwiftUI foundation for the puzzle game.")
                .font(DSTypography.body)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    private var progressCard: some View {
        DSCard {
            HStack(spacing: DSSpacing.lg) {
                FlaskProgressView(progress: viewModel.progress)

                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    Text("Current run")
                        .font(DSTypography.title)
                        .foregroundStyle(DSColor.textPrimary)

                    metric(title: "Solved flasks", value: "\(viewModel.completedFlasks)/\(viewModel.totalFlasks)")
                    metric(title: "Moves", value: "\(viewModel.moves)")

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var actionArea: some View {
        Button {
            viewModel.startNewGame()
        } label: {
            Label("New Game", systemImage: "play.fill")
        }
        .buttonStyle(.dsPrimary)
        .accessibilityHint("Starts a new color sorting puzzle")
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            Text(title)
                .font(DSTypography.caption)
                .foregroundStyle(DSColor.textSecondary)

            Text(value)
                .font(DSTypography.headline)
                .foregroundStyle(DSColor.textPrimary)
        }
    }
}
