import SwiftUI

struct SignalStrengthView: View {
    let level: SignalLevel

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 4, height: CGFloat(bar) * 4)
                    .foregroundColor(bar <= level.rawValue ? barColor : Color.appTextSecondary.opacity(0.3))
            }
        }
    }

    private var barColor: Color {
        switch level {
        case .poor:      return .appDanger
        case .fair:      return .appWarning
        case .good:      return .appSuccess.opacity(0.8)
        case .excellent: return .appSuccess
        }
    }
}
