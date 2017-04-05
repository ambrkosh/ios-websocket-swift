//
//  WebsocketWrapper.swift
//  Pods
//
//  Created by Ye David on 2/27/17.
//
//

import Foundation
import SocketRocket.SRWebSocket

protocol WebsocketWrapperDelegate {
    func openEvent() -> Void
    func closeEvent(code: Int, reason: String) -> Void
    func processInfoArrayEvent(info: [Any]?) -> Void
    func processMessageEvent(info: [String:Any]?) -> Void
    func dispatchHeartBeatEvent() -> Void
    func errorEvent(description: String) -> Void
}

open class WebsocketWrapper: NSObject, SRWebSocketDelegate {
    
    var websocketWrapperDelegate: WebsocketWrapperDelegate?
    var websocket: SRWebSocket?
    
    init(urlRequest: URLRequest) {
        websocket = SRWebSocket(urlRequest: urlRequest)
    }
    
    public func getReadyState() -> SRReadyState {
        return websocket?.readyState ?? SRReadyState.CLOSED
    }
    
    public func open() -> Bool {
        if let ws = websocket {
            ws.open()
            return true
        } else {
            return false
        }
    }
    
    public func close() -> Bool {
        if let ws = websocket {
            ws.close()
            return true
        } else {
            return false
        }
    }
    
    public func send(message: String) -> Bool {
        if let ws = websocket {
            ws.send(message)
            return true
        } else {
            return false
        }
    }
    
    public func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        if (message is String) {
            let messageText: String = message as! String
            NSLog("%@", messageText)
            
            var jsonDictionary: [String:Any]?
            var jsonArray: [Any]?
            // Parse the JSON object
            if (!messageText.isEmpty) {
                let frameCode: Character = messageText.characters.first!
                // char frameCode = [[message substringToIndex:1] UTF8String][0];
                
                if (messageText.length > 1) {
                    let subString: String = messageText.substring(from: messageText.index(messageText.startIndex, offsetBy: 1))
                    
                    do {
                        let jsonObject = try JSONSerialization.jsonObject(with: subString.data(using: String.Encoding.utf8)!, options: JSONSerialization.ReadingOptions.allowFragments)
                        if (jsonObject is [String:Any]) {
                            jsonDictionary = jsonObject as! [String:Any]
                        } else if (jsonObject is [Any]) {
                            jsonArray = jsonObject as! [Any]
                        }
                    } catch let e {
                        NSLog("JSON Parse Error: %@", e.localizedDescription)
                    }
                }
                
                // Check the type of frame code and act accordingly
                switch frameCode {
                    case Character("o"):
                        // The connection was opened by the server
                        self.websocketWrapperDelegate?.openEvent()
                    case Character("a"):
                        // A message was sent from the server in an array format
                        if (jsonArray != nil) {
                            self.websocketWrapperDelegate?.processInfoArrayEvent(info: jsonArray)
                        }
                    case Character("m"):
                        // A message was sent from the server
                        if (jsonDictionary != nil) {
                            self.websocketWrapperDelegate?.processMessageEvent(info: jsonDictionary)
                        }
                    case Character("c"):
                        // The connection was closed by the server
                        if (jsonArray != nil) {
                            do {
                                try self.websocketWrapperDelegate?.closeEvent(code: jsonArray![0] as! Int, reason: jsonArray![1] as! String)
                            } catch let e {
                                NSLog("JsonArray Access Error: %@", e.localizedDescription)
                            }
                        } else {
                            self.websocketWrapperDelegate?.closeEvent(code: ClosureCode.Unknown.rawValue, reason: ClosureReason.NormalClosure.rawValue)
                        }
                    case Character("h"):
                        self.websocketWrapperDelegate?.dispatchHeartBeatEvent()
                    default:
                        // Assume it is not framed with a char and is a straight json string
                        if (jsonArray != nil) {
                            self.websocketWrapperDelegate?.processInfoArrayEvent(info: jsonArray)
                        } else if ((jsonDictionary) != nil) {
                            self.websocketWrapperDelegate?.processMessageEvent(info: jsonDictionary)
                        }
                        NSLog("%@", messageText)
                    }
            }
        }
    }
    
    
    public func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        NSLog("Socket Opened")
    }
    
    public func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        self.websocketWrapperDelegate?.errorEvent(description: error.localizedDescription)
    }
    
    public func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        // TODO
    }
    
    public func webSocket(_ webSocket: SRWebSocket!, didReceivePong pongPayload: Data!) {
        // TODO
    }
}
