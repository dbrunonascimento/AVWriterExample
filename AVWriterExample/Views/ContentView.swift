//
//  ContentView.swift
//  AVWriterExample
//
//  Created by Ken Torimaru on 1/8/20.
//  Copyright © 2020 Torimaru & Williamson, LLC. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        CameraView()
            .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
