//
//  State.swift
//  AVWriterExample
//
//  Created by Ken Torimaru on 12/27/19.
//  Copyright © 2019 Torimaru & Williamson, LLC. All rights reserved.
//

import Foundation
import Combine

/// Manages the data and state of the app
class State: ObservableObject {
    var willChange: PassthroughSubject<Void, Never> = PassthroughSubject<Void, Never>()
    typealias PublisherType = PassthroughSubject<Void, Never>
    
}
