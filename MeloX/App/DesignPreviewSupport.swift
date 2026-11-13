#if DEBUG && targetEnvironment(simulator)
import Foundation

/// Simulator UI checks use a local queue and original placeholder lyrics.
/// This code is excluded from device and Release builds.
enum MeloXDesignPreview {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["MELOX_UI_PREVIEW"] == "1"
    }

    static let covers = [
        "https://p2.music.126.net/HXfXIIBCk5w96MiY1Wdsqw==/109951171836610847.jpg",
        "https://p2.music.126.net/ltPnu_JI1o70hz1INwzFYg==/109951166557803274.jpg",
        "https://p2.music.126.net/e5cvcdgeosDKTDrkTfZXnQ==/109951166155165682.jpg",
    ]

    static var songs: [Song] {
        let names = ["此刻的音乐", "午后漫游", "夜色与旋律", "重新出发", "晴空", "晚安电台"]
        return names.enumerated().map { index, name in
            Song(
                id: 900_000 + index,
                name: name,
                artists: [Artist(id: 900_000, name: "MeloX")],
                album: Album(id: 900_000 + index, name: "音乐时刻", picURL: covers[index % covers.count]),
                durationMS: 214_000
            )
        }
    }

    static var lyricLines: [LyricLine] {
        ["让音乐陪着你", "走过明亮的午后", "留住此刻的旋律", "在每一次呼吸之间", "听见属于你的声音", "让今天慢一点"]
            .enumerated().map { index, text in
                LyricLine(time: Double(index * 12), duration: 12, text: text)
            }
    }

    static var toplist: Playlist {
        let tracks = (0..<12).map { index in
            Song(
                id: 901_000 + index,
                name: ["此刻的音乐", "午后漫游", "夜色与旋律", "重新出发", "晴空", "晚安电台"][index % 6],
                artists: [Artist(id: 900_000, name: "MeloX")],
                album: Album(id: 901_000 + index, name: "音乐时刻", picURL: covers[index % covers.count]),
                durationMS: 214_000
            )
        }
        return Playlist(
            id: 3778678,
            name: "热歌榜",
            coverURLString: "https://p1.music.126.net/0SUEG8yDACfx0Bw2MYFv4Q==/109951170048519512.jpg",
            playlistDescription: "云音乐热歌榜，每日更新。",
            trackCount: tracks.count,
            updateFrequency: "每日更新",
            toplistType: "hot",
            tracks: tracks,
            trackIDs: tracks.map { TrackReference(id: $0.id) }
        )
    }

    static var explorePlaylists: [Playlist] {
        let names = ["今天从旋律听起", "重温你的收藏", "私人雷达", "轻松一刻", "让今天的旋律慢一点，和你一起走过明亮的午后", "午后漫游", "夜晚的陪伴", "专注与放松", "流行新声", "心动旋律", "晚安电台", "晴空音乐"]
        return names.enumerated().map { index, title in
            Playlist(
                id: 902_000 + index,
                name: title,
                coverURLString: covers[index % covers.count],
                trackCount: 24,
                playCount: 35_000,
                copywriter: "为你推荐"
            )
        }
    }

    static var homeFallbacks: [HomeRecommendationSlot: HomeRecommendationFallback] {
        let names = ["为你精选", "轻松时刻", "流行新声", "夜晚的陪伴", "专注与放松", "心动旋律"]
        let playlists = names.enumerated().map { index, name in
            Playlist(
                id: 900_000 + index,
                name: name,
                coverURLString: covers[index % covers.count],
                trackCount: 24,
                copywriter: "精选音乐 · 随时聆听"
            )
        }
        return [
            .recommendedPlaylists: HomeRecommendationFallback(title: .standard, content: .playlists(playlists)),
            .recentlyTrending: HomeRecommendationFallback(title: .standard, content: .songs(songs)),
        ]
    }
}
#endif
