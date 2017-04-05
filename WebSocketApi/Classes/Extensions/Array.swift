//
//  Array.swift
//  Pods
//
//  Created by Ye David on 2/20/17.
//
//

import Foundation

extension Array {

    func filterJsonMessage() -> [String] {
        return self.map({ (e) -> String in
            if let str = e as? String {
                return str
            } else {
                return ""
            }
        }).filter({ s -> Bool in
            return !s.isEmpty
        })
    }
}
