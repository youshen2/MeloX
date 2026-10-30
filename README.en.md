# MeloX

[简体中文](README.md) | [English](README.en.md)

[![License](https://img.shields.io/github/license/youshen2/MeloX)](https://github.com/youshen2/MeloX/blob/master/LICENSE)
[![Download](https://img.shields.io/github/v/release/youshen2/MeloX)](https://github.com/youshen2/MeloX/releases)
[![stars](https://img.shields.io/github/stars/youshen2/MeloX)](https://github.com/youshen2/MeloX/stargazers)

<p align="center">
  A third-party NetEase Cloud Music player built with native SwiftUI for iPhone, iPad, Mac, and Apple Watch
</p>

[![Website](https://img.shields.io/badge/MeloX-Visit_Website-red?style=for-the-badge&logo=music&logoColor=red)](https://melox.luoxe.cn)

[![Telegram Group](https://img.shields.io/badge/Telegram-Join_Group-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/melox_official)

> MeloX is an unofficial open-source project and is not affiliated with, sponsored by, or authorized by NetEase Cloud Music or its related companies. The project is under active development, and APIs or features may stop working when the NetEase Cloud Music service changes.

> [!IMPORTANT]
> **The Apple Watch version is still under development.** Its features, interactions, and data compatibility are not yet stable and should not be treated as production-ready.

## Disclaimer

This project is developed for learning and research. MeloX adds no restrictions beyond those imposed by GPLv3 on the main application code. Third-party code, assets, and models remain subject to their own licenses. Users are responsible for complying with local laws, the NetEase Cloud Music terms of service, and the copyright requirements of music content.

The project is provided without warranty, as described by its licenses. You assume all risks arising from its use.

Delete downloaded copies within 24 hours.

## Screenshots

### MeloX Desktop (macOS)

MeloX Desktop uses a Mac-native sidebar, multi-column content area, and persistent bottom player. Its wider layout keeps browsing, lyrics, and the play queue close at hand. The immersive player combines artwork, word-synced lyrics, playback controls, and volume, and can switch between lyrics and queue sidebars. Synced lyrics can also remain visible beside the Home page.

The desktop app also provides an autoplay queue, playlist details designed for horizontal space, and direct access to messages, Music Cloud Drive, downloads, and settings. The website provides Developer ID-signed and Apple-notarized DMGs for Apple silicon and Intel. GitHub Releases provide separate unsigned CI builds for both architectures. See the [MeloX website](https://melox.luoxe.cn/) for details and downloads.

<p align="center">
  <img src="https://melox.luoxe.cn/mac/home.png" alt="MeloX Desktop Home" width="48%">
  <img src="https://melox.luoxe.cn/mac/immersive-player.png" alt="MeloX Desktop immersive player" width="48%">
  <br>
  <img src="https://melox.luoxe.cn/mac/lyrics-pane.png" alt="MeloX Desktop lyrics pane" width="48%">
  <img src="https://melox.luoxe.cn/mac/queue.png" alt="MeloX Desktop play queue" width="48%">
  <br>
  <img src="https://melox.luoxe.cn/mac/playlist.png" alt="MeloX Desktop playlist details" width="48%">
  <img src="https://melox.luoxe.cn/mac/account.png" alt="MeloX Desktop account" width="48%">
</p>

### Main Screens

<p align="center">
  <img src="docs/screenshots/0.png" alt="Home" width="20%">
  <img src="docs/screenshots/1.png" alt="Explore" width="20%">
  <img src="docs/screenshots/2.png" alt="Library" width="20%">
  <br>
  <img src="docs/screenshots/3.png" alt="Search" width="20%">
  <img src="docs/screenshots/13.png" alt="Playlist" width="20%">
</p>

### Private Messages

<p align="center">
  <img src="docs/screenshots/11.png" alt="Private messages" width="30%">
  <img src="docs/screenshots/12.png" alt="Share to a private message" width="30%">
</p>

### Player

> The lyrics view implements animations similar to Apple Music, including staggered lines, per-word glow, and selectable word- or character-based lift effects.

<p align="center">
  <img src="docs/screenshots/4.png" alt="Now Playing" width="20%">
  <img src="docs/screenshots/5.png" alt="Lyrics" width="20%">
  <img src="docs/screenshots/14.png" alt="Play queue" width="20%">
</p>

### Landscape Player

<p align="center">
  <img src="docs/screenshots/6.png" alt="Landscape Now Playing" width="20%">
  <img src="docs/screenshots/7.png" alt="Landscape lyrics" width="20%">
</p>

### Featured: Full-Screen Skyline Lyrics

Inspired by the Xiaomi YU7 Skyline Display.

<p align="center">
  <img src="docs/screenshots/9.png" alt="Full-screen Skyline lyrics" width="60%">
</p>

### Featured: Text PV Lyrics

The templates, visual effects, and original implementation of Text PV come from [PV Tool](https://github.com/DanteAlighieri13210914/pv-tool) by DanteAlighieri13210914 (Copyright © 2026 DanteAlighieri13210914).

MeloX ports this work to native SwiftUI and renders it in real time from lyric playback progress. It currently includes 18 styles, configurable effect intensity and animation speed, and full-screen player support.

> **License notice:** Text PV templates, effects, and related derivative content are separately governed by the PV Tool [Non-Commercial License](MeloX/Resources/PVTool-LICENSE.txt) and may only be used for non-commercial purposes. The MeloX GPLv3 license does not supersede that license. Commercial products, paid services, and commercial integrations require separate permission from the original author. See the [commercial licensing notice](MeloX/Resources/PVTool-COMMERCIAL.md).

<p align="center">
  <img src="docs/screenshots/8.png" alt="Text PV lyrics" width="60%">
</p>

### EVA-Style Lyrics (?)

<p align="center">
  <img src="docs/screenshots/10.png" alt="EVA-style lyrics" width="30%">
</p>

### Apple Watch (In Development)

The watch app currently supports independent sign-in, search, daily recommendations, playlist browsing, local playback, and synchronized lyrics. The player uses horizontal paging.

> The watch app remains under active development. Its feature scope, interface, and minimum system requirements may change.

<p align="center">
  <img src="docs/screenshots/15.png" alt="Watch playlist" width="40%">
  <img src="docs/screenshots/16.png" alt="Watch player" width="40%">
  <img src="docs/screenshots/17.png" alt="Watch lyrics" width="40%">
</p>
<p align="center">
  <img src="docs/screenshots/18.png" alt="Watch settings" width="40%">
</p>

## Features

- Listen Together
- Heart Mode
- Song recognition
- Private Roaming
- Private Radar
- Similar songs
- Similar-song autoplay

- Personalized Home recommendations
- Editor's picks
- Daily recommendations
- Recommended playlists
- Featured playlists
- Playlist categories
- Charts
- Hot Songs chart
- Popular artists
- New albums
- New releases
- Personalized new-song recommendations
- Recently popular tracks
- Regional popular tracks
- Liked-song roaming
- Liked-song recommendations
- Personal playlists
- Listened-podcast recommendations

- Search suggestions and text completion
- Song search
- Album search
- Artist search
- Playlist search
- Podcast search
- Song details
- Playlist details
- Album details
- Artist details
- Artist follow controls and a followed artists library
- Song wiki
- Song comments
- Comment replies

- Featured podcasts
- Personalized podcast recommendations
- Podcast episode recommendations
- Podcast category browsing
- Podcast details
- Podcast episode lists
- Podcast episode details
- Podcast episode search
- Podcast subscriptions
- Podcast playback

- Official NetEase Cloud Music web sign-in
- User profile
- Liked songs
- Saved playlists
- Saved albums
- Create public and private playlists
- Delete owned playlists
- Add songs to playlists
- Remove songs from owned playlists
- Playback history
- NetEase Cloud Music listening-record sync
- NetEase Cloud Music listening-time sync
- Music Cloud Drive
- Cloud Drive uploads
- Cloud Drive deletion

- NetEase Cloud Music private messages
- Private-message contacts
- Text messages
- Share content to private messages
- Repost to activity feed
- System share sheet

- Standard quality
- Higher quality
- Lossless quality
- Hi-Res quality
- HD surround sound
- Immersive surround sound
- Master quality
- Mini player
- Portrait player
- Landscape player
- Play queue
- Add to play queue
- Queue reordering
- Shuffle
- Repeat all
- Repeat one
- Playback seeking
- System volume
- Independent volume
- Background playback
- Lock-screen metadata
- System media controls
- Headphone and audio-route handling
- Playback-state restoration
- Smart AutoMix
- Fixed crossfade
- Tempo matching
- 10-band graphic equalizer
- Equalizer presets
- Flowing-light background
- Blurred-artwork background
- Downbeat vignette
- Keep player screen awake

- Song downloads
- Multi-select downloads
- Playlist batch downloads
- Album batch downloads
- Chart batch downloads
- Multiple download quality levels
- Offline playback
- Automatic caching by play count
- Download task management
- Local download management

- LRC line-synced lyrics
- Official YRC word-synced lyrics
- Synthesized word timing
- Translated lyrics
- Romanized lyrics
- Apple Music-style lyrics
- EVA-style lyrics
- Text PV lyrics
- Full-screen Skyline lyrics
- Per-word highlighting
- Word-based lift
- Character-based lift
- Per-word glow
- Long-note expansion
- Intro and interlude countdowns
- Seek from lyrics
- Lyric sharing
- Automatic lyric following
- Lyric timing offset
- Floating lyrics
- Picture-in-Picture lyric controls
- Lyrics in system Now Playing metadata
- Notification lyrics
- Live Activity lyrics
- Dynamic Island lyrics

- Native iPhone interface
- Native iPad interface
- Mac-native sidebar and multi-column interface
- Persistent Mac bottom player
- Immersive Mac player
- Mac lyrics and play-queue sidebars
- Mac floating lyrics and mini player
- Mac keyboard and system media controls
- Native Apple silicon and Intel builds
- Light and dark themes
- Customizable Home
- Customizable tab bar
- Customizable Library
- First-launch onboarding
- Automatic update checks
- Release notes

- Independent Apple Watch sign-in
- Account sync between Apple Watch and iPhone
- Apple Watch song search
- Apple Watch daily recommendations
- Apple Watch playlist browsing
- Independent Apple Watch playback
- Apple Watch play queue
- Apple Watch playback modes
- Apple Watch playback-state restoration
- Apple Watch word-synced lyrics
- Apple Watch translated lyrics
- Apple Watch romanized lyrics

## Smart AutoMix

Smart AutoMix uses a Core ML conversion of the general-purpose [BeatNet](https://github.com/mjhydri/BeatNet) model by Mojtaba Heydari to analyze beats, downbeats, tempo, and opening energy on device.

MeloX uses a fixed 32-second window and an FP16 Core ML ML Program. MeloX performs feature extraction and temporal decoding on device. The model is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See the [BeatNet model notice](MeloX/Resources/Models/BeatNet/BeatNet-NOTICE.md) for conversion and attribution details.

## Requirements

- Xcode 27.1 or later
- iOS / iPadOS 26.0 or later
- macOS 15.0 or later
- watchOS 10.0 or later (the watch app remains under development)
- Swift 5
- An Apple Developer account capable of code signing when running on physical devices

## Local Build

1. Clone the repository:

   ```bash
   git clone https://github.com/youshen2/MeloX.git MeloX
   cd MeloX
   ```

2. Open the project in Xcode:

   ```bash
   open MeloX.xcodeproj
   ```

3. Select the `MeloX` target for mobile or `MeloX Desktop` for Mac. Set your development team under Signing & Capabilities and, if necessary, replace the Bundle Identifier with a unique value.

4. Select a compatible iPhone, iPad, Mac, or simulator, then build and run.

No additional backend service or third-party API endpoint is required.

## Project Structure

```text
.
├── MeloX/
│   ├── App/                  # App entry points, root views, and app navigation
│   ├── Core/
│   │   ├── Artwork/          # Artwork color and visual data
│   │   ├── Cloud/            # Cloud Drive models and state
│   │   ├── Downloads/        # Download storage and transfers
│   │   ├── Library/          # Account library state and collection actions
│   │   ├── Lyrics/           # LRC / YRC models and parsing
│   │   ├── Models/           # Business models grouped by account, music, network, and social features
│   │   ├── Networking/       # NetEase Cloud Music APIs and direct request clients
│   │   ├── Playback/         # AutoMix, playback engine, equalizer, queue, and media sessions
│   │   ├── Settings/         # App, lyrics, and playback preferences
│   │   └── Updates/          # Version and update services
│   ├── Features/
│   │   ├── Player/           # Now Playing, lyric renderers, Text PV, and play queue
│   │   ├── Settings/         # Account, app, lyrics, playback, and system settings
│   │   └── …                 # Home, Explore, Search, Library, and other features
│   ├── Shared/
│   │   ├── Components/       # Shared state and helper views
│   │   └── Media/            # Artwork, media cards, and track rows
│   ├── Resources/            # Fonts, Core ML models, and licenses
│   └── Assets.xcassets/      # App icons, accent colors, and image assets
├── MeloXDesktop/             # Native Mac desktop app
│   ├── App/                  # Desktop windows, commands, and navigation
│   ├── Core/                 # Desktop state, playback, and storage
│   ├── Features/             # Desktop Home, details, player, and settings
│   └── Shared/               # Desktop media cards and shared views
├── MeloXLocalization/        # Shared semantic localization APIs for iOS, macOS, and watchOS
└── MeloXWatch/               # Independent Apple Watch app (in development)
    ├── Playback/             # Watch player, queue, and state restoration
    ├── Player/               # Now Playing, live queue, and playback modes
    ├── Lyrics/               # Synchronized watch lyrics
    └── …                     # Sign-in, discovery, settings, and connectivity
```

## Known Limitations

- NetEase Cloud Music does not publicly guarantee long-term API stability. Server changes may break individual features.
- Preview access, full playback, quality levels, and regional availability depend on the NetEase Cloud Music account, licensing, and server policy.
- MeloX is not intended to bypass payment, copyright, or regional restrictions.
- The Apple Watch version remains under development and does not yet guarantee complete features or data compatibility.
- macOS DMGs on GitHub Releases are unsigned CI builds. Download Developer ID-signed and Apple-notarized builds from the website.

## Shareholders

Thanks to the following shareholder for supporting MeloX. The list is for acknowledgement only and is not ranked.

- J1 Champ1on

## Special Thanks

- [jayfunc/BetterLyrics](https://github.com/jayfunc/BetterLyrics): reference for word-synced lyric rendering, lighting, and animation.
- [WXRIW/Lyricify-Lyrics-Helper](https://github.com/WXRIW/Lyricify-Lyrics-Helper): reference for NetEase YRC word-synced lyric parsing.
- [qier222/YesPlayMusic](https://github.com/qier222/YesPlayMusic): reference for NetEase Cloud Music APIs and player behavior.
- [DanteAlighieri13210914/pv-tool](https://github.com/DanteAlighieri13210914/pv-tool): original Text PV templates and visual effects.
- [dimitris-c/AudioStreaming](https://github.com/dimitris-c/AudioStreaming): Audio streaming engine for iOS and macOS.
- [mjhydri/BeatNet](https://github.com/mjhydri/BeatNet): beat, downbeat, and tempo analysis model used by AutoMix.

The code and resources from these projects remain subject to their original licenses.

## License

The main MeloX application code is released under the [GNU General Public License version 3](LICENSE). When copying, modifying, or distributing this project, comply with the license requirements for source availability, copyright notices, and distribution under the same license. The `LICENSE` file is authoritative.

Third-party code, assets, and models remain subject to their respective licenses, including:

- PV Tool-derived content uses the [Non-Commercial License](MeloX/Resources/PVTool-LICENSE.txt). It is limited to non-commercial use; commercial use requires separate permission from the original author.
- The BeatNet general-purpose model and its Core ML conversion use the [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/) license. Use and redistribution must preserve appropriate attribution, a link to the license, and a description of changes. See the [conversion and attribution notice](MeloX/Resources/Models/BeatNet/BeatNet-NOTICE.md).
