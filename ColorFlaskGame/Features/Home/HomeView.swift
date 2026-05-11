import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let columns = 3

    private enum Layer {
        static let background: Double = 0
        static let placeholder: Double = 1
        static let gameUI: Double = 10
        static let animation: Double = 20
    }

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            DSColor.background
                .ignoresSafeArea()
                .zIndex(Layer.background)

            ZStack {
                resetButton
                    .position(resetButtonCenter(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets))
                    .zIndex(Layer.placeholder)

                ForEach(Array(viewModel.gameManager.flasks.enumerated()), id: \.element.id) { index, flask in
                    Button {
                        viewModel.handleFlaskTap(at: index)
                    } label: {
                        FlaskTubeView(
                            flask: flask,
                            isSelected: viewModel.selectedFlaskIndex == index
                        )
                    }
                    .buttonStyle(.plain)
                    .position(flaskCenter(for: index, in: proxy.size))
                    .zIndex(Layer.gameUI)
                }

                if let animation = viewModel.pourAnimation {
                    PourStreamView(
                        from: pourStartPoint(for: animation.sourceIndex, in: proxy.size),
                        to: pourEndPoint(for: animation.targetIndex, in: proxy.size),
                        color: animation.color
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(Layer.animation)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var resetButton: some View {
        Button {
            viewModel.startNewGame()
        } label: {
            ZStack {
                Text("reset")
                    .font(DSTypography.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .zIndex(Layer.placeholder)

                Image("ResetButton")
                    .resizable()
                    .scaledToFill()
                    .zIndex(Layer.gameUI)
            }
            .frame(width: 104, height: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset")
    }

    private func flaskCenter(for index: Int, in size: CGSize) -> CGPoint {
        let column = index % columns
        let row = index / columns
        let horizontalPadding: CGFloat = 36
        let verticalCenter = size.height * 0.5
        let cellWidth = (size.width - horizontalPadding * 2) / CGFloat(columns)
        let rowSpacing: CGFloat = min(220, size.height * 0.28)

        return CGPoint(
            x: horizontalPadding + cellWidth * (CGFloat(column) + 0.5),
            y: verticalCenter + (CGFloat(row) - 0.5) * rowSpacing
        )
    }

    private func pourStartPoint(for index: Int, in size: CGSize) -> CGPoint {
        let center = flaskCenter(for: index, in: size)
        return CGPoint(x: center.x, y: center.y - 92)
    }

    private func pourEndPoint(for index: Int, in size: CGSize) -> CGPoint {
        let center = flaskCenter(for: index, in: size)
        return CGPoint(x: center.x, y: center.y - 76)
    }

    private func resetButtonCenter(in size: CGSize, safeAreaInsets: EdgeInsets) -> CGPoint {
        CGPoint(
            x: size.width / 2,
            y: size.height - safeAreaInsets.bottom - 72
        )
    }
}
