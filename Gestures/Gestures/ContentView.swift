//
//  ContentView.swift
//  Gestures
//
//  Created by Ella Wang on 9/22/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View { DJEmojiMixer() }
}

// Helpers
@inline(__always)
private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
    Swift.min(Swift.max(v, lo), hi)
}

@inline(__always)
private func avg(_ xs: [CGFloat]) -> CGFloat? {
    guard !xs.isEmpty else { return nil }
    return xs.reduce(0, +) / CGFloat(xs.count)
}

// Main View (Multi-Touch + FX visuals)
struct DJEmojiMixer: View {
    // Track touches (id -> location)
    @State private var touches: [String: CGPoint] = [:]

    // App state
    @State private var scratch: CGFloat = 0.5   // 0...1 (one finger horizontal)
    @State private var crossfade: CGFloat = 0.0 // 0...1 (two-finger average X)
    @State private var fxOn: Bool = false       // FX toggled by 3+ fingers
    @State private var fxArmed: Bool = true     // toggle once per 3+ finger gesture

    // Emoji
    private let deckA: [String] = ["😀","😃","😄","😁","😆","🥳"]
    private let deckB: [String] = ["😐","😑","😒","😤","😡","🤬"]

    var body: some View {
        ZStack {
            AnimatedBackgroundLite(active: fxOn)

            VStack(spacing: 28) {
                Text("DJ Emoji Mixer")
                    .font(.title.bold())
                    .foregroundColor(.white)

                GeometryReader { geo in
                    let disc: CGFloat = min(geo.size.width, geo.size.height) * 0.75

                    ZStack {
                        // Disc base
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 2))
                            .frame(width: disc, height: disc)

                        // Groove rings
                        ForEach(0..<7, id: \.self) { i in
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                .frame(width: disc * (1 - CGFloat(i) * 0.1),
                                       height: disc * (1 - CGFloat(i) * 0.1))
                        }

                        // Bouncy emoji
                        BouncyEmojiLite(emoji: currentEmoji(), fxActive: fxOn, baseSize: disc * 0.42)

                        // Sparkles
                        if fxOn {
                            SparkleOverlayLite()
                                .frame(width: disc, height: disc)
                                .allowsHitTesting(false)
                        }

                        // FX label
                        if fxOn {
                            Text("✨ FX ✨")
                                .foregroundColor(.yellow)
                                .font(.headline)
                                .offset(y: disc * 0.58)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 330)

                // Debug
                VStack(spacing: 6) {
                    Text("Touches: \(touches.count)")
                    Text("Scratch: \(String(format: "%.2f", scratch))")
                    Text("Crossfade: \(String(format: "%.2f", crossfade))")
                    Text("FX: \(fxOn ? "ON" : "OFF")  (3+ fingers toggles)")
                }
                .foregroundColor(.white.opacity(0.9))
                .font(.callout)
            }
            .padding()
        }
        //
        .gesture(
            SpatialEventGesture()
                .onChanged { events in
                    for event in events {
                        switch event.phase {
                        case .active:
                            touches["\(event.id)"] = event.location
                        case .ended, .cancelled:
                            touches["\(event.id)"] = nil
                        @unknown default:
                            touches["\(event.id)"] = nil
                        }
                    }
                    handleTouches()
                }
                .onEnded { events in
                    for event in events {
                        touches["\(event.id)"] = nil
                    }
                    handleTouches()
                }
        )
    }

    // Touch handling
    private func handleTouches() {
        let count: Int = touches.count

        if count == 1, let loc = touches.values.first {
            let screenW: CGFloat = UIScreen.main.bounds.width
            let denom: CGFloat = Swift.max(1, screenW)
            scratch = clamp(loc.x / denom, 0, 1)
        }

        if count == 2 {
            let xs: [CGFloat] = touches.values.map { $0.x }
            if let avgX = avg(xs) {
                let screenW: CGFloat = UIScreen.main.bounds.width
                let denom: CGFloat = Swift.max(1, screenW)
                crossfade = clamp(avgX / denom, 0, 1)
            }
        }

        // 3+ fingers: toggle FX once, then re-arm when <3
        if count >= 3 {
            if fxArmed {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    fxOn.toggle()
                }
                fxArmed = false
            }
        } else {
            fxArmed = true
        }
    }

    private func currentEmoji() -> String {
        let n: Int = deckA.count
        let idxFloat: CGFloat = scratch * CGFloat(Swift.max(1, n - 1))
        let idx: Int = Swift.max(0, Swift.min(Int(round(idxFloat)), n - 1))
        return crossfade < 0.5 ? deckA[idx] : deckB[idx]
    }
}

// Lightweight Animated Background (hue shift when FX active)
struct AnimatedBackgroundLite: View {
    var active: Bool

    private var baseGradient: LinearGradient {
        LinearGradient(
            colors: [Color.purple, Color.blue, Color.cyan],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate
            let hueAngle: Angle = .degrees(active ? sin(t * 20) * 40 : 0)
            baseGradient
                .hueRotation(hueAngle)
                .ignoresSafeArea()
        }
    }
}

// Bouncy Emoji (bob + pulse + slight hue wobble in FX)
struct BouncyEmojiLite: View {
    let emoji: String
    let fxActive: Bool
    let baseSize: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate
            let bob: CGFloat = fxActive ? CGFloat(sin(t * 4.0)) * (baseSize * 0.04) : 0
            let scale: CGFloat = fxActive ? 1 + 0.05 * CGFloat(sin(t * 3.0)) : 1
            let hue: Angle = .degrees(fxActive ? sin(t * 30) * 10 : 0)

            Text(emoji)
                .font(.system(size: baseSize))
                .scaleEffect(scale)
                .offset(y: bob)
                .hueRotation(hue)
                .animation(nil, value: fxActive) // Timeline drives it
        }
    }
}

// Sparkles 
struct SparkleOverlayLite: View {
    private let count: Int = 48

    var body: some View {
        TimelineView(.animation) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                let w: CGFloat = geo.size.width
                let h: CGFloat = geo.size.height
                let cx: CGFloat = w / 2
                let cy: CGFloat = h / 2
                let baseR: CGFloat = min(w, h) * 0.45

                ZStack {
                    ForEach(0..<count, id: \.self) { i in
                        let seed: Double = Double(i) * 0.37
                        let angle: Double = seed.truncatingRemainder(dividingBy: .pi * 2)
                        let flutter: CGFloat = 0.8 + 0.2 * CGFloat(sin(t * 0.7 + seed))
                        let r: CGFloat = baseR * flutter
                        let x: CGFloat = cx + CGFloat(cos(angle)) * r
                        let y: CGFloat = cy + CGFloat(sin(angle)) * r
                        let size: CGFloat = 2 + abs(CGFloat(sin(t * 1.3 + seed))) * 3
                        let alpha: Double = 0.15 + 0.85 * abs(sin(t * 0.9 + seed))

                        Circle()
                            .fill(Color.white.opacity(alpha))
                            .frame(width: size, height: size)
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .blur(radius: 0.5)
    }
}


#Preview {
    ContentView()
}
