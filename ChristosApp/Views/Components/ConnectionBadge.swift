import SwiftUI

struct ConnectionBadge: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 5) {
            if status.isTransitioning {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(status.color)
            } else {
                Circle()
                    .fill(status.color)
                    .frame(width: 7, height: 7)
                    .overlay(
                        Circle()
                            .stroke(status.color.opacity(0.4), lineWidth: 3)
                            .scaleEffect(status.isActive ? 1.8 : 1)
                            .opacity(status.isActive ? 0 : 1)
                            .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false),
                                       value: status.isActive)
                    )
            }
            Text(status.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.color.opacity(0.1))
        .clipShape(Capsule())
    }
}
