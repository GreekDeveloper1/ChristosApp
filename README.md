# Christos App — Universal Remote Hub

**Made by Christos Papavas**

A professional iOS application that discovers and controls smart devices on your local network using Wi-Fi, Bluetooth LE, Bonjour/mDNS, SSDP/UPnP, Chromecast, and AirPlay protocols.

---

## Features

- **Animated radar scanning** across all discovery protocols simultaneously
- **Auto device detection** — Samsung, LG, Sony, Android TV, Apple TV, Chromecast, projectors, IoT
- **Full remote control** — D-pad, volume, media, number pad, channel controls
- **App launcher** — launch Netflix, YouTube, Disney+, and installed apps
- **Input/source selection** per device
- **"Turn Off All" button** for connected devices only
- **Favorites** with heart icon
- **Room grouping** with custom icons and colors
- **Connection history** with timestamps
- **Dark polished UI** with animated radar, glass cards, and haptic feedback

---

## Project Structure

```
ChristosApp/
├── ChristosApp.swift              # App entry + DI setup
├── Info.plist                     # Permissions + Bonjour types
├── Models/
│   ├── Device.swift               # Core device model
│   ├── DeviceType.swift           # Type/brand enums
│   ├── ConnectionStatus.swift     # Status enum
│   ├── DeviceCommand.swift        # All remote commands
│   └── Room.swift                 # Room grouping model
├── Services/
│   ├── Discovery/
│   │   ├── DeviceDiscoveryService.swift   # Orchestrator + de-dup
│   │   ├── BonjourDiscovery.swift         # mDNS / NWBrowser
│   │   ├── SSDPDiscovery.swift            # UDP M-SEARCH multicast
│   │   └── BLEDiscovery.swift             # CoreBluetooth wrapper
│   ├── Networking/
│   │   ├── NetworkManager.swift           # HTTP / URLSession
│   │   └── WebSocketManager.swift         # WebSocket / ping
│   └── Adapters/
│       ├── DeviceAdapter.swift            # Protocol + Factory
│       ├── SamsungTVAdapter.swift         # WebSocket port 8002
│       ├── LGWebOSAdapter.swift           # SSAP WebSocket port 3000
│       ├── SonyBraviaAdapter.swift        # HTTP JSON-RPC + SOAP IRCC
│       ├── AndroidTVAdapter.swift         # Android TV Remote REST
│       ├── AppleTVAdapter.swift           # MRP (port 7000)
│       └── ChromecastAdapter.swift        # CASTV2 TLS port 8009
├── Managers/
│   ├── BluetoothManager.swift     # CBCentralManager + delegate
│   ├── PersistenceManager.swift   # UserDefaults JSON
│   └── ConnectionHistoryManager.swift
├── ViewModels/
│   ├── DeviceDiscoveryViewModel.swift
│   ├── DeviceControlViewModel.swift
│   └── FavoritesViewModel.swift
├── Views/
│   ├── Main/
│   │   ├── SplashView.swift       # Animated logo + ring
│   │   ├── ContentView.swift      # Custom tab bar
│   │   └── HomeView.swift         # Main scan + device list
│   ├── Discovery/
│   │   ├── RadarScanView.swift    # Animated sonar radar
│   │   ├── DeviceCardView.swift   # Device row card
│   │   └── DeviceListView.swift   # Filterable device list
│   ├── Control/
│   │   ├── DeviceControlView.swift # Adaptive control hub
│   │   ├── TVControlView.swift     # D-pad + number pad
│   │   ├── MediaControlView.swift  # Play/pause/seek
│   │   └── AppLauncherView.swift   # App grid sheet
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── FavoritesView.swift
│   │   ├── RoomManagerView.swift
│   │   └── HistoryView.swift
│   └── Components/
│       ├── SignalStrengthView.swift
│       ├── ConnectionBadge.swift
│       └── RemoteButton.swift
└── Extensions/
    ├── Color+Theme.swift           # Dark theme palette
    └── View+Extensions.swift       # cardStyle, shimmer, haptic
```

---

## Xcode Setup

1. **Create a new Xcode project** → iOS App → SwiftUI → named `ChristosApp`
2. **Copy all Swift files** from this folder into the Xcode project, preserving the group structure
3. **Replace** the generated `ContentView.swift` and `Info.plist` with the ones provided
4. **Add capabilities** in Xcode → Signing & Capabilities:
   - `Bluetooth` (Background Modes → Uses Bluetooth LE accessories)
   - `Network Extensions` (if needed for advanced UPnP)
5. **Minimum deployment target**: iOS 17.0
6. **Build & run** on a real device (Bluetooth and local network require physical hardware)

---

## Device Protocol Reference

| Brand / Platform | Protocol | Port | Notes |
|-----------------|----------|------|-------|
| Samsung (Tizen) | WebSocket | 8002 (SSL) / 8001 | KEY_* commands |
| LG webOS | WebSocket SSAP | 3000 | Requires TV pairing (PIN on screen) |
| Sony Bravia | HTTP JSON-RPC + SOAP IRCC | 80 | PSK: set in TV Settings |
| Android TV / Google TV / Cosmote | REST API | 7676 | Android keycode commands |
| Apple TV | MRP (TLS) | 7000 / 49152+ | Companion Link pairing |
| Chromecast | CASTV2 (TLS + Protobuf) | 8009 | CASTV2 framing |
| Generic / IoT | HTTP | 80 | Reachability only |

---

## Privacy

- **Only controls local network and explicitly paired Bluetooth devices**
- No cloud, no telemetry, no remote access
- All communication stays on-device and on your local network

---

*Made by Christos Papavas — © 2025*
