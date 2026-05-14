import SwiftUI
import CoreBluetooth

struct BLEScannerView: View {
    @EnvironmentObject private var bluetoothMgr: BluetoothManager
    @State private var selectedAdv: BLEAdvertisement?
    @State private var searchText = ""
    @State private var sortMode: SortMode = .rssi
    @State private var filterConnectable = false
    @State private var pulseOpacity: Double = 1

    enum SortMode: String, CaseIterable {
        case rssi    = "Signal"
        case name    = "Name"
        case newest  = "Recent"
    }

    private var filtered: [BLEAdvertisement] {
        var list = bluetoothMgr.sortedAdvertisements
        if filterConnectable { list = list.filter { $0.isConnectable } }
        if !searchText.isEmpty {
            list = list.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                ($0.companyName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.serviceUUIDs.contains { $0.uuidString.contains(searchText.uppercased()) }
            }
        }
        switch sortMode {
        case .rssi:   return list.sorted { $0.rssi > $1.rssi }
        case .name:   return list.sorted { $0.displayName < $1.displayName }
        case .newest: return list.sorted { $0.lastSeen > $1.lastSeen }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header stats bar
                    statsBar

                    // Search + filters
                    controlBar

                    // Device list
                    if bluetoothMgr.state != .poweredOn {
                        bluetoothOffState
                    } else if filtered.isEmpty && bluetoothMgr.isScanning {
                        scanningState
                    } else if filtered.isEmpty {
                        emptyState
                    } else {
                        deviceList
                    }
                }
            }
            .navigationTitle("BLE Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if bluetoothMgr.isScanning {
                            bluetoothMgr.stopScanning()
                        } else {
                            bluetoothMgr.clearResults()
                            bluetoothMgr.startScanning()
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            if bluetoothMgr.isScanning {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .opacity(pulseOpacity)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                                            pulseOpacity = 0.2
                                        }
                                    }
                                Text("Stop")
                                    .foregroundColor(.red)
                            } else {
                                Text("Scan")
                                    .foregroundColor(.green)
                            }
                        }
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        bluetoothMgr.clearResults()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(item: $selectedAdv) { adv in
                BLEDeviceDetailView(advertisement: adv, bluetoothMgr: bluetoothMgr)
            }
            .onAppear {
                if !bluetoothMgr.isScanning && bluetoothMgr.state == .poweredOn {
                    bluetoothMgr.startScanning()
                }
            }
            .onDisappear {
                bluetoothMgr.stopScanning()
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(value: "\(bluetoothMgr.totalSeen)", label: "TOTAL SEEN")
            Divider().frame(height: 30).background(Color.green.opacity(0.3))
            statItem(value: "\(filtered.count)", label: "SHOWING")
            Divider().frame(height: 30).background(Color.green.opacity(0.3))
            statItem(
                value: bluetoothMgr.sortedAdvertisements.filter { $0.isConnectable }.count.description,
                label: "CONNECTABLE"
            )
            Divider().frame(height: 30).background(Color.green.opacity(0.3))
            statItem(
                value: bluetoothMgr.isScanning ? "ON" : "OFF",
                label: "SCANNING",
                valueColor: bluetoothMgr.isScanning ? .green : .red
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(white: 0.05))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.green.opacity(0.2)), alignment: .bottom)
    }

    private func statItem(value: String, label: String, valueColor: Color = .green) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color.green.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 8) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.green)
                TextField("", text: $searchText, prompt:
                    Text("search name / company / uuid...").foregroundColor(Color.green.opacity(0.3))
                )
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.green)
                .tint(.green)
            }
            .padding(8)
            .background(Color(white: 0.07))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.green.opacity(0.25), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Sort + Filter row
            HStack(spacing: 8) {
                ForEach(SortMode.allCases, id: \.self) { mode in
                    Button {
                        sortMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(sortMode == mode ? .black : .green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(sortMode == mode ? Color.green : Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Spacer()
                Button {
                    filterConnectable.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filterConnectable ? "checkmark.square" : "square")
                            .font(.system(size: 12))
                        Text("Connectable")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundColor(filterConnectable ? .green : Color.green.opacity(0.4))
                }
            }
        }
        .padding(10)
        .background(Color(white: 0.04))
    }

    // MARK: - Device List

    private var deviceList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 2) {
                ForEach(filtered) { adv in
                    BLEDeviceRow(advertisement: adv)
                        .onTapGesture {
                            selectedAdv = adv
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color.black)
    }

    // MARK: - States

    private var scanningState: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("[ SCANNING ]")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
                .opacity(pulseOpacity)
            Text("Looking for BLE advertisements...")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color.green.opacity(0.5))
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("[ NO DEVICES ]")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(Color.green.opacity(0.6))
            Text("Tap SCAN to start")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color.green.opacity(0.3))
            Spacer()
        }
    }

    private var bluetoothOffState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("[ BLUETOOTH OFF ]")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.red)
            Text("Enable Bluetooth in Settings")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color.red.opacity(0.6))
            Spacer()
        }
    }
}

// MARK: - BLE Device Row (Flipper-style)
struct BLEDeviceRow: View {
    let advertisement: BLEAdvertisement
    @State private var flash = false

    var body: some View {
        HStack(spacing: 12) {
            // RSSI bar
            VStack(spacing: 2) {
                Text("\(advertisement.rssi)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(rssiColor)
                    .frame(width: 36)
                Text("dBm")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color.green.opacity(0.4))
            }

            // Signal bars
            SignalBars(rssi: advertisement.rssi)

            // Main info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(advertisement.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if advertisement.isConnectable {
                        Text("CONN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                if let company = advertisement.companyName {
                    Text("▸ \(company)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.green.opacity(0.7))
                }

                HStack(spacing: 8) {
                    if !advertisement.serviceUUIDs.isEmpty {
                        Text("SVC: \(advertisement.serviceUUIDs.count)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.cyan.opacity(0.7))
                    }
                    if advertisement.manufacturerData != nil {
                        Text("MFR")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.yellow.opacity(0.7))
                    }
                    if let tx = advertisement.txPowerLevel {
                        Text("TX:\(tx)dBm")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.orange.opacity(0.7))
                    }
                    Text("×\(advertisement.seenCount)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.3))
                }
            }

            Spacer(minLength: 0)

            // Time
            Text(timeAgo(advertisement.lastSeen))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(flash ? Color.green.opacity(0.05) : Color.clear)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.green.opacity(0.08)), alignment: .bottom)
        .onChange(of: advertisement.seenCount) { _, _ in
            withAnimation(.easeOut(duration: 0.15)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { flash = false }
            }
        }
    }

    private var rssiColor: Color {
        switch advertisement.rssi {
        case ..<(-80): return .red
        case -80 ..< -70: return .orange
        case -70 ..< -55: return .yellow
        default: return .green
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(-date.timeIntervalSinceNow)
        if s < 60 { return "\(s)s" }
        return "\(s/60)m"
    }
}

// MARK: - Signal Bars (Flipper style)
private struct SignalBars: View {
    let rssi: Int

    private var filledBars: Int {
        switch rssi {
        case ..<(-80): return 1
        case -80 ..< -70: return 2
        case -70 ..< -55: return 3
        default: return 4
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 4, height: CGFloat(i * 5))
                    .foregroundColor(i <= filledBars ? barColor : Color.white.opacity(0.1))
            }
        }
        .frame(width: 24, height: 22, alignment: .bottom)
    }

    private var barColor: Color {
        switch rssi {
        case ..<(-80): return .red
        case -80 ..< -70: return .orange
        case -70 ..< -55: return .yellow
        default: return .green
        }
    }
}
