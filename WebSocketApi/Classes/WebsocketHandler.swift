//
//  WebsocketHandler.swift
//  Pods
//
//  Created by Ye David on 3/31/17.
//
//

import Foundation

public struct WebSocketHandlerConstants {
    public static let CONST_FUNCTION = "function"
    public static let CONST_STRING = "string"
    public static let CONST_TYPE = "type"
    public static let CONST_ADDRESS = "address"
    public static let CONST_BODY = "body"
    public static let CONST_REPLY_HANDLER = "replyHandler"
    public static let CONST_REPLY_ADDRESS = "replyAddress"
    public static let CONST_REPLY_SEND = "send"
    public static let CONST_REGISTER = "register"
    public static let CONST_UNREGISTER = "unregister"
    public static let CONST_SEND = "send"
    public static let CONST_PUBLISH = "publish"
}

public protocol WebSocketHandlerDelegate {
    func heartBeatEvent() -> Void
    func openEvent() -> Void
    func closeEvent(code: ClosureCode, reason: ClosureReason) -> Void
    func messageEvent(messageData: [String:Any]?) -> Void
    func errorEvent(errorMessage: String?) -> Void
}

open class WebSocketHandler {
    var sockJSClient: SockJSClient?
    var _baseUrl: String?
    var _interval: Float?
    var handlers: [String:Any]
    var replayHandlers: [String:Any]
    var delegate: WebSocketHandlerDelegate?
    
    
    init(interval: Float, url: String) {
        _interval = interval
        _baseUrl = url
        let clientOptions: ClientOptions = ClientOptions(interval: interval, baseUrl: url, protocolList: [], options: [:], useCustomUrl: false, openImmediately: true)
        sockJSClient = SockJSClient(options: clientOptions)
        
        handlers = [:]
        replayHandlers = [:]
    }
    
    func send(message: [String:Any]) -> Bool {
        let jsonMessage: String = self.prepareMessage(messageDictionary: message)
        if (jsonMessage.isEmpty) {
            self.delegate?.errorEvent(errorMessage: "Cannot send empty string!")
            return false
        } else {
            return self.sendMessage(message: jsonMessage)
        }
    }
    
    func sendMessage(message: String) -> Bool {
        return sockJSClient?.sendMessage(message: message) ?? false
    }
    
    func prepareMessage(messageDictionary: [String:Any]) -> String {
        if (!messageDictionary.checkParameter(parameterName: WebSocketHandlerConstants.CONST_TYPE, parameterType: WebSocketHandlerConstants.CONST_STRING, optional: false)) {
            self.delegate?.errorEvent(errorMessage: "Parameter type must be specified")
            return ""
        }
        if (!messageDictionary.checkParameter(parameterName: WebSocketHandlerConstants.CONST_ADDRESS, parameterType: WebSocketHandlerConstants.CONST_STRING, optional: false)) {
            self.delegate?.errorEvent(errorMessage: "Parameter address must be specified")
            return ""
        }
        if (!messageDictionary.checkParameter(parameterName: WebSocketHandlerConstants.CONST_REPLY_HANDLER, parameterType: WebSocketHandlerConstants.CONST_FUNCTION, optional: true)) {
            self.delegate?.errorEvent(errorMessage: "Parameter replyHandler must be specified")
            return ""
        }
        
        let type: String = messageDictionary[WebSocketHandlerConstants.CONST_TYPE] as! String
        let address: String = messageDictionary[WebSocketHandlerConstants.CONST_ADDRESS] as! String
        let body: String = messageDictionary[WebSocketHandlerConstants.CONST_BODY] as! String
        let replyHandler = messageDictionary[WebSocketHandlerConstants.CONST_REPLY_HANDLER]
        
        var envelope: [String:Any] = [WebSocketHandlerConstants.CONST_TYPE:type,
                        WebSocketHandlerConstants.CONST_ADDRESS:address,
                        WebSocketHandlerConstants.CONST_BODY:body]
        
        if (replyHandler != nil) {
            // If the reply handler exists then store it
            let replyAddress: String = UUID().uuidString
            envelope[WebSocketHandlerConstants.CONST_REPLY_ADDRESS] = replyAddress
            envelope[replyAddress] = replyHandler
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: envelope, options: JSONSerialization.WritingOptions.prettyPrinted)
            return String.init(data: jsonData, encoding: String.Encoding.utf8)?.toJSON ?? ""
        } catch let e {
            self.delegate?.errorEvent(errorMessage: String.init(format: "Error converting to JSON string: %@", e.localizedDescription))
            return ""
        }
    }
    
    func isOpen() -> Bool {
        return sockJSClient?.isOpen() ?? false
    }
    
    func registerHandler(handlerName: String, handler: @escaping (Any, Any) -> Void) -> Bool {
        if (handlers[handlerName] == nil) {
            let message: [String:Any] = [WebSocketHandlerConstants.CONST_TYPE:WebSocketHandlerConstants.CONST_REGISTER,
                                         WebSocketHandlerConstants.CONST_ADDRESS:handlerName]
            self.send(message: message)
            handlers[handlerName] = handler
            return true
        } else {
            return false
        }
    }
    
    func deregisterHandler(handlerName: String, handler: @escaping (Any, Any) -> Void) -> Bool {
        if (handlers[handlerName] != nil) {
            let message: [String:Any] = [WebSocketHandlerConstants.CONST_TYPE:WebSocketHandlerConstants.CONST_UNREGISTER,
                                         WebSocketHandlerConstants.CONST_ADDRESS:handlerName]
            self.send(message: message)
            return handlers.removeValue(forKey: handlerName) != nil
        } else {
            return false
        }
    }
    
    func reconnectIfClosed() -> Bool {
        if (!self.isOpen()) {
            return sockJSClient?.reopen() ?? false
        } else {
            return false
        }
    
    }
    
    func closeConnection() -> Bool {
        // Close the client
        return sockJSClient?.close() ?? false
    }
    
    // SockJSClient delegates
    
    // Fires when the the socket connection has been closed
    // Gives the code and the reason
    func closeEvent(code: ClosureCode, reason: ClosureReason) -> Void {
        self.delegate?.closeEvent(code: code, reason: reason)
    }
    // Fires when the socket connection has been opened
    func openEvent() -> Void {
        self.delegate?.openEvent()
    }
    // Fires when a message of type json is received
    func messageEvent(messageData: [String:Any]) -> Void {
        
        let replyAddress: String = messageData[WebSocketHandlerConstants.CONST_REPLY_ADDRESS] as? String ?? ""
        let address: String = messageData[WebSocketHandlerConstants.CONST_ADDRESS] as! String
        let body: [String:Any] = messageData[WebSocketHandlerConstants.CONST_BODY] as! [String : Any]
        
        let handler: ((Any, Any) -> Void)? = handlers[address] as! ((Any, Any) -> Void)?
        var replyHandler: ((Any, Any) -> Void)? = nil
        
        if (!replyAddress.isEmpty) {
            replyHandler = { r, rh in
                let messageDict: [String:Any] = [WebSocketHandlerConstants.CONST_TYPE:WebSocketHandlerConstants.CONST_REPLY_SEND,
                                                 WebSocketHandlerConstants.CONST_ADDRESS:replyAddress,
                                                 WebSocketHandlerConstants.CONST_BODY:r,
                                                 WebSocketHandlerConstants.CONST_REPLY_HANDLER:replyHandler]
                self.send(message: messageDict)
            }
        }
        
        if let h = handler {
            h(body, replyHandler)
        } else {
            // Might be a reply message
            let tempHandler: ((Any, Any) -> Void)? = replayHandlers[address] as! ((Any, Any) -> Void)?
            if let t = tempHandler {
                replayHandlers.removeValue(forKey: address)
                t(body, replyHandler)
            }
        }
    }
    // Fires when there is an error and gives the error message
    func errorEvent(errorMessage: String) -> Void {
        self.delegate?.errorEvent(errorMessage: errorMessage)
    }
    // Fires when there is a heartbeat message sent from the server
    func heartbeatEvent() -> Void {
        self.delegate?.heartBeatEvent()
    }
}
