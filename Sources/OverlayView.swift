import Cocoa
import CoreImage
import SwiftUI

// MARK: - Blur Overlay View
//
// A full-screen NSView compositing layers:
//   1. Backdrop blur  – NSVisualEffectView (.behindWindow)
//   2. Colour tint    – solid CALayer with adjustable opacity
//   3. Film grain     – large organic noise pattern with jitter animation
//   4. Colour controls – CIFilter for monochrome / gain (exposure)
//
// The grain uses a 256×256 texture with variable-size noise particles
// and 8 random jitter keyframes for a cinematic film-stock look.

final class OverlayView: NSView {

    // MARK: Sub-layers

    private let blurView   = NSVisualEffectView()
    private let tintLayer  = CALayer()
    private let noiseLayer = CALayer()

    // MARK: Cached State

    private var lastNoiseIntensity: CGFloat = -1

    // MARK: Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBlur()
        setupTint()
        setupNoise()
    }

    required init?(coder: NSCoder) { fatalError("Not implemented") }

    // MARK: Layout

    override func layout() {
        super.layout()
        tintLayer.frame  = bounds
        // Oversized to allow jitter translation without exposing edges
        noiseLayer.frame = bounds.insetBy(dx: -200, dy: -200)
    }

    // MARK: Public API

    func applySettings(state: AppState) {
        applyBlurStrength(state.blurStrength)
        applyTint(colour: state.tintColor, opacity: state.tintOpacity)
        applyGrain(intensity: CGFloat(state.grainIntensity))
        applyColourControls(monochrome: state.isMonochrome)
    }

    /// Animate the overlay's opacity for a gradual fade-in / fade-out.
    func animateOpacity(to value: Float, duration: CFTimeInterval = 0.4) {
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = layer?.opacity ?? 0
        anim.toValue = value
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        layer?.add(anim, forKey: "fadeOverlay")
        layer?.opacity = value
    }

    // MARK: - Private Setup

    private func setupBlur() {
        blurView.state            = .active
        blurView.blendingMode     = .behindWindow
        blurView.autoresizingMask = [.width, .height]
        blurView.frame            = bounds
        addSubview(blurView)
    }

    private func setupTint() {
        tintLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(tintLayer)
    }

    private func setupNoise() {
        noiseLayer.autoresizingMask = []
        noiseLayer.opacity          = 0.8
        layer?.addSublayer(noiseLayer)
    }

    // MARK: - Private Updates

    /// Map 1–100 percentage to a continuous blur.
    /// Uses the strongest material and controls visibility via alphaValue.
    /// 1% = barely-there haze, 100% = fully opaque heavy blur.
    private func applyBlurStrength(_ percentage: Double) {
        blurView.material = .underWindowBackground
        blurView.alphaValue = CGFloat(max(0.05, min(1.0, percentage / 100.0)))
    }

    private func applyTint(colour: Color, opacity: Double) {
        tintLayer.backgroundColor = NSColor(colour).cgColor
        tintLayer.opacity         = Float(opacity)
    }

    private func applyGrain(intensity: CGFloat) {
        guard intensity != lastNoiseIntensity else { return }
        lastNoiseIntensity = intensity

        if intensity > 0 {
            noiseLayer.backgroundColor = generateFilmGrain(intensity: intensity)?.cgColor
            addJitterAnimationIfNeeded()
        } else {
            noiseLayer.backgroundColor = NSColor.clear.cgColor
            noiseLayer.removeAnimation(forKey: "jitter")
        }
    }

    private func applyColourControls(monochrome: Bool) {
        guard monochrome else {
            layer?.filters = nil
            return
        }
        guard let filter = CIFilter(name: "CIColorControls") else { return }
        filter.setDefaults()
        filter.setValue(0.0, forKey: kCIInputSaturationKey)
        layer?.filters = [filter]
    }

    // MARK: - Film Grain Generator
    //
    // Fine, dense, single-pixel monochrome grain — matching 35mm
    // photographic film stock. Every pixel gets independent noise
    // with Gaussian-distributed brightness for natural variance.

    private func generateFilmGrain(intensity: CGFloat) -> NSColor? {
        let size = 256
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let alpha = UInt8(min(255, 255.0 * intensity * 1.2))

        for i in stride(from: 0, to: pixels.count, by: 4) {
            // Sum of 3 uniform randoms ≈ Gaussian brightness distribution
            let r1 = Double(arc4random_uniform(256))
            let r2 = Double(arc4random_uniform(256))
            let r3 = Double(arc4random_uniform(256))
            let grey = UInt8(max(0, min(255, (r1 + r2 + r3) / 3.0)))
            pixels[i]     = grey
            pixels[i + 1] = grey
            pixels[i + 2] = grey
            pixels[i + 3] = alpha
        }

        let colourSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data:             &pixels,
            width:            size,
            height:           size,
            bitsPerComponent: 8,
            bytesPerRow:      size * 4,
            space:            colourSpace,
            bitmapInfo:       CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = ctx.makeImage() else { return nil }

        return NSColor(patternImage: NSImage(cgImage: cgImage, size: NSSize(width: size, height: size)))
    }

    // MARK: - Jitter Animation
    //
    // Gentle shimmer with tight offsets so the grain texture
    // feels alive without jumping around visibly.

    private func addJitterAnimationIfNeeded() {
        guard noiseLayer.animation(forKey: "jitter") == nil else { return }

        let anim = CAKeyframeAnimation(keyPath: "transform.translation")
        anim.values = [
            NSValue(size: CGSize(width:   0, height:   0)),
            NSValue(size: CGSize(width:  11, height:  -7)),
            NSValue(size: CGSize(width:  -9, height:  14)),
            NSValue(size: CGSize(width:  17, height:   5)),
            NSValue(size: CGSize(width: -13, height: -11)),
            NSValue(size: CGSize(width:   6, height:  19)),
            NSValue(size: CGSize(width: -16, height:  -3)),
            NSValue(size: CGSize(width:  14, height:  10)),
        ]
        anim.duration        = 0.08
        anim.repeatCount     = .infinity
        anim.calculationMode = .discrete
        noiseLayer.add(anim, forKey: "jitter")
    }
}
