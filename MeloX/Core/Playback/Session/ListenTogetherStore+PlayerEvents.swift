import Foundation

struct PendingListenTogetherTransportReport {
    let type: ListenTogetherCommandType
    let formerSongID: Int?
    let targetSongID: Int
    let isPlaying: Bool
    let progressMilliseconds: Int64
}

extension ListenTogetherStore {
    func playerTransportDidChange(
        type: ListenTogetherCommandType,
        formerSongID: Int?
    ) {
        guard isInRoom, operation != .leaving,
              let targetSongID = player.currentSong?.id else { return }
        localChangeRevision += 1
        let pending = pendingTransportReport
        let preservesTrackChange = pending?.type == .goTo
            && pending?.targetSongID == targetSongID
        let isPlaying: Bool
        switch type {
        case .play: isPlaying = true
        case .pause: isPlaying = false
        default: isPlaying = player.listenTogetherReportedPlaying
        }
        pendingTransportReport = PendingListenTogetherTransportReport(
            type: preservesTrackChange ? .goTo : type,
            formerSongID: preservesTrackChange ? pending?.formerSongID : formerSongID,
            targetSongID: targetSongID,
            isPlaying: isPlaying,
            progressMilliseconds: Int64((player.estimatedProgress() * 1_000).rounded())
        )
        guard transportReportTask == nil else { return }
        let session = sessionRevision
        transportReportTask = Task { @MainActor [weak self] in
            await self?.sendPendingTransportReports(session: session)
        }
    }

    private func sendPendingTransportReports(session: Int) async {
        defer {
            if sessionRevision == session {
                transportReportTask = nil
            }
        }
        // Merge nearby actions before sending. Once sent, finish that request
        // before starting the next one so it cannot overtake the newer action.
        while !Task.isCancelled, sessionRevision == session,
              pendingTransportReport != nil {
            do {
                try await Task.sleep(for: .milliseconds(40))
                guard sessionRevision == session, operation != .leaving,
                      let pending = pendingTransportReport else { return }
                pendingTransportReport = nil
                try await sendCommand(
                    type: pending.type,
                    formerSongID: pending.formerSongID,
                    targetSongID: pending.targetSongID,
                    isPlaying: pending.isPlaying,
                    progressMilliseconds: pending.progressMilliseconds
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, sessionRevision == session else { return }
                connectionState = .reconnecting
            }
        }
    }

    func playerQueueDidChange() {
        guard isInRoom, operation != .leaving else { return }
        localChangeRevision += 1
        queueReportTask?.cancel()
        queueReportRevision += 1
        let session = sessionRevision
        let revision = queueReportRevision
        queueReportTask = Task { @MainActor [weak self] in
            defer {
                if let self, self.sessionRevision == session,
                   self.queueReportRevision == revision {
                    self.queueReportTask = nil
                }
            }
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, let self,
                      self.sessionRevision == session,
                      self.operation != .leaving else { return }
                try await self.sendPlaylistSnapshot()
            } catch {
                guard !Task.isCancelled, let self,
                      self.sessionRevision == session else { return }
                self.connectionState = .reconnecting
            }
        }
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
        clientSequence += 1
        try await api.reportListenTogetherPlaylist(
            roomID: room.id,
            userID: localUserID,
            version: clientSequence,
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

    private func sendCommand(
        type: ListenTogetherCommandType,
        formerSongID: Int?,
        targetSongID: Int,
        isPlaying: Bool? = nil,
        progressMilliseconds: Int64? = nil
    ) async throws {
        guard let room else { return }
        clientSequence += 1
        locallyReportedCommandSequences.append(clientSequence)
        if locallyReportedCommandSequences.count > 16 {
            locallyReportedCommandSequences.removeFirst()
        }
        try await api.reportListenTogetherCommand(
            roomID: room.id,
            commandType: type,
            progressMilliseconds: progressMilliseconds ?? Int64(
                (player.estimatedProgress() * 1_000).rounded()
            ),
            isPlaying: isPlaying ?? player.listenTogetherReportedPlaying,
            formerSongID: formerSongID,
            targetSongID: targetSongID,
            clientSequence: clientSequence
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

    func commandOriginatedLocally(_ command: ListenTogetherPlayCommand?) -> Bool {
        guard let command,
              let localUserID,
              command.userID == String(localUserID),
              let sequence = Int(exactly: command.clientSequence) else { return false }
        return locallyReportedCommandSequences.contains(sequence)
    }
}
