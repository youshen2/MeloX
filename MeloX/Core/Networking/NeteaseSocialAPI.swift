import Foundation

extension NeteaseAPI {
    func privateMessageConversations(
        offset: Int = 0,
        limit: Int = 50
    ) async throws -> [NeteasePrivateConversation] {
        let path = "/api/msg/private/users"
        let data: [String: Any] = [
            "offset": offset,
            "limit": limit,
            "total": "true",
        ]
        let response: NeteasePrivateConversationsResponse = try await socialRequest(
            path,
            data: data
        )
        try validate(responseCode: response.code, message: response.message)
        return response.messages
    }

    func privateMessageHistory(
        userID: Int,
        before: Int64? = nil,
        limit: Int = 100
    ) async throws -> [NeteasePrivateMessage] {
        let path = "/api/msg/private/history"
        let data: [String: Any] = [
            "userId": userID,
            "limit": limit,
            // 网易云网页端首次打开会话时发送 -1。这个首次加载请求同时
            // 承担服务端已读上报；0 只会返回历史记录，不会清除未读状态。
            "time": before ?? -1,
            "total": "true",
        ]
        let response: NeteasePrivateMessageHistoryResponse = try await socialRequest(
            path,
            data: data
        )
        try validate(responseCode: response.code, message: response.message)
        return response.messages.sorted { $0.time < $1.time }
    }

    func sendPrivateText(
        _ message: String,
        to userIDs: [Int]
    ) async throws {
        let recipients = Array(Set(userIDs)).sorted()
        guard !recipients.isEmpty else {
            throw NeteaseSocialError.noRecipient
        }

        let response: APIStatusResponse = try await client.eapi(
            "/api/msg/private/send",
            data: [
                "type": "text",
                "msg": message,
                "userIds": "[\(recipients.map(String.init).joined(separator: ","))]",
            ],
            authenticated: true
        )
        try validate(responseCode: response.code, message: response.message)
    }

    func messageContacts(
        userID: Int,
        pageSize: Int = 100,
        maximumCount: Int = 1_000
    ) async throws -> [NeteaseMessageContact] {
        var contacts: [NeteaseMessageContact] = []
        var loadedIDs: Set<Int> = []
        var offset = 0
        var hasMore = true

        while hasMore, contacts.count < maximumCount {
            let response = try await messageContactsPage(
                userID: userID,
                offset: offset,
                limit: min(pageSize, maximumCount - contacts.count)
            )
            for contact in response.follow
            where loadedIDs.insert(contact.id).inserted {
                contacts.append(contact)
            }
            offset += response.follow.count
            hasMore = response.more == true && !response.follow.isEmpty
        }

        return contacts
    }

    func sendPrivateMessage(
        _ resource: NeteaseShareResource,
        to userIDs: [Int],
        message: String = ""
    ) async throws {
        let recipients = Array(Set(userIDs)).sorted()
        guard !recipients.isEmpty else {
            throw NeteaseSocialError.noRecipient
        }

        let response: APIStatusResponse = try await client.eapi(
            "/api/msg/private/send",
            data: [
                "id": resource.resourceID,
                "msg": message,
                "type": resource.resourceType,
                "userIds": "[\(recipients.map(String.init).joined(separator: ","))]",
            ],
            authenticated: true
        )
        try validate(responseCode: response.code, message: response.message)
    }

    func shareToTimeline(
        _ resource: NeteaseShareResource,
        message: String = ""
    ) async throws {
        guard resource.supportsTimelineSharing else {
            throw NeteaseSocialError.unsupportedTimelineResource
        }

        let response: APIStatusResponse = try await client.eapi(
            "/api/share/friends/resource",
            data: [
                "type": resource.resourceType,
                "msg": message,
                "id": resource.resourceID,
            ],
            authenticated: true
        )
        try validate(responseCode: response.code, message: response.message)
    }

    private func messageContactsPage(
        userID: Int,
        offset: Int,
        limit: Int
    ) async throws -> NeteaseFollowsResponse {
        let path = "/api/user/getfollows/\(userID)"
        let data: [String: Any] = [
            "offset": offset,
            "limit": limit,
            "order": true,
        ]
        let response: NeteaseFollowsResponse
        do {
            // Mirrors @neteaseapireborn/api/module/user_follows.js.
            response = try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            // Preserve the route and parameters when CFNetwork receives an
            // empty weapi response, matching other direct API fallbacks.
            response = try await client.eapi(
                path,
                data: data,
                authenticated: true
            )
        }
        try validate(responseCode: response.code, message: response.message)
        return response
    }

    private func socialRequest<Response: Decodable>(
        _ path: String,
        data: [String: Any]
    ) async throws -> Response {
        do {
            return try await client.weapi(path, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch APIError.emptyResponse {
            return try await client.eapi(
                path,
                data: data,
                authenticated: true
            )
        }
    }
}
