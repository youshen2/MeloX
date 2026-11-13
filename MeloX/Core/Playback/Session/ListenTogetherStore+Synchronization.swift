import Foundation

extension ListenTogetherStore {
    func startMonitoring() {
        monitorTask?.cancel()
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
        let session = sessionRevision
        do {
            try await synchronizeFromServer(initial: false)
            guard isInRoom, sessionRevision == session else { return }

            if includesRoomStatus {
                try await refreshRoomStatus()
                guard isInRoom, sessionRevision == session else { return }
                try await sendHeartbeat()
            }

            guard sessionRevision == session else { return }
            consecutiveSyncFailures = 0
            connectionState = .connected
            lastSyncDate = .now
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, sessionRevision == session else { return }
            consecutiveSyncFailures += 1
            if consecutiveSyncFailures >= 2 {
                connectionState = .reconnecting
            }
        }
    }

    func refreshRoomStatus() async throws {
        guard let expectedRoom = room else { return }
        let session = sessionRevision
        let status = try await api.listenTogetherRoomStatus()
        try Task.checkCancellation()
        guard sessionRevision == session else { return }
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
        guard let room, operation != .leaving else { return }
        let session = sessionRevision
        guard synchronizingSession != session, transportReportTask == nil,
              queueReportTask == nil else { return }
        synchronizingSession = session
        defer {
            if synchronizingSession == session {
                synchronizingSession = nil
            }
        }
        let revision = localChangeRevision
        let payload = try await api.listenTogetherPlayback(roomID: room.id)
        try Task.checkCancellation()
        guard sessionRevision == session, localChangeRevision == revision,
              operation != .leaving else { return }

        let playlistSignature = signature(for: payload.playlist)
        let commandSignature = signature(for: payload.playCommand)
        let playlistChanged = playlistSignature != lastPlaylistSignature
        let commandChanged = commandSignature != lastCommandSignature
        guard initial || playlistChanged || commandChanged else { return }

        let command = payload.playCommand
        let appliesTransport = initial || (
            commandChanged && command != nil && !commandOriginatedLocally(command)
        )
        if !appliesTransport, !playlistChanged {
            lastCommandSignature = commandSignature
            return
        }

        var songIDs = payload.playlist?.playbackSongIDs ?? []
        if songIDs.isEmpty {
            songIDs = player.queue.map(\.id)
        }
        let targetSongID = (appliesTransport ? command?.targetSongNumericID : nil)
            ?? player.currentSong?.id ?? songIDs.first
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
        try Task.checkCancellation()
        guard sessionRevision == session, localChangeRevision == revision,
              operation != .leaving else { return }
        guard songs.contains(where: { $0.id == targetSongID }) else {
            throw ListenTogetherSessionError.invalidPlaybackState
        }

        if appliesTransport {
            let shouldPlay = command?.shouldPlay ?? player.listenTogetherReportedPlaying
            let progress = command.map { TimeInterval($0.progressMilliseconds) / 1_000 }
                ?? player.estimatedProgress()
            await player.synchronizeListenTogetherPlayback(
                songs: songs,
                targetSongID: targetSongID,
                progress: progress,
                isPlaying: shouldPlay,
                adoptsRoomPlayMode: initial,
                playMode: payload.playlist?.playMode
            )
        } else {
            player.synchronizeListenTogetherQueue(songs: songs)
        }
        guard sessionRevision == session, operation != .leaving else { return }
        lastPlaylistSignature = playlistSignature
        lastCommandSignature = commandSignature
    }

    private func loadSongsPreservingOrder(
        ids: [Int]
    ) async throws -> [Song] {
        var loadedByID: [Int: Song] = [:]
        for song in player.queue {
            loadedByID[song.id] = song
        }
        let missingIDs = ids.filter { loadedByID[$0] == nil }
        var start = 0
        while start < missingIDs.count {
            try Task.checkCancellation()
            let end = min(start + 100, missingIDs.count)
            let page = try await api.songDetails(
                ids: Array(missingIDs[start..<end])
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
