import SwiftUI

struct BrandPickerSheet: View {
    let deviceName: String
    @Binding var selectedBrand: DeviceBrand
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    private struct BrandOption: Identifiable {
        let id: String          // unique per row, not per brand
        let brand: DeviceBrand
        let icon: String
        let description: String
    }

    private let brands: [BrandOption] = [
        BrandOption(id: "samsung",  brand: .samsung,  icon: "tv",                             description: "Samsung Smart TV (Tizen)"),
        BrandOption(id: "lg",       brand: .lg,       icon: "tv.fill",                        description: "LG Smart TV (webOS)"),
        BrandOption(id: "sony",     brand: .sony,     icon: "tv.and.hifispeaker.fill",        description: "Sony Bravia TV"),
        BrandOption(id: "google",   brand: .google,   icon: "tv.and.hifispeaker.fill",        description: "Android TV / Google TV"),
        BrandOption(id: "cosmote",  brand: .cosmote,  icon: "tv.and.hifispeaker.fill",        description: "Cosmote TV box (Android-based)"),
        BrandOption(id: "apple",    brand: .apple,    icon: "appletv",                        description: "Apple TV"),
        BrandOption(id: "cast",     brand: .google,   icon: "dot.radiowaves.left.and.right",  description: "Chromecast / Google Cast"),
        BrandOption(id: "epson",    brand: .epson,    icon: "videoprojector",                 description: "Epson / BenQ Projector"),
        BrandOption(id: "unknown",  brand: .unknown,  icon: "questionmark.circle",            description: "Other / Unknown"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "tv")
                            .font(.system(size: 36))
                            .foregroundStyle(LinearGradient.accentGradient)
                            .padding(.top, 24)
                        Text("What type of device is this?")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                        Text(deviceName)
                            .font(.subheadline)
                            .foregroundColor(.appAccentSecondary)
                    }
                    .padding(.bottom, 24)

                    // Brand list
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(brands) { item in
                                Button {
                                    selectedBrand = item.brand
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedBrand == item.brand
                                                    ? Color.appAccent.opacity(0.2)
                                                    : Color.appSurfaceElevated)
                                                .frame(width: 48, height: 48)
                                            Image(systemName: item.icon)
                                                .font(.system(size: 20))
                                                .foregroundColor(selectedBrand == item.brand
                                                    ? .appAccent : .appTextSecondary)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.description)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.appTextPrimary)
                                            Text(item.brand.rawValue)
                                                .font(.system(size: 12))
                                                .foregroundColor(.appTextSecondary)
                                        }

                                        Spacer()

                                        if selectedBrand == item.brand {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.appAccent)
                                                .font(.system(size: 20))
                                        }
                                    }
                                    .padding(14)
                                    .background(
                                        selectedBrand == item.brand
                                            ? Color.appAccent.opacity(0.08)
                                            : Color.appSurface
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                selectedBrand == item.brand
                                                    ? Color.appAccent.opacity(0.4)
                                                    : Color.appDivider,
                                                lineWidth: 1
                                            )
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Connect") {
                        onConfirm()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appAccent)
                }
            }
        }
    }
}
