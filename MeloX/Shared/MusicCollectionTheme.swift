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
