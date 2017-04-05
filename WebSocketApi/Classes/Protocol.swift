//
//  Protocol.swift
//  Pods
//
//  Created by Ye David on 2/16/17.
//
//

import Foundation

// Enum to show the connection status
public enum ReadyState: Int {
    case SOCKJS_CONNECTING = 0 // Connecting to the server
    case SOCKJS_OPEN = 1 // Connected
    case SOCKJS_CLOSING = 2 // Attempting to close the connection
    case SOCKJS_CLOSED = 3 // Connection to the server has closed
    case SOCKJS_ERROR = 4  // Error has occurred in the connection
}

public enum ClosureCode: Int {
    case NormalClosure = 1000
    case ServerLostSession = 1006
    case Unknown = 9999
}

public enum ClosureReason: String {
    case NormalClosure = "Normal Closure"
    case ServerLostSession = "Server lost session"
    case Unknown = "Unknown"
}

public struct ClientConstants {
    public static let CONST_INFO = "info"
    public static let CONST_DEVEL = "devel"
    public static let CONST_DEBUG = "debug"
    public static let CONST_PROTOCOLS_WHITELIST = "protocols_whitelist"
    public static let CONST_RTT = "rtt"
    public static let CONST_RTO = "rto"
    public static let CONST_SERVER = "server"
    public static let BASE_URL = "http://localhost:8081/eventbus"
}

public enum ProtocolConstants: String {
    case nullOrigin = "null_origin"
    case webSocket = "websocket"
    case xhrStreaming = "xhr-streaming"
    case xdrStreaming = "xdr-streaming"
    case iFrameEventSource = "iframe-eventsource"
    case iFrameHtmlFile = "iframe-htmlfile"
    case xdrPolling = "xdr-polling"
    case xhrPolling = "xhr-polling"
    case iFrameXhrPolling = "iframe-xhr-polling"
    case jsonpPolling = "jsonp-polling"
    case cookieNeeded = "cookie_needed"
}

open class Protocol {
    
    static func isUserSetCode(code: Int) -> Bool {
        return code == 1000 || (code >= 3000 && code <= 4999)
    }
    
    static func detectProtocols(protocolsWhitelist: [String], info: [String:Any]) -> [Any] {
        /*let allProtocols: [String] = [
            ProtocolConstants.webSocket.rawValue,
            ProtocolConstants.xdrStreaming.rawValue,
            ProtocolConstants.xhrStreaming.rawValue,
            ProtocolConstants.iFrameEventSource.rawValue,
            ProtocolConstants.iFrameHtmlFile.rawValue,
            ProtocolConstants.xdrPolling.rawValue,
            ProtocolConstants.xhrPolling.rawValue,
            ProtocolConstants.iFrameXhrPolling.rawValue,
            ProtocolConstants.jsonpPolling.rawValue]
        
        NSMutableArray *protocols = [NSMutableArray array];
        NSMutableArray *result = [NSMutableArray array];
        if (!protocolsWhitelist || protocolsWhitelist.count == 0) {
            int length = sizeof(allProtocols)/sizeof(NSString*);
            for (int i; i < length; ++i) {
                [protocols addObject:allProtocols[i]];
            }
        } else {
            [protocols addObjectsFromArray:protocolsWhitelist];
        }*/
        
        var result: [Any] = []
        
        // 1. websocket
        if ((info[ProtocolConstants.webSocket.rawValue] != nil) && (info[ProtocolConstants.webSocket.rawValue] as! Bool)) {
            result.append(info[ProtocolConstants.webSocket.rawValue])
        }
        
        // 2. Streaming
        if ((info[ProtocolConstants.xhrStreaming.rawValue] != nil)
            && (info[ProtocolConstants.nullOrigin.rawValue] != nil
            && !(info[ProtocolConstants.nullOrigin.rawValue] as! Bool))) {
            result.append(info[ProtocolConstants.nullOrigin.rawValue])
        } else {
            if (info[ProtocolConstants.xdrStreaming.rawValue] != nil
                && (info[ProtocolConstants.cookieNeeded.rawValue] != nil && !(info[ProtocolConstants.cookieNeeded.rawValue] as! Bool))
                && (info[ProtocolConstants.nullOrigin.rawValue] != nil && !(info[ProtocolConstants.nullOrigin.rawValue] as! Bool))) {
                result.append(info[ProtocolConstants.xdrStreaming.rawValue])
            } else {
                if (info[ProtocolConstants.iFrameEventSource.rawValue] != nil) {
                    result.append(info[ProtocolConstants.iFrameEventSource.rawValue])
                }
                if (info[ProtocolConstants.iFrameHtmlFile.rawValue] != nil) {
                    result.append(info[ProtocolConstants.iFrameHtmlFile.rawValue])
                }
            }
        }
        
        // 3. Polling
        if ((info[ProtocolConstants.xhrPolling.rawValue] != nil)
            && (info[ProtocolConstants.nullOrigin.rawValue] != nil
            && !(info[ProtocolConstants.nullOrigin.rawValue] as! Bool))) {
            result.append(info[ProtocolConstants.xhrPolling.rawValue])
        } else {
            if (info[ProtocolConstants.xdrPolling.rawValue] != nil
                && (info[ProtocolConstants.cookieNeeded.rawValue] != nil && !(info[ProtocolConstants.cookieNeeded.rawValue] as! Bool))
                && (info[ProtocolConstants.nullOrigin.rawValue] != nil && !(info[ProtocolConstants.nullOrigin.rawValue] as! Bool))) {
                result.append(info[ProtocolConstants.xdrPolling.rawValue])
            } else {
                if (info[ProtocolConstants.iFrameXhrPolling.rawValue] != nil) {
                    result.append(info[ProtocolConstants.iFrameXhrPolling.rawValue])
                }
                if (info[ProtocolConstants.jsonpPolling.rawValue] != nil) {
                    result.append(info[ProtocolConstants.jsonpPolling.rawValue])
                }
            }
        }
        
        return result
    }
}
