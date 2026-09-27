//
//  WebAuthenticationSession.swift
//  flutter_inappwebview
//
//  Created by Lorenzo Pichilli on 08/05/22.
//

import Foundation
import AuthenticationServices
import SafariServices
import FlutterMacOS

@available(macOS 10.15, *)
private final class WebAuthenticationPresentationContextProvider: NSObject,
    ASWebAuthenticationPresentationContextProviding {
    /// Purpose: Supply the authentication session's presentation window.
    /// Inputs: The requesting authentication session.
    /// Returns: The key window or an empty presentation anchor.
    /// Side effects: None.
    /// Notes: The enclosing provider gates the entire conformance to macOS 10.15.
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

public class WebAuthenticationSession: NSObject, Disposable {
    static let METHOD_CHANNEL_NAME_PREFIX = "com.pichillilorenzo/flutter_webauthenticationsession_"
    var id: String
    var plugin: InAppWebViewFlutterPlugin?
    var url: URL
    var callbackURLScheme: String?
    var settings: WebAuthenticationSessionSettings
    var session: Any?
    private var presentationContextProvider: NSObject?
    var channelDelegate: WebAuthenticationSessionChannelDelegate?
    private var _canStart = true
    
    /// Purpose: Create an authentication session and its Flutter channel.
    /// Inputs: Plugin, session identifier, URL, callback scheme and settings.
    /// Returns: A configured session wrapper.
    /// Side effects: Creates the native session and registers the channel delegate.
    /// Notes: Retains the presentation provider because the native session holds it weakly.
    public init(plugin: InAppWebViewFlutterPlugin, id: String, url: URL, callbackURLScheme: String?, settings: WebAuthenticationSessionSettings) {
        self.id = id
        self.plugin = plugin
        self.url = url
        self.settings = settings
        super.init()
        self.callbackURLScheme = callbackURLScheme
        if #available(macOS 10.15, *) {
            let presentationContextProvider = WebAuthenticationPresentationContextProvider()
            let session = ASWebAuthenticationSession(url: self.url, callbackURLScheme: self.callbackURLScheme, completionHandler: self.completionHandler)
            session.presentationContextProvider = presentationContextProvider
            self.presentationContextProvider = presentationContextProvider
            self.session = session
        }
        let channel = FlutterMethodChannel(name: WebAuthenticationSession.METHOD_CHANNEL_NAME_PREFIX + id,
                                           binaryMessenger: plugin.registrar.messenger)
        self.channelDelegate = WebAuthenticationSessionChannelDelegate(webAuthenticationSession: self, channel: channel)
    }
    
    public func prepare() {
        if #available(macOS 10.15, *), let session = session as? ASWebAuthenticationSession {
            session.prefersEphemeralWebBrowserSession = settings.prefersEphemeralWebBrowserSession
        }
    }
    
    public func completionHandler(url: URL?, error: Error?) -> Void {
        channelDelegate?.onComplete(url: url, errorCode: error?._code)
    }
    
    public func canStart() -> Bool {
        guard let session = session else {
            return false
        }
        if #available(macOS 10.15.4, *), let session = session as? ASWebAuthenticationSession {
            return session.canStart
        }
        return _canStart
    }
    
    public func start() -> Bool {
        guard let session = session else {
            return false
        }
        var started = false
        if #available(macOS 10.15, *), let session = session as? ASWebAuthenticationSession {
            started = session.start()
        }
        if started {
            _canStart = false
        }
        return started
    }
    
    public func cancel() {
        guard let session = session else {
            return
        }
        if #available(macOS 10.15, *), let session = session as? ASWebAuthenticationSession {
            session.cancel()
        }
    }
    
    /// Purpose: Stop authentication and release session resources.
    /// Inputs: None.
    /// Returns: None.
    /// Side effects: Cancels the session, releases its provider and unregisters its channel.
    /// Notes: Safe when resources have already been released.
    public func dispose() {
        cancel()
        channelDelegate?.dispose()
        channelDelegate = nil
        session = nil
        presentationContextProvider = nil
        plugin?.webAuthenticationSessionManager?.sessions[id] = nil
        plugin = nil
    }
    
    deinit {
        debugPrint("WebAuthenticationSession - dealloc")
        dispose()
    }
}
