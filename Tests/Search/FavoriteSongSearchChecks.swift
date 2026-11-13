import Foundation

@main
struct FavoriteSongSearchChecks {
    static func main() {
        func matches(_ query: String, title: String = "花の塔", artist: String = "さユり", album: String? = "酸欠少女") -> Bool {
            FavoriteSongSearch.matches(query: query, title: title, artist: artist, album: album)
        }

        precondition(matches("花の塔"))
        precondition(matches("さユり"))
        precondition(matches("酸欠"))
        precondition(matches("  花の塔   さユり  "))
        precondition(matches(""))
        precondition(matches(" \n\t "))
        precondition(!matches("知らない曲"))
        precondition(!matches("花の塔 知らない歌手"))
        precondition(matches("PRINCESS", title: "Keep Your Head Up Princess", artist: "Anson Seabra", album: nil))
        precondition(matches("cafe", title: "Café", album: nil))
        precondition(matches("ABC", title: "ＡＢＣ", album: nil))
        precondition(!matches("酸欠", album: nil))
        print("Favorite song search: 12 checks passed")
    }
}
