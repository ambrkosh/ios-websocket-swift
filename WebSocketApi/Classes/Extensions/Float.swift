//
//  Float.swift
//  Pods
//
//  Created by Ye Jiahao on 2/16/17.
//
//

import Foundation

extension Float {
    
    func calculateRto() -> Float {
        // In a local environment, when using IE8/9 and the `jsonp-polling`
        // transport the time needed to establish a connection (the time that pass
        // from the opening of the transport to the call of `_dispatchOpen`) is
        // around 200msec (the lower bound used in the article above) and this
        // causes spurious timeouts. For this reason we calculate a value slightly
        // larger than that used in the article.
        if (self > 100) {
            return 4 * self // rto > 400msec
        } else {
            return 300 + self
        }
    }
}
