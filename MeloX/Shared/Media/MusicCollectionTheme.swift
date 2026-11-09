import SwiftUI

extension ArtworkDetailPalette {
    var colorScheme: ColorScheme {
        prefersDarkAppearance ? .dark : .light
    }

    var backgroundColor: Color {
        Color(
            red: backgroundRGB.x,
            green: backgroundRGB.y,
            blue: backgroundRGB.z
        )
    }

    var edgeColor: Color {
        let rgb = tabletSourceRGB.map { $0 * 0.70 + SIMD3<Double>(repeating: 0.30) } ?? accentRGB
        return Color(red: rgb.x, green: rgb.y, blue: rgb.z)
    }

    func tabletPalette(usesLightAppearance: Bool) -> Self {
        let source = tabletSourceRGB ?? SIMD3<Double>(repeating: 0.5)
        let peak = max(source.x, source.y, source.z)
        let floor = min(source.x, source.y, source.z)
        let chroma = peak - floor
        let average = (source.x + source.y + source.z) / 3
        let neutral = SIMD3<Double>(repeating: average)
        let canvas: SIMD3<Double>

        if usesLightAppearance {
            canvas = SIMD3<Double>(repeating: 0.90) + (source - neutral) * 0.14
        } else {
            // Keep the hue on dark artwork without turning near-neutral covers into colored screens.
            let saturation = min(chroma / 0.22, 1)
            let hue = (source - SIMD3<Double>(repeating: floor)) / max(chroma, 0.001)
            let colored = SIMD3<Double>(repeating: 0.043) + hue * 0.195
            let charcoal = SIMD3<Double>(repeating: 0.055 + average * 0.105)
            canvas = charcoal + (colored - charcoal) * saturation
        }

        return Self(
            backgroundRGB: canvas,
            accentRGB: accentRGB,
            tabletSourceRGB: tabletSourceRGB,
            prefersDarkAppearance: !usesLightAppearance
        )
    }
}

struct TabletCollectionChrome {
    let id: UUID
    let palette: ArtworkDetailPalette?
}

extension EnvironmentValues {
    @Entry var tabletCollectionChrome: Binding<TabletCollectionChrome?>? = nil
}

private struct TabletCollectionChromeModifier: ViewModifier {
    @Environment(\.tabletCollectionChrome) private var chrome
    @State private var id = UUID()

    let palette: ArtworkDetailPalette?

    func body(content: Content) -> some View {
        content
            .onAppear {
                chrome?.wrappedValue = TabletCollectionChrome(id: id, palette: palette)
            }
            .onChange(of: palette) { _, palette in
                guard chrome?.wrappedValue?.id == id else { return }
                chrome?.wrappedValue = TabletCollectionChrome(id: id, palette: palette)
            }
            .onDisappear {
                guard chrome?.wrappedValue?.id == id else { return }
                chrome?.wrappedValue = nil
            }
    }
}

extension View {
    func tabletCollectionChrome(_ palette: ArtworkDetailPalette?) -> some View {
        modifier(TabletCollectionChromeModifier(palette: palette))
    }
}

func filterMusicCollectionTracks(_ tracks: [Song], query: String) -> [Song] {
    let keywords = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !keywords.isEmpty else { return tracks }
    return tracks.filter { song in
        song.name.localizedCaseInsensitiveContains(keywords)
            || song.artistText.localizedCaseInsensitiveContains(keywords)
            || (song.album?.name.localizedCaseInsensitiveContains(keywords) ?? false)
    }
}
