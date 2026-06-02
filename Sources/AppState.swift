import SwiftUI
import Combine

// MARK: - Preset Profiles

enum FocusPreset: String, CaseIterable, Identifiable {
    case ambient    = "Ambient"
    case deep       = "Deep"
    case monochrome = "Mono"
    case custom     = "Custom"

    var id: String { rawValue }
}

// MARK: - Observable App State

final class AppState: ObservableObject {

    // MARK: Toggles

    @Published var isEnabled: Bool = true {
        didSet { updateOverlays() }
    }

    @Published var selectedPreset: FocusPreset = .ambient {
        didSet {
            applyPreset(selectedPreset)
            updateOverlays()
        }
    }

    // MARK: Tunable Parameters

    @Published var blurStrength: Double    = 50.0  { didSet { markCustom() } }
    @Published var tintColor: Color        = .clear { didSet { markCustom() } }
    @Published var tintOpacity: Double     = 0.0   { didSet { markCustom() } }
    @Published var grainIntensity: Double  = 0.08  { didSet { markCustom() } }
    @Published var isMonochrome: Bool      = false  { didSet { markCustom() } }

    // MARK: Overlay Callback

    var onUpdateOverlays: (() -> Void)?

    // MARK: Init

    init() {
        if UserDefaults.standard.object(forKey: "isEnabled") != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")
            if let presetStr = UserDefaults.standard.string(forKey: "selectedPreset"),
               let preset = FocusPreset(rawValue: presetStr) {
                self.selectedPreset = preset
            }
            self.blurStrength = UserDefaults.standard.double(forKey: "blurStrength")
            self.tintOpacity = UserDefaults.standard.double(forKey: "tintOpacity")
            self.grainIntensity = UserDefaults.standard.double(forKey: "grainIntensity")
            self.isMonochrome = UserDefaults.standard.bool(forKey: "isMonochrome")
            if let data = UserDefaults.standard.data(forKey: "tintColor"),
               let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                self.tintColor = Color(nsColor)
            }
        }
    }

    // MARK: Private

    private var updatingPreset = false

    private func markCustom() {
        if !updatingPreset { selectedPreset = .custom }
        updateOverlays()
    }

    private func updateOverlays() {
        save()
        onUpdateOverlays?()
    }

    private func save() {
        UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
        UserDefaults.standard.set(selectedPreset.rawValue, forKey: "selectedPreset")
        UserDefaults.standard.set(blurStrength, forKey: "blurStrength")
        UserDefaults.standard.set(tintOpacity, forKey: "tintOpacity")
        UserDefaults.standard.set(grainIntensity, forKey: "grainIntensity")
        UserDefaults.standard.set(isMonochrome, forKey: "isMonochrome")
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(tintColor), requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: "tintColor")
        }
    }

    // MARK: Preset Application

    func applyPreset(_ preset: FocusPreset) {
        updatingPreset = true
        defer { updatingPreset = false }

        switch preset {
        case .ambient:
            blurStrength   = 50.0
            tintColor      = .clear
            tintOpacity    = 0.0
            grainIntensity = 0.08
            isMonochrome   = false

        case .deep:
            blurStrength   = 90.0
            tintColor      = .clear
            tintOpacity    = 0.0
            grainIntensity = 0.15
            isMonochrome   = false

        case .monochrome:
            blurStrength   = 40.0
            tintColor      = .clear
            tintOpacity    = 0.0
            grainIntensity = 0.05
            isMonochrome   = true

        case .custom:
            break
        }
    }
}
