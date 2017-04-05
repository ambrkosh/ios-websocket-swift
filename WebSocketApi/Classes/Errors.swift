//
//  Errors.swift
//  Pods
//
//  Created by Ye David on 2/27/17.
//
//

import Foundation

public enum ConnectorError : Error {
    case InvalidStateError(String)
    case InvalidUrlError(String)
    case InvalidTimerError(String)
}
