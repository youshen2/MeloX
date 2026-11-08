import Foundation

extension ListenTogetherStore {
    func startMonitoring() {
        monitorTask?.cancel()
        suppressReportsUntil = Date.now.addingTimeInterval(1)
        monitorTask = Task { @MainActor [weak self] in
            await self?.monitorSession()
        }
    }

    private func monitorSession() async {
        var tick = 0
        while !Task.isCancelled, isInRoom {
            tick += 1
            await pollServer(
                includesRoomStatus: tick == 1 || tick.isMultiple(of: 5)
            )
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
        }
    }

    private func pollServer(
        includesRoomStatus: Bool
    ) async {
        do {
            try await synchronizeFromServer(initial: false)
            guard isInRoom else { return }

            if includesRoomStatus {
                try await refreshRoomStatus()
                guard isInRoom else { return }
                try await sendHeartbeat()
            }

            consecutiveSyncFailures = 0
            connectionState = .connected
            lastSyncDate = .now
        } catch is CancellationError {
            return
        } catch {
            consecutiveSyncFailures += 1
            if consecutiveSyncFailures >= 2 {
                connectionState = .reconnecting
            }
        }
    }

    func refreshRoomStatus() async throws {
        guard let expectedRoom = room else { return }
        let status = try await api.listenTogetherRoomStatus()
        guard status.isInRoom else {
            clearSession(notice: L10n.string("ui.listen_together.notice.room_ended"))
            return
        }
        guard let updatedRoom = status.roomInfo else { return }
        guard updatedRoom.id == expectedRoom.id else {
            clearSession(notice: L10n.string("ui.listen_together.notice.account_moved"))
            return
        }
        room = updatedRoom
        if let localUserID {
            isHost = updatedRoom.creatorID == String(localUserID)
        }
    }

    func synchronizeFromServer(initial: Bool) async throws {
        guard let room else { return }
        let payload = try await api.listenTogetherPlayback(
            roomID: room.id
        )
        let playlistSignature = signature(for: payload.playlist)
        let commandSignature = signature(for: payload.playCommand)
        let playlistChanged =
            playlistSignature != lastPlaylistSignature
        let commandChanged =
            commandSignature != lastCommandSignature

        guard initial || playlistChanged || commandChanged else {
            return
        }

        var songIDs = payload.playlist?.playbackSongIDs ?? []
        if songIDs.isEmpty {
            songIDs = player.queue.map(\.id)
        }

        let command = payload.playCommand
        let targetSongID = command?.targetSongNumericID
            ?? player.currentSong?.id
            ?? songIDs.first
        guard let targetSongID else {
            throw ListenTogetherSessionError.invalidPlaybackState
        }
        if !songIDs.contains(targetSongID) {
            songIDs.append(targetSongID)
        }

        let songs: [Song]
        if songIDs == player.queue.map(\.id) {
            songs = player.queue
        } else {
            songs = try await loadSongsPreservingOrder(ids: songIDs)
        }
        guard songs.contains(where: { $0.id == targetSongID }) else {
            throw ListenTogetherSessionError.invalidPlaybackState
        }

        let shouldPlay = command?.shouldPlay ?? player.isPlaying
        let progress = TimeInterval(
            command?.progressMilliseconds ?? Int64(
                (player.estimatedProgress() * 1_000).rounded()
            )
        ) / 1_000

        // Defer before opening the report-suppression window. A no-op poll
        // must not swallow the play command for the track now loading.
        if !shouldPlay,
           player.isPreparingListenTogetherAutoplay,
           player.currentSong?.id == targetSongID {
            return
        }

        isApplyingRemoteState = true
        suppressReportsUntil = Date.now.addingTimeInterval(1)
        defer { isApplyingRemoteState = false }
        let applied = await player.synchronizeListenTogetherPlayback(
            songs: songs,
            targetSongID: targetSongID,
            progress: progress,
            isPlaying: shouldPlay,
            shouldSeek: initial || commandChanged,
            // Polls must not copy the room play mode. Doing so clears a
            // local repeat or shuffle choice on every echoed command.
            adoptsRoomPlayMode: initial,
            playMode: payload.playlist?.playMode,
            commandType: command?.commandType
        )
        guard applied else {
            suppressReportsUntil = .distantPast
            return
        }

        lastPlaylistSignature = playlistSignature
        lastCommandSignature = commandSignature
    }

    private func loadSongsPreservingOrder(
        ids: [Int]
    ) async throws -> [Song] {
        var loadedByID: [Int: Song] = [:]
        var start = 0
        while start < ids.count {
            try Task.checkCancellation()
            let end = min(start + 100, ids.count)
            let page = try await api.songDetails(
                ids: Array(ids[start..<end])
            )
            for song in page {
                loadedByID[song.id] = song
            }
            start = end
        }
        return ids.compactMap { loadedByID[$0] }
    }

    private func signature(
        for playlist: ListenTogetherPlaylistSnapshot?
    ) -> String? {
        guard let playlist else { return nil }
        let ids = playlist.playbackSongIDs.map(String.init).joined(
            separator: ","
        )
        let versions = playlist.versions.map {
            "\($0.userID):\($0.version)"
        }.joined(separator: ",")
        return "\(playlist.playMode ?? "")|\(ids)|\(versions)"
    }

    private func signature(
        for command: ListenTogetherPlayCommand?
    ) -> String? {
        guard let command else { return nil }
        return [
            String(command.serverSequence),
            String(command.clientSequence),
            command.userID ?? "",
            command.commandType ?? "",
            command.targetSongID ?? "",
            String(command.progressMilliseconds),
            command.playStatus ?? "",
        ].joined(separator: "|")
    }
}
