///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation
import Alamofire

/// The client for the User API. Call routes using the namespaces inside this object (inherited from parent).

open class DropboxClient: DropboxBase {
    private var transportClient: DropboxTransportClient
    private var accessTokenProvider: AccessTokenProvider
    private var selectUser: String?

    /// Initialize a client with a static accessToken string.
    /// Use this method if your access token is long-lived.
    public convenience init(accessToken: String, selectUser: String? = nil, pathRoot: Common.PathRoot? = nil) {
        let transportClient = DropboxTransportClient(accessToken: accessToken, selectUser: selectUser, pathRoot: pathRoot)
        self.init(transportClient: transportClient)
    }

    /// Initialize a client with an `AccessTokenProvider`.
    /// Use this method if your access token is short-lived.
    /// See `ShortLivedAccessTokenProvider` for a default implementation.
    public convenience init(
        accessTokenProvider: AccessTokenProvider, selectUser: String? = nil, pathRoot: Common.PathRoot? = nil
    ) {
        let transportClient = DropboxTransportClient(
            accessTokenProvider: accessTokenProvider, selectUser: selectUser, pathRoot: pathRoot
        )
        self.init(transportClient: transportClient)
    }

    public init(transportClient: DropboxTransportClient) {
        self.transportClient = transportClient
        self.selectUser = transportClient.selectUser
        self.accessTokenProvider = transportClient.accessTokenProvider
        super.init(client: transportClient)
    }

    open func withPathRoot(_ pathRoot: Common.PathRoot) -> DropboxClient {
        return DropboxClient(accessTokenProvider: accessTokenProvider, selectUser: selectUser, pathRoot: pathRoot)
    }
}
