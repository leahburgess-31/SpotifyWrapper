//
//  SpotifyWrapperApp.swift
//  SpotifyWrapper
//
//  Created by Leah on 2024-01-28.
//

import SwiftUI
import Combine
import SpotifyWebAPI

@main
struct SpotifyWrapperApp: App {
    @StateObject var spotify = Spotify()

        init() {
            SpotifyAPILogHandler.bootstrap()
        }

        var body: some Scene {
            WindowGroup {
                RootView()
                    .environmentObject(spotify)
            }
        }
}
