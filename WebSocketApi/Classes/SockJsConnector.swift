//
//  SockJsConnector.swift
//  Pods
//
//  Created by Ye David on 2/20/17.
//
//

import Foundation
import AFNetworking
import PromiseKit
import SocketRocket.SRWebSocket

public protocol ConnectorDelegate {
    func heartBeatEvent() -> Void
    func openEvent() -> Void
    func closeEvent(code: ClosureCode, reason: ClosureReason) -> Void
    func messageEvent(messageData: [String:Any]) -> Void
}

open class Connector: WebsocketWrapperDelegate {
    var sessionManager: AFURLSessionManager
    var sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default
    var webSocketWrapper: WebsocketWrapper?
    var delegate: ConnectorDelegate?
    var timer: DispatchSourceTimer?
    
    public var readyState: ReadyState
    
    init(state: ReadyState = ReadyState.SOCKJS_CONNECTING) {
        readyState = state
        self.sessionManager = AFURLSessionManager(sessionConfiguration: sessionConfiguration)
    }
    
    func getServerInfo(mainOptions: MainOptions, clientOptions: ClientOptions) -> Void {
        let baseUrl: String = clientOptions.baseUrl ?? ClientConstants.BASE_URL
        let infoUrl: String = String(format: "%@/info", arguments: [baseUrl])
        let url: URL = URL(string: infoUrl)!
        let urlRequest: URLRequest = URLRequest(url: url)
        let sessionTask = self.sessionManager.dataTask(with: urlRequest, completionHandler: { res, obj, err in
            self.processsServerInfoData(data: obj as? Data ?? nil, mainOptions: mainOptions, clientOptions: clientOptions)
        })
    }
    
    func processsServerInfoData(data: Data?, mainOptions: MainOptions, clientOptions: ClientOptions) -> [String:Any] {
        let baseUrl: String = clientOptions.baseUrl ?? ClientConstants.BASE_URL
        let server: String = mainOptions.server ?? ""
        
        do {
            let dataDictionary = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments)
            return (dataDictionary as? [String:Any]) ?? [:]
        } catch let e  {
            NSLog("JSON Parse Error: %@", e.localizedDescription)
            // Close websocket
            self.close(mainOptions: mainOptions, clientOptions: clientOptions)
            // Return empty dictionary
            return [:]
        }
    }
    
    func openWebsocket() -> Bool {
        var result = false
        if let websocket = webSocketWrapper {
            if (websocket.getReadyState() != SRReadyState.OPEN) {
                result = websocket.open()
            } else {
                result = false
            }
        } else {
            result = false
        }
        return result
    }
    
    func closeWebsocket() -> Bool {
        var result = false
        if let websocket = webSocketWrapper {
            if (websocket.getReadyState() == SRReadyState.OPEN) {
                result = websocket.close()
            } else {
                result = false
            }
        } else {
            result = false
        }
        return result
    }
    
    func tryNextProtocol(protocols: [String], mainOptions: MainOptions, clientOptions: ClientOptions) -> Bool {
        var result: Bool = false
        let baseUrl: String = clientOptions.baseUrl ?? ClientConstants.BASE_URL
        let server: String = mainOptions.server ?? ""
        let rto: Float = mainOptions.rto ?? 0

        for s in protocols {
            let protocolEnabled: Bool = mainOptions.info[s] as? Bool ?? false
            if (protocolEnabled) {
                // Generate a random connection id for the websocket
                let connectionId: String = String.generateRandom(length: 8)
                var connectionUrl: String = baseUrl
                let useCustomUrl: Bool = clientOptions.useCustomUrl ?? false
                // Checks if a custom url is to be used for connecting to the websocket server
                if (!useCustomUrl) {
                    // Generates a standard websocket connection url based on the connection id, server generated keys
                    var url: String = baseUrl
                    let baseUrlProtocol: String = baseUrl.substring(to: baseUrl.index(baseUrl.startIndex, offsetBy: 5))
                    if (baseUrlProtocol == "https") {
                        url = String.init(format: "wss%@", baseUrl.substring(from: baseUrl.index(baseUrl.startIndex, offsetBy: 5)))
                    } else {
                        url = String.init(format: "ws%@", baseUrl.substring(from: baseUrl.index(baseUrl.startIndex, offsetBy: 4)))
                    }
                    
                    // Add extra info if it is a websocket protocol
                    if (baseUrlProtocol == ProtocolConstants.webSocket.rawValue) {
                        connectionUrl = String.init(format: "%@/%@/%@/%@", arguments: [url, server, connectionId, ProtocolConstants.webSocket.rawValue])
                    } else {
                        connectionUrl = String.init(format: "%@/%@/%@", arguments: [url, server, connectionId])
                    }
                    
                    NSLog("Opening transport: %@ url: %@ rto: %@", s, connectionUrl, rto)
                }
                
                do {
                    try self.connectToWebSocketServer(url: connectionUrl, rto: rto)
                } catch let e {
                    NSLog("Connection to websocket error: %@", e.localizedDescription)
                }
                
                result = true
                break
            }
        }
        return result
    }
    
    func close(mainOptions: MainOptions, clientOptions: ClientOptions) -> Bool {
        let baseUrl: String = clientOptions.baseUrl ?? ClientConstants.BASE_URL
        let server: String = mainOptions.server ?? ""
        
        if (self.readyState != ReadyState.SOCKJS_CONNECTING &&
            self.readyState != ReadyState.SOCKJS_OPEN) {
            return false
        }
        self.readyState = ReadyState.SOCKJS_CLOSING
        do {
            return try didClose(code: ClosureCode.NormalClosure, reason: ClosureReason.NormalClosure, mainOptions: mainOptions, clientOptions: clientOptions)
        } catch ConnectorError.InvalidStateError(let errorMessage) {
            NSLog("Closure error: %@", errorMessage)
            return false
        } catch let e {
            NSLog("Closure error: %@", e.localizedDescription)
            return false
        }
    }
    
    func isOpen() -> Bool {
        return self.readyState == ReadyState.SOCKJS_OPEN
    }
    
    func didClose(code: ClosureCode, reason: ClosureReason, force: Bool = false, mainOptions: MainOptions, clientOptions: ClientOptions) throws -> Bool {
        if (self.readyState != ReadyState.SOCKJS_CONNECTING &&
            self.readyState != ReadyState.SOCKJS_OPEN &&
            self.readyState != ReadyState.SOCKJS_CLOSING) {
            // Throw error
            NSLog("INVALID_STATE_ERR")
            throw ConnectorError.InvalidStateError("INVALID_STATE_ERR")
        }
        return false
        
        // Open websocket
        
        if (!Protocol.isUserSetCode(code: code.rawValue) &&
            self.readyState == ReadyState.SOCKJS_CONNECTING && !force) {
            if (self.tryNextProtocol(protocols: [], mainOptions: mainOptions, clientOptions: clientOptions)) {
                return true
            }
        }
        
        self.readyState = ReadyState.SOCKJS_CLOSED
        // Stop the heartbeat timer loop
        self.stopTimerLoop()
        // Fire a close event
        self.delegate?.closeEvent(code: code, reason: reason)
    }
    
    func processInfoArray(jsonArray: [Any]) -> [[String:Any]] {
        return jsonArray.filterJsonMessage().map({ s -> [String:Any] in
            do {
                let jsonDictionary: [String:Any] = try JSONSerialization.jsonObject(with: s.data(using: String.Encoding.utf8)!, options: JSONSerialization.ReadingOptions.allowFragments) as! [String:Any]
                self.delegate?.messageEvent(messageData: jsonDictionary)
                return jsonDictionary
            } catch let e {
                NSLog("JSON Parse Error: %@", e.localizedDescription)
                return [:]
            }
        })
    }
    
    func connectToWebSocketServer(url: String, rto: Float) throws -> Void {
        if (url.verifyUrl()) {
            var urlRequest: URLRequest = URLRequest(url: URL(string: url)!)
            // Set the timeout interval
            urlRequest.timeoutInterval = TimeInterval((rto * 5000) / 1000 as Float)
            
            webSocketWrapper = WebsocketWrapper(urlRequest: urlRequest)
            webSocketWrapper?.websocketWrapperDelegate = self
        } else {
            // raise an error
            NSLog("Incorrectly formatted url: %@", url)
            throw ConnectorError.InvalidUrlError(String.init(format: "Incorrectly formatted url: %@", url))
        }
    }
    
    // Timer loop
    func setupTimerLoop(timerInterval: Double) throws -> Void {
        // Create a timer loop on a different thread
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        // timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        
        if let t = timer {
            // Fires it according the the time interval set
            t.scheduleRepeating(deadline: .now(), interval: timerInterval)
            // dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, timerInterval * NSEC_PER_SEC, 1.0 * NSEC_PER_SEC);
            t.setEventHandler(handler: handleTimerEvent)
            t.resume()
            // dispatch_source_set_event_handler(timer, ^{ handleTimerEvent(websocket); });
            // dispatch_resume(timer);
        } else {
            throw ConnectorError.InvalidUrlError("Cannot create timer")
        }
    }
    
    func stopTimerLoop() -> Void {
        timer?.cancel()
        timer = nil
    }
    
    func handleTimerEvent() -> Void {
        // Send a ping
        if let w = webSocketWrapper {
            if (w.getReadyState() == SRReadyState.OPEN) {
                let message: String = "\"{\\\"type\\\" : \\\"ping\\\"}\""
                w.send(message: message)
                NSLog("%@", message)
            }
        }
    }
    
    func sendMessage(message: String) -> Bool {
        if let w = webSocketWrapper {
            if (w.getReadyState() == SRReadyState.OPEN) {
                w.send(message: message)
                NSLog("Message sent: %@", message)
                return true
            } else {
                NSLog("Message not sent due to ready state being not open: %@", message)
                return false
            }
        } else {
            self.delegate?.openEvent()
            return true
        }
    }
    
    // Websocket Wrapper Delegates
    func openEvent() -> Void {
        if (self.readyState == ReadyState.SOCKJS_CONNECTING) {
            self.readyState = ReadyState.SOCKJS_OPEN
            // Fires an open event
            self.delegate?.openEvent()
            NSLog("%@", "Open event")
        } else {
            // Server might have been restarted and lost track of our connection
            self.delegate?.closeEvent(code: ClosureCode.ServerLostSession, reason: ClosureReason.ServerLostSession)
            NSLog("%@", "Close event")
        }
    }
    
    func closeEvent(code: Int, reason: String) -> Void {
        self.delegate?.closeEvent(code: ClosureCode(rawValue: code)!, reason: ClosureReason(rawValue: reason)!)
        NSLog("%@", "Close event")
    }
    
    func processInfoArrayEvent(info: [Any]?) -> Void {
        let messageArray: [[String:Any]] = self.processInfoArray(jsonArray: info ?? [])
        for m in messageArray {
            self.delegate?.messageEvent(messageData: m)
        }
        NSLog("%@", "Info array event")
    }
    
    func processMessageEvent(info: [String:Any]?) -> Void {
        if (self.readyState != ReadyState.SOCKJS_OPEN) {
            return
        }
        // Fires a message event
        self.delegate?.messageEvent(messageData: info ?? [:])
        NSLog("%@", "Message event")
    }
    
    func dispatchHeartBeatEvent() -> Void {
        // Fires a heartheat event
        self.delegate?.heartBeatEvent()
        NSLog("%@", "Heartbeat event")
    }
    
    func errorEvent(description: String) {
        NSLog("Error event: %@", description)
    }
}
