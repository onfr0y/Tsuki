import SwiftUI

// MARK: - Settings View (Control Centre)
//
// Redesigned to match the Monocle-style card layout:
// rounded grey cards with icon + label + wide slider.

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            headerSection
            controlsCard
            presetsCard
            appGroupsCard
            tipSection
        }
        .padding(20)
        .frame(width: 320)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("tsuki")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Aesthetic Centre")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $state.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Main Controls Card

    private var controlsCard: some View {
        VStack(spacing: 0) {
            // Blur row
            controlRow(
                icon: "drop.fill",
                iconColour: .white,
                label: "Blur",
                value: $state.blurStrength,
                range: 1...100,
                step: 1,
                tint: .blue
            )

            cardDivider

            // Tint row
            HStack(spacing: 12) {
                ColorPicker("", selection: $state.tintColor)
                    .labelsHidden()
                    .frame(width: 28, height: 28)

                Text("Tint")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 50, alignment: .leading)

                Slider(value: $state.tintOpacity, in: 0...1)
                    .tint(.gray)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            cardDivider

            // Grain row
            controlRow(
                icon: "water.waves",
                iconColour: .white,
                label: "Grain",
                value: $state.grainIntensity,
                range: 0...0.5,
                tint: .blue
            )

            cardDivider

            // Monochrome row
            HStack(spacing: 12) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)

                Text("Mono")
                    .font(.system(size: 15, weight: .medium))

                Spacer()

                Toggle("", isOn: $state.isMonochrome)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.mini)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Presets Card

    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Presets")
                .font(.system(size: 15, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.top, 14)

            HStack(spacing: 6) {
                ForEach(FocusPreset.allCases) { preset in
                    presetChip(preset)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - App Groups Card

    private var appGroupsCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("App Groups")
                    .font(.system(size: 15, weight: .bold))
                Text("Pair apps that stay focused together")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                // TODO: App Groups feature
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 30, height: 30)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Tip

    private var tipSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.wave")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Shake mouse to toggle")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.top, 2)
    }

    // MARK: - Reusable Components

    private var cardDivider: some View {
        Divider().padding(.horizontal, 16)
    }

    private func controlRow(
        icon: String,
        iconColour: Color,
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double? = nil,
        tint: Color = .blue
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColour)
                .frame(width: 28, height: 28)

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 50, alignment: .leading)

            Group {
                if let step = step {
                    Slider(value: value, in: range, step: step)
                } else {
                    Slider(value: value, in: range)
                }
            }
            .tint(tint)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func presetChip(_ preset: FocusPreset) -> some View {
        let isSelected = state.selectedPreset == preset
        return Button {
            state.selectedPreset = preset
        } label: {
            Text(preset.rawValue)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
