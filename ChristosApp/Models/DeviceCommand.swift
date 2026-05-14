import Foundation

enum DeviceCommand: Equatable {
    // Power
    case powerOn
    case powerOff
    case powerToggle

    // Volume
    case volumeUp
    case volumeDown
    case volumeSet(Int)
    case mute
    case unmute
    case muteToggle

    // Navigation
    case up
    case down
    case left
    case right
    case select
    case back
    case home
    case menu

    // Media
    case play
    case pause
    case playPause
    case stop
    case rewind
    case fastForward
    case skipBack
    case skipForward
    case record

    // Input
    case setInput(String)
    case nextInput

    // Numbers
    case number(Int)

    // Channel
    case channelUp
    case channelDown
    case channelSet(Int)

    // App Launch
    case launchApp(AppInfo)

    // Custom
    case raw(String)

    var displayName: String {
        switch self {
        case .powerOn:      return "Power On"
        case .powerOff:     return "Power Off"
        case .powerToggle:  return "Power"
        case .volumeUp:     return "Vol +"
        case .volumeDown:   return "Vol -"
        case .volumeSet(let v): return "Vol \(v)"
        case .mute:         return "Mute"
        case .unmute:       return "Unmute"
        case .muteToggle:   return "Mute Toggle"
        case .up:           return "Up"
        case .down:         return "Down"
        case .left:         return "Left"
        case .right:        return "Right"
        case .select:       return "Select"
        case .back:         return "Back"
        case .home:         return "Home"
        case .menu:         return "Menu"
        case .play:         return "Play"
        case .pause:        return "Pause"
        case .playPause:    return "Play/Pause"
        case .stop:         return "Stop"
        case .rewind:       return "Rewind"
        case .fastForward:  return "Fast Forward"
        case .skipBack:     return "Skip Back"
        case .skipForward:  return "Skip Forward"
        case .record:       return "Record"
        case .setInput(let s): return "Input: \(s)"
        case .nextInput:    return "Next Input"
        case .number(let n): return "\(n)"
        case .channelUp:    return "Ch +"
        case .channelDown:  return "Ch -"
        case .channelSet(let c): return "Ch \(c)"
        case .launchApp(let a): return a.name
        case .raw(let s):   return s
        }
    }

    var systemImage: String {
        switch self {
        case .powerOn, .powerOff, .powerToggle: return "power"
        case .volumeUp:     return "speaker.plus"
        case .volumeDown:   return "speaker.minus"
        case .mute, .unmute, .muteToggle: return "speaker.slash"
        case .up:           return "chevron.up"
        case .down:         return "chevron.down"
        case .left:         return "chevron.left"
        case .right:        return "chevron.right"
        case .select:       return "return"
        case .back:         return "arrow.uturn.left"
        case .home:         return "house"
        case .menu:         return "list.bullet"
        case .play:         return "play.fill"
        case .pause:        return "pause.fill"
        case .playPause:    return "playpause.fill"
        case .stop:         return "stop.fill"
        case .rewind:       return "backward.fill"
        case .fastForward:  return "forward.fill"
        case .skipBack:     return "backward.end.fill"
        case .skipForward:  return "forward.end.fill"
        case .record:       return "record.circle"
        case .setInput:     return "input.hdmi"
        case .nextInput:    return "arrow.right.square"
        case .number(let n): return "\(n).circle"
        case .channelUp:    return "chevron.up.square"
        case .channelDown:  return "chevron.down.square"
        case .channelSet:   return "tv"
        case .launchApp:    return "app.fill"
        case .raw:          return "terminal"
        default:            return "questionmark.circle"
        }
    }
}

struct AppInfo: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let iconURL: URL?
    let deepLink: String?

    static let presets: [AppInfo] = [
        AppInfo(id: "netflix",  name: "Netflix",      iconURL: nil, deepLink: nil),
        AppInfo(id: "youtube",  name: "YouTube",      iconURL: nil, deepLink: nil),
        AppInfo(id: "prime",    name: "Prime Video",  iconURL: nil, deepLink: nil),
        AppInfo(id: "disney",   name: "Disney+",      iconURL: nil, deepLink: nil),
        AppInfo(id: "spotify",  name: "Spotify",      iconURL: nil, deepLink: nil),
        AppInfo(id: "twitch",   name: "Twitch",       iconURL: nil, deepLink: nil),
        AppInfo(id: "hbomax",   name: "Max",          iconURL: nil, deepLink: nil),
        AppInfo(id: "appletv+", name: "Apple TV+",    iconURL: nil, deepLink: nil),
    ]
}
