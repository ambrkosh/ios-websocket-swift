//
//  String.swift
//  Pods
//
//  Created by Ye David on 2/15/17.
//
//

import Foundation

extension String {
    var length: Int {
        return self.characters.count
    }
    
    var toJSON: String {
        let replacementOptions: [(String,String)] = [("\"", "\\\""), ("/", "\\/"), ("\n", "\\n"), ("\\b", "\\\\b"), ("\\f","\\\\f"), ("\r","\\r"), ("\t","\\t")]
        var interimResult: String = replacementOptions.reduce(self, { res, s -> String in
            replacingOccurrences(of: s.0, with: s.1)
        })
        // Add quotes to the begining and end if it doesn't exist
        if (interimResult.substring(to: interimResult.startIndex) != "\"") {
            interimResult = String(format: "%@%@%@", "\"", interimResult, "\"")
        }
        return interimResult
    }
    
    static func generateRandom(length: Int)-> String {
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let len = UInt32(letters.length)
        
        var randomString = ""
        
        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        
        return randomString
    }
    
    static func generateRandomNumber(maxValue: Int) -> String {
        let maxValueLength: Int = String(maxValue).length
        let randomNumber = arc4random_uniform(UInt32(maxValue))
        return String(Int(randomNumber))
    }
    
    func verifyUrl() -> Bool {
        let urlRegEx: String = "(http|https|ws|wss)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|:/]((\\w)*|([0-9]*)|([-|_])*))+"
        return NSPredicate(format: "SELF MATCHES %@", urlRegEx).evaluate(with: self)
    }
}
