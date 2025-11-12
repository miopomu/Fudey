//
//  CalliSensei3App.swift
//  CalliSensei3
//
//  Created by 三田村美桜 on 2025/09/14.
//

import SwiftUI
import Firebase

@main
struct CalliSensei3App: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }
}
