//
//  ContentView.swift
//  Compositor
//
//  Created by Maxim Eliseyev on 10.07.2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        CompositorView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
