import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyMgr: ConnectionHistoryManager
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()

                Group {
                    if historyMgr.history.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 48))
                                .foregroundStyle(LinearGradient.accentGradient)
                            Text("No history yet")
                                .font(.title3.bold())
                                .foregroundColor(.appTextPrimary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(historyMgr.history) { entry in
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.appAccent.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(.appAccent)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.deviceName)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.appTextPrimary)
                                        Text("Connected: \(Self.dateFormatter.string(from: entry.connectedAt))")
                                            .font(.caption)
                                            .foregroundColor(.appTextSecondary)
                                        if let dc = entry.disconnectedAt {
                                            Text("Disconnected: \(Self.dateFormatter.string(from: dc))")
                                                .font(.caption)
                                                .foregroundColor(.appTextSecondary.opacity(0.7))
                                        }
                                    }
                                }
                                .listRowBackground(Color.appSurface)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Connection History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { historyMgr.clearHistory() }
                        .foregroundColor(.appDanger)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
    }
}
