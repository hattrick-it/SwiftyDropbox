///
/// Copyright (c) 2020 Dropbox, Inc. All rights reserved.
///

import Foundation

/// Protocol for objects that provide an access token and offer a way to refresh (short-lived) token.
public protocol AccessTokenProvider: Any {
    var accessToken: String { get }
    func refreshAccessTokenIfNecessary(completion: @escaping DropboxOAuthCompletion)
}

/// Wrapper for legacy long-lived access token.
public struct LongLivedAccessTokenProvider: AccessTokenProvider {
    public let accessToken: String
    public func refreshAccessTokenIfNecessary(completion: @escaping DropboxOAuthCompletion) {
        // Complete with empty result, because it doesn't need a refresh.
        completion(nil)
    }
}

/// Wrapper for short-lived token.
public class ShortLivedAccessTokenProvider: AccessTokenProvider {
    public var accessToken: String {
        if Thread.isMainThread {
            return token.accessToken
        } else {
            return mainQueue.sync { return token.accessToken }
        }
    }

    private let mainQueue = DispatchQueue.main
    private let tokenRefresher: AccessTokenRefreshing
    private var token: DropboxAccessToken
    private var completionBlocks = [(DropboxOAuthResult?) -> Void]()

    /// Refresh if it's about to expire (5 minutes from expiration) or already expired.
    private var shouldRefresh: Bool {
        guard let expirationTimestamp = token.tokenExpirationTimestamp else {
            return false
        }
        let fiveMinutesBeforeExpire = Date(timeIntervalSince1970: expirationTimestamp - 300)
        return Date() > fiveMinutesBeforeExpire
    }

    private var refreshInProgress: Bool {
        !completionBlocks.isEmpty
    }

    /// - Parameters:
    ///     - token: The `DropboxAccessToken` object for a short-lived token.
    ///     - tokenRefresher: Helper object that refreshes a token over network.
    init(token: DropboxAccessToken, tokenRefresher: AccessTokenRefreshing) {
        self.token = token
        self.tokenRefresher = tokenRefresher
    }

    public func refreshAccessTokenIfNecessary(completion: @escaping DropboxOAuthCompletion) {
        mainQueue.async {
            guard self.shouldRefresh else {
                completion(nil)
                return
            }
            // Ensure subsequent calls don't initiate more refresh requests, if one is in progress.
            if !self.refreshInProgress {
                self.tokenRefresher.refreshAccessToken(
                    self.token, scopes: nil, queue: self.mainQueue
                ) { [weak self] result in
                    self?.handleRefreshResult(result)
                }
            }
            self.completionBlocks.append(completion)
        }
    }

    private func handleRefreshResult(_ result: DropboxOAuthResult?) {
        if case let .success(token) = result {
            self.token = token
        }
        self.completionBlocks.forEach { block in
            block(result)
        }
        self.completionBlocks.removeAll()
    }
}
