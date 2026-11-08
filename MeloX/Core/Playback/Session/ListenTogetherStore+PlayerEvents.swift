import Foundation

extension ListenTogetherStore {
    func playerSongDidChange(
        from formerSongID: Int?,
        to targetSongID: Int?
    ) {
        guard shouldReportLocalChanges,
              let targetSongID else {
            return
        }
        Task { @MainActor [weak self] in
            guard let self,
                  self.shouldReportLocalChanges,
                  self.player.currentSong?.id == targetSongID else {
                return
            }
            await self.reportLocalCommand(
                type: .goTo,
                formerSongID: formerSongID,
                targetSongID: targetSongID
            )
        }
    }

    func playerPlaybackDidChange(isPlaying: Bool) {
        guard shouldReportLocalChanges,
              let songID = player.currentSong?.id else {
            return
        }
        if !isPlaying, player.isLoading || player.isPreparingListenTogetherAutoplay {
            return
        }
        Task { @MainActor [weak self] in
            guard let self,
                  self.shouldReportLocalChanges,
                  self.player.currentSong?.id == songID else {
                return
            }
            await self.reportLocalCommand(
                type: isPlaying ? .play : .pause,
                formerSongID: songID,
                targetSongID: songID
            )
        }
    }

    func playerDidSeek() {
        guard shouldReportLocalChanges,
              let songID = player.currentSong?.id else {
            return
        }
        Task { @MainActor [weak self] in
            guard let self,
                  self.shouldReportLocalChanges,
                  self.player.currentSong?.id == songID else {
                return
            }
            await self.reportLocalCommand(
                type: .progress,
                formerSongID: songID,
                targetSongID: songID
            )
        }
    }

    func playerQueueDidChange() {
        guard shouldReportLocalChanges else { return }
        queueReportTask?.cancel()
        queueReportTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard let self,
                      self.shouldReportLocalChanges else {
                    return
                }
                try await self.sendPlaylistSnapshot()
            } catch is CancellationError {
                return
            } catch {
                self?.connectionState = .reconnecting
            }
        }
    }

    private var shouldReportLocalChanges: Bool {
        isInRoom
            && !isApplyingRemoteState
            && Date.now >= suppressReportsUntil
            && operation != .leaving
    }

    func sendPlaylistSnapshot() async throws {
        guard let room,
              let localUserID else {
            throw ListenTogetherSessionError.missingAccount
        }
        let displaySongIDs = player.listenTogetherDisplaySongIDs
        guard !displaySongIDs.isEmpty else {
            throw ListenTogetherSessionError.noCurrentSong
        }
        let randomSongIDs = player.listenTogetherRandomSongIDs
        try await api.reportListenTogetherPlaylist(
            roomID: room.id,
            userID: localUserID,
            version: nextClientSequence(),
            displaySongIDs: displaySongIDs,
            randomSongIDs: randomSongIDs.isEmpty
                ? displaySongIDs
                : randomSongIDs
        )
    }

    func sendCurrentPlaybackCommand(
        type: ListenTogetherCommandType
    ) async throws {
        guard let songID = player.currentSong?.id else {
            throw ListenTogetherSessionError.noCurrentSong
        }
        try await sendCommand(
            type: type,
            formerSongID: songID,
            targetSongID: songID
        )
    }

    private func reportLocalCommand(
        type: ListenTogetherCommandType,
        formerSongID: Int?,
        targetSongID: Int
    ) async {
        do {
            try await sendCommand(
                type: type,
                formerSongID: formerSongID,
                targetSongID: targetSongID
            )
        } catch is CancellationError {
            return
        } catch {
            connectionState = .reconnecting
        }
    }

    private func sendCommand(
        type: ListenTogetherCommandType,
        formerSongID: Int?,
        targetSongID: Int
    ) async throws {
        guard let room else { return }
        try await api.reportListenTogetherCommand(
            roomID: room.id,
            commandType: type,
            progressMilliseconds: Int64(
                (player.estimatedProgress() * 1_000).rounded()
            ),
            isPlaying: player.listenTogetherReportedPlaying,
            formerSongID: formerSongID,
            targetSongID: targetSongID,
            clientSequence: nextClientSequence()
        )
    }

    func sendHeartbeat() async throws {
        guard let room,
              let songID = player.currentSong?.id else {
            return
        }
        try await api.sendListenTogetherHeartbeat(
            roomID: room.id,
            songID: songID,
            isPlaying: player.listenTogetherReportedPlaying,
            progressMilliseconds: Int64(
                (player.estimatedProgress() * 1_000).rounded()
            )
        )
    }

    private func nextClientSequence() -> Int {
        clientSequence += 1
        locallyReportedCommandSequences.append(clientSequence)
        if locallyReportedCommandSequences.count > 16 {
            locallyReportedCommandSequences.removeFirst(
                locallyReportedCommandSequences.count - 16
            )
        }
        return clientSequence
    }

    func commandOriginatedLocally(
        _ command: ListenTogetherPlayCommand?
    ) -> Bool {
        guard let command else { return false }
        if let userID = command.userID,
           let localUserID,
           userID == String(localUserID) {
            return true
        }
        // clientSeq is per device and both sides start at 1, so it is only
        // a hint when the server omitted userId.
        guard command.userID == nil, command.clientSequence > 0 else {
            return false
        }
        return locallyReportedCommandSequences.contains(
            Int(command.clientSequence)
        )
    }
}
