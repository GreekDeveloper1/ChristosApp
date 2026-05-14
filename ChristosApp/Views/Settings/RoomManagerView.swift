import SwiftUI

struct RoomManagerView: View {
    @EnvironmentObject private var discoveryVM: DeviceDiscoveryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newRoomName = ""
    @State private var newRoomIcon = "sofa"
    @State private var newRoomColor = "#2196F3"

    private let availableIcons = [
        "sofa", "bed.double", "fork.knife", "desktopcomputer",
        "car", "outdoor.thermometer", "tv", "gamecontroller",
        "music.note", "figure.walk"
    ]
    private let availableColors = [
        "#2196F3", "#9C27B0", "#FF9800", "#4CAF50",
        "#F44336", "#00BCD4", "#FF5722", "#607D8B"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()

                List {
                    // Add new room
                    Section("Add Room") {
                        VStack(spacing: 14) {
                            TextField("Room name", text: $newRoomName)
                                .padding(10)
                                .background(Color.appSurfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .foregroundColor(.appTextPrimary)

                            // Icon picker
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(availableIcons, id: \.self) { icon in
                                        Button {
                                            newRoomIcon = icon
                                        } label: {
                                            Image(systemName: icon)
                                                .font(.system(size: 20))
                                                .frame(width: 40, height: 40)
                                                .background(newRoomIcon == icon
                                                    ? Color.appAccent.opacity(0.3)
                                                    : Color.appSurfaceElevated)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .foregroundColor(newRoomIcon == icon ? .appAccent : .appTextSecondary)
                                        }
                                    }
                                }
                            }

                            // Color picker
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(availableColors, id: \.self) { hex in
                                        Circle()
                                            .fill(Color(hex: hex) ?? .blue)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle().stroke(Color.white, lineWidth: newRoomColor == hex ? 3 : 0)
                                            )
                                            .onTapGesture { newRoomColor = hex }
                                    }
                                }
                            }

                            Button("Add Room") {
                                guard !newRoomName.isEmpty else { return }
                                let room = Room(
                                    name: newRoomName,
                                    icon: newRoomIcon,
                                    colorHex: newRoomColor
                                )
                                discoveryVM.addRoom(room)
                                newRoomName = ""
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(newRoomName.isEmpty ? Color.appSurfaceElevated : Color.appAccent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .disabled(newRoomName.isEmpty)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.appSurface)
                    }

                    // Existing rooms
                    Section("Rooms (\(discoveryVM.rooms.count))") {
                        ForEach(discoveryVM.rooms) { room in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(room.color.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: room.icon)
                                        .foregroundColor(room.color)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(room.name)
                                        .foregroundColor(.appTextPrimary)
                                        .font(.system(size: 15, weight: .medium))
                                    let count = discoveryVM.devicesByRoom[room.id]?.count ?? 0
                                    Text("\(count) device\(count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.appTextSecondary)
                                }
                            }
                            .listRowBackground(Color.appSurface)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { i in
                                discoveryVM.deleteRoom(discoveryVM.rooms[i])
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Manage Rooms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
        }
    }
}
