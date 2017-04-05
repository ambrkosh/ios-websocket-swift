//
//  SockJSClient.swift
//  Pods
//
//  Created by Ye David on 2/15/17.
//
//

import Foundation
import SocketRocket.SRWebSocket

public struct ClientOptions {
    public var interval: Float?
    public var baseUrl: String?
    public var protocolList: [String]?
    public var options: [String:Any]?
    public var useCustomUrl: Bool?
    public var openImmediately: Bool?
}

public struct MainOptions {
    public var devel: Bool?
    public var debug: Bool?
    public var protocolWhitelist: [String]?
    public var info: [String:Any]
    public var rtt: Float?
    public var rto: Float?
    public var mainProtocolList: [String:String]?
    public var options: [String:Any]?
    public var server: String?
    public var protocols: [String]?
    public var nullOrigin: Bool?
}

public protocol SockJSClientDelegate {
    // Fires when the the socket connection has been closed
    // Gives the code and the reason
    func closeEvent(code: ClosureCode, reason: ClosureReason) -> Void
    // Fires when the socket connection has been opened
    func openEvent() -> Void
    // Fires when a message of type json is received
    func messageEvent(messageData: [String:Any]) -> Void
    // Fires when there is an error and gives the error message
    func errorEvent(errorMessage: String) -> Void
    // Fires when there is a heartbeat message sent from the server
    func heartbeatEvent() -> Void
}

open class SockJSClient: ConnectorDelegate {
    private var clientOptions: ClientOptions!
    private var mainOptions: MainOptions!
    private var connector: Connector!
    var delegate: SockJSClientDelegate?
    
    init(options: ClientOptions) {
        clientOptions = options
        mainOptions = self.setOptions(clientOptions: options)

        // Initialise the main protocol list
        // mainProtocolList = protocolList && protocolList.count > 0 ? mainProtocolList : [NSMutableDictionary dictionary];
        
        // Initialise the main option list
        
        /* mainOptions = MainOptions(devel: false, debug: false, protocolWhitelist: [], info:  [:], rtt: 0, rto: 0, mainProtocolList: [:], options: [:], server: nil, protocols: [], nullOrigin: false)
        
        // If the option list passed in is not empty then add it to the main options
        if ((options.options != nil) && (options.options!.count) > 0) {
            mainOptions.options = clientOptions.options
        }
        // Initialise the server instance
        if (mainOptions.server == nil) {
            mainOptions.server = String.generateRandom(length: 1000)
        }

        // Initialise the protocol whitelist
        if (mainOptions.protocolWhitelist == nil) {
            if (options.protocolList != nil && !options.protocolList!.isEmpty) {
                mainOptions.protocolWhitelist = clientOptions.protocolList
            } else {
                mainOptions.protocolWhitelist = []
            }
        } */

        // Set the ready state to connecting
        self.open(clientOptions: clientOptions, main: mainOptions)
    }
    
    func setOptions(clientOptions: ClientOptions) -> MainOptions {
        var options = MainOptions(devel: false, debug: false, protocolWhitelist: [], info:  [:], rtt: 0, rto: 0, mainProtocolList: [:], options: [:], server: nil, protocols: [], nullOrigin: false)
        
        // If the option list passed in is not empty then add it to the main options
        if ((clientOptions.options != nil) && (clientOptions.options!.count) > 0) {
            options.options = clientOptions.options
        }
        // Initialise the server instance
        if (options.server == nil) {
            options.server = String.generateRandom(length: 1000)
        }
        
        // Initialise the protocol whitelist
        if (options.protocolWhitelist == nil) {
            if (clientOptions.protocolList != nil && !clientOptions.protocolList!.isEmpty) {
                options.protocolWhitelist = clientOptions.protocolList
            } else {
                options.protocolWhitelist = []
            }
        }
        return options
    }
    
    func sendMessage(message: String) -> Bool {
        return connector.sendMessage(message: message)
    }
    
    func open(clientOptions: ClientOptions, main: MainOptions) -> Void {
        // Set the main options
        mainOptions = self.setOptions(clientOptions: clientOptions)
        // Get the protocol and other info from the server
        if (connector == nil) {
            connector = Connector()
        }
        connector.getServerInfo(mainOptions: main, clientOptions: clientOptions)
        do {
            // Stop the timer loop first
            connector.stopTimerLoop()
            // Setup and start the timer loop for the pings
            try connector.setupTimerLoop(timerInterval: Double(clientOptions.interval ?? 0))
        } catch let e {
            NSLog("%@", e.localizedDescription)
        }
    }
    
    func close() -> Bool {
        return connector.close(mainOptions: mainOptions, clientOptions: clientOptions)
    }
    
    func isOpen() -> Bool {
        return connector.isOpen()
    }
    
    func reopen() -> Bool {
        if (!self.isOpen()) {
            // Reopen the connection
            self.open(clientOptions: clientOptions, main: mainOptions)
            return true
        } else {
            return false
        }
    }
    
    func applyInfo(infoDictionary: [String:Any], rtt: Float, protocolsWhitelist: [String]) -> Void {
        mainOptions.info = infoDictionary
        mainOptions.rtt = rtt
        mainOptions.rto = rtt.calculateRto()
        mainOptions.nullOrigin = false
        mainOptions.protocols = Protocol.detectProtocols(protocolsWhitelist: protocolsWhitelist, info: infoDictionary) as! [String]
    }
    
    func processInfoData(data: Data?, timeElapsed: TimeInterval) throws -> Void {
        if let d = data {
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: d, options: JSONSerialization.ReadingOptions.allowFragments)
                if let jsonDictionary = jsonObject as? [String:Any] {
                    var rtt = mainOptions.rtt ?? 0
                    
                    // Add all info and protocols to the variables
                    self.applyInfo(infoDictionary: jsonDictionary, rtt: rtt, protocolsWhitelist: mainOptions.protocolWhitelist ?? [])
                    try connector.didClose(code: ClosureCode.Unknown, reason: ClosureReason.Unknown, force: false, mainOptions: mainOptions, clientOptions: clientOptions)
                } else if let jsonArray = jsonObject as? [Any] {
                    // Unknown format - don't know how to handle this
                    NSLog("Array returned from info get")
                } else {
                    connector.closeWebsocket()
                }
            } catch let e {
                NSLog("JSON Parse Error: %@", e.localizedDescription)
                connector.closeWebsocket()
            }
            
        } else {
            connector.closeWebsocket()
        }
    }
    
    // Connector delegate functions
    public func heartBeatEvent() -> Void {
        self.delegate?.heartbeatEvent()
    }
    
    public func openEvent() -> Void {
        self.open(clientOptions: self.clientOptions, main: self.mainOptions)
        self.delegate?.openEvent()
    }
    
    public func closeEvent(code: ClosureCode, reason: ClosureReason) -> Void {
        self.delegate?.closeEvent(code: code, reason: reason)
    }
    
    public func messageEvent(messageData: [String:Any]) -> Void {
        self.delegate?.messageEvent(messageData: messageData)
    }
}
