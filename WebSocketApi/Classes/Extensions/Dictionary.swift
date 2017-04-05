//
//  Dictionary.swift
//  Pods
//
//  Created by Ye David on 4/3/17.
//
//

import Foundation

extension Dictionary where Key: Equatable, Value: Any {
    
    func checkParameter(parameterName: String, parameterType: String, optional: Bool) -> Bool {
        let result = self.contains(where: { key, value in
            return (key as! String) == parameterName
        })
        if (result) {
            let parameter = self.filter({key, value in
                return (key as! String) == parameterName
            }).map({ k, v in
                return v
            }).first!
            
            if (parameterType == WebSocketHandlerConstants.CONST_STRING) {
                return (parameter is String)
            } else if (parameterType == WebSocketHandlerConstants.CONST_FUNCTION) {
                return String(describing: type(of: parameter)).contains("->")
            } else {
                return true
            }
        } else {
            return optional
        }
    }
}
