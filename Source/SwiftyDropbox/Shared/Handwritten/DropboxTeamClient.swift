///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation
import Alamofire

/// The client for the Business API. Call routes using the namespaces inside this object (inherited from parent).

open class DropboxTeamClient: DropboxTeamBase {
    private var transportClient: DropboxTransportClient
    private var accessTokenProvider: AccessTokenProvider

    /// Initialize a client with a static accessToken string.
    /// Use this method if your access token is long-lived.
    public convenience init(accessToken: String) {
        let transportClient = DropboxTransportClient(accessToken: accessToken)
        self.init(transportClient: transportClient)
    }

    /// Initialize a client with an `AccessTokenProvider`.
    /// Use this method if your access token is short-lived.
    /// See `ShortLivedAccessTokenProvider` for a default implementation.
    public convenience init(accessTokenProvider: AccessTokenProvider) {
        let transportClient = DropboxTransportClient(accessTokenProvider: accessTokenProvider)
        self.init(transportClient: transportClient)
    }

    public init(transportClient: DropboxTransportClient) {
        self.transportClient = transportClient
        self.accessTokenProvider = transportClient.accessTokenProvider
        super.init(client: transportClient)
    }

    public func asMember(_ memberId: String) -> DropboxClient {
        return DropboxClient(accessTokenProvider: accessTokenProvider, selectUser: memberId)
    }
}
