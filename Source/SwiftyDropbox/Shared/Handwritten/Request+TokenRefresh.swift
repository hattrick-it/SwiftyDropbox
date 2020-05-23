///
/// Copyright (c) 2020 Dropbox, Inc. All rights reserved.
///

import Foundation
import Alamofire

/// Completion handler for ApiRequest.
enum RequestCompletionHandler {
    case dataCompletionHandler((DefaultDataResponse) -> Void)
    case downloadFileCompletionHandler((DefaultDownloadResponse) -> Void)
}

/// Protocol defining an API request object.
protocol ApiRequest {
    @discardableResult func progress(handler: @escaping Alamofire.Request.ProgressHandler) -> Self

    @discardableResult
    func response(queue: DispatchQueue?, completionHandler: RequestCompletionHandler) -> Self

    func cancel()
}

/// A class that wraps a network request that calls DBX API.
/// This class will first attempt to refresh the access token and conditionally proceed to the actual API call.
class RequestWithTokenRefresh: ApiRequest {
    typealias RequestCreationBlock = () -> Alamofire.Request
    fileprivate var request: Alamofire.Request?
    private var cancelled = false
    private var responseQueue: DispatchQueue?
    private var completionHandler: RequestCompletionHandler?
    private var progressHandler: Alamofire.Request.ProgressHandler?
    private let serialQueue = DispatchQueue(label: "RequestWithTokenRefresh.serial.queue", qos: .userInitiated)

    init(requestCreation: @escaping RequestCreationBlock, tokenProvider: AccessTokenProvider) {
        tokenProvider.refreshAccessTokenIfNecessary { result in
            self.serialQueue.async {
                self.handleTokenRefreshResult(result, requestCreation: requestCreation)
            }
        }
    }

    /// - Parameters:
    ///     - queue: The queue where the completionHandler should be called from.
    ///     - completionHandler: The completion handler.
    func response(queue: DispatchQueue?, completionHandler: RequestCompletionHandler) -> Self {
        serialQueue.async {
            self.responseQueue = queue
            self.completionHandler = completionHandler
            self.setCompletionHandlerIfNecessary()
        }
        return self
    }

    /// - Parameters:
    ///     - handler: A ProgressHandler.
    /// Progress handlerr will always be called back on Main Queue.
    func progress(handler: @escaping Alamofire.Request.ProgressHandler) -> Self {
        serialQueue.async {
            self.progressHandler = handler
            self.setProgressHandlerIfNecessary()
        }
        return self
    }

    func cancel() {
        serialQueue.async {
            self.cancelled = true
            self.request?.cancel()
        }
    }

    private func handleTokenRefreshResult(_ result: DropboxOAuthResult?, requestCreation: RequestCreationBlock) {
        if case let .error(oauthError, _) = result, !oauthError.isInvalidGrantError {
            // Refresh failed, due to an error that's not invalid grant, e.g. A refresh request timed out.
            // Don't complete request with error immediately, so developers could retry to get access token refreshed.
            // Otherwise, the API request may proceed with an expired access token which would lead to
            // a false positive auth error.
            self.completeWithError(oauthError)
        } else {
            // Refresh succeeded or a refresh is not required, i.e. access token is valid, continue request normally.
            // Or
            // Refresh failed due to invalid grant, e.g. refresh token revoked by user.
            // Continue, and the API call would failed with an auth error that developers can handle properly.
            // e.g. Sign out the user upon auth error.
            self.setRequest(requestCreation())
        }
    }

    private func setRequest(_ request: Alamofire.Request) {
        self.request = request
        setProgressHandlerIfNecessary()
        setCompletionHandlerIfNecessary()
        if cancelled {
            request.cancel()
        } else {
            request.resume()
        }
    }

    private func setCompletionHandlerIfNecessary() {
        guard let completionHandler = completionHandler else { return }
        switch completionHandler {
        case .dataCompletionHandler(let handler):
            if let dataRequest = request as? Alamofire.DataRequest {
                dataRequest.validate().response(queue: responseQueue, completionHandler: handler)
            }
        case .downloadFileCompletionHandler(let handler):
            if let downloadRequest = request as? Alamofire.DownloadRequest {
                downloadRequest.validate().response(queue: responseQueue, completionHandler: handler)
            }
        }
    }

    private func setProgressHandlerIfNecessary() {
        guard let progressHandler = progressHandler else { return }
        if let uploadRequest = request as? Alamofire.UploadRequest {
            uploadRequest.uploadProgress(closure: progressHandler)
        } else if let downloadRequest = request as? Alamofire.DownloadRequest {
            downloadRequest.downloadProgress(closure: progressHandler)
        } else if let dataRequest = request as? Alamofire.DataRequest {
            dataRequest.downloadProgress(closure: progressHandler)
        }
    }

    private func completeWithError(_ error: OAuth2Error) {
        guard let completionHandler = completionHandler else { return }
        (responseQueue ?? DispatchQueue.main).async {
            switch completionHandler  {
            case .dataCompletionHandler(let handler):
                let dataResponse = DefaultDataResponse(request: nil, response: nil, data: nil, error: error)
                handler(dataResponse)
            case .downloadFileCompletionHandler(let handler):
                let downloadResponse = DefaultDownloadResponse(
                    request: nil, response: nil, temporaryURL: nil,
                    destinationURL: nil, resumeData: nil, error: error
                )
                handler(downloadResponse)
            }
        }
    }
}
