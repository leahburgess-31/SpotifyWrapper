//
//  SpotifyApiExtensions.swift
//  SpotifyWrapper
//
//  Created by Leah on 2024-01-29.
//

import Foundation
import Combine
import SpotifyWebAPI

extension SpotifyAPI where AuthorizationManager: SpotifyScopeAuthorizationManager {

    func getAvailableDeviceThenPlay(
        _ playbackRequest: PlaybackRequest
    ) -> AnyPublisher<Void, Error> {
        
        return self.availableDevices().flatMap {
            devices -> AnyPublisher<Void, Error> in
    
            let usableDevices = devices.filter { device in
                !device.isRestricted && device.id != nil
            }

            let device = usableDevices.first(where: \.isActive)
                    ?? usableDevices.first
            
            if let deviceId = device?.id {
                return self.play(playbackRequest, deviceId: deviceId)
            }
            else {
                return SpotifyGeneralError.other(
                    "no active or available devices",
                    localizedDescription:
                    "There are no devices available to play content on. " +
                    "Try opening the Spotify app on one of your devices."
                )
                .anyFailingPublisher()
            }
            
        }
        .eraseToAnyPublisher()
        
    }

}
