import SwiftUI
import Combine
import SpotifyWebAPI
import URLImage


struct RootView: View {
    
    @EnvironmentObject var spotify: Spotify
    
    @State private var alert: AlertItem? = nil

    @State private var cancellables: Set<AnyCancellable> = []
    @State private var playRequestCancellable: AnyCancellable? = nil
    
    @State private var topTracks: [Track] = []
    
    @State private var didRequestTopTracks = false
    @State private var isLoadingTopTracks = false
    @State private var couldntLoadTopTracks = false

    @State private var loadTopTracksCancellable: AnyCancellable? = nil
    
    @State private var selectedTimeRange: TimeRange = .shortTerm
    
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                HStack{
                    Text("Most Listened").padding(.leading)
                    Spacer()
                    Picker("Time Range", selection: $selectedTimeRange) {
                        Text("Short Term").tag(TimeRange.shortTerm)
                        Text("Medium Term").tag(TimeRange.mediumTerm)
                        Text("Long Term").tag(TimeRange.longTerm)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .foregroundColor(.white)
                    .padding(.trailing)
                }.foregroundColor(.white).font(.title).fontWeight(.bold)
                
                LazyVStack {
                    ForEach(topTracks, id: \.id) { track in
                        TrackCard(track: track).overlay(Button(action: {
                            playTrack(track: track)
                        }) {
                            Image(systemName: "play.circle")
                                .resizable()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .frame(width: 100, height: 100)
                                .foregroundColor(.white)
                        }
                        .padding(.top, -60))
                    }
                }
                .padding()
            }
        }
        .modifier(LoginView())
        .alert(item: $alert) { alert in
            Alert(title: alert.title, message: alert.message)
        }
        .onOpenURL(perform: handleURL(_:))
        .onAppear {
            if !self.didRequestTopTracks {
                self.retrieveTopTracks()
            }
        }
        .onChange(of: selectedTimeRange) { _ in
            self.retrieveTopTracks()
        }
        .preferredColorScheme(.dark)
    }
    
    func retrieveTopTracks() {
        self.didRequestTopTracks = true
        self.isLoadingTopTracks = true
        self.topTracks = []

        self.loadTopTracksCancellable = self.spotify.api.currentUserTopTracks(selectedTimeRange, offset: 0, limit: 10)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoadingTopTracks = false
                    switch completion {
                        case .finished:
                            self.couldntLoadTopTracks = false
                        case .failure(let error):
                            self.couldntLoadTopTracks = true
                        print("Error retrieving top tracks: \(error)")
                            self.alert = AlertItem(
                                title: "Couldn't Retrieve Top Tracks",
                                message: error.localizedDescription
                            )
                    }
                },
                receiveValue: { tracks in
                    let topTracks = tracks.items
                        .filter { $0.id != nil }
                    self.topTracks.append(contentsOf: topTracks)
                }
                                       
            )
    }
    
    struct TrackCard: View {
        let track: Track

        var body: some View {
            VStack{
                RoundedRectangle(cornerRadius: 30).foregroundColor(.black).frame(width: 300, height: 300).overlay(
                    VStack{
                        
                        URLImage((track.album?.images?.first?.url)!) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 250, height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .black, radius: 3, y: 3)
                        }

                        Text(track.name)
                            .foregroundColor(.white).font(.system(.headline)).multilineTextAlignment(.center)
                        if let artists = track.artists {
                            Text(artists.map { $0.name }.joined(separator: ", "))
                                .foregroundColor(.white)
                                .font(.subheadline).multilineTextAlignment(.center)
                        }
                    }
                )
                
            }
            .padding()
        }
    }
    
    func handleURL(_ url: URL) {
        guard url.scheme == self.spotify.loginCallbackURL.scheme else {
            print("not handling URL: unexpected scheme: '\(url)'")
            self.alert = AlertItem(
                title: "Cannot Handle Redirect",
                message: "Unexpected URL"
            )
            return
        }
        
        print("received redirect from Spotify: '\(url)'")

        spotify.isRetrievingTokens = true
        
        spotify.api.authorizationManager.requestAccessAndRefreshTokens(
            redirectURIWithQuery: url,
            state: spotify.authorizationState
        )
        .receive(on: RunLoop.main)
        .sink(receiveCompletion: { completion in
            self.spotify.isRetrievingTokens = false
            
            if case .failure(let error) = completion {
                print("couldn't retrieve access and refresh tokens:\n\(error)")
                let alertTitle: String
                let alertMessage: String
                if let authError = error as? SpotifyAuthorizationError,
                   authError.accessWasDenied {
                    alertTitle = "You Denied The Authorization Request :("
                    alertMessage = ""
                }
                else {
                    alertTitle =
                        "Couldn't Authorization With Your Account"
                    alertMessage = error.localizedDescription
                }
                self.alert = AlertItem(
                    title: alertTitle, message: alertMessage
                )
            }
        })
        .store(in: &cancellables)
        
        self.spotify.authorizationState = String.randomURLSafe(length: 128)
        
    }
    
    func playTrack(track: Track) {
        
        let alertTitle = "Couldn't Play \(track.name)"

        guard let trackURI = track.uri else {
            self.alert = AlertItem(
                title: alertTitle,
                message: "missing URI"
            )
            return
        }

        let playbackRequest: PlaybackRequest

        if let albumURI = track.album?.uri {
            playbackRequest = PlaybackRequest(
                context: .contextURI(albumURI),
                offset: .uri(trackURI)
            )
        }
        else {
            playbackRequest = PlaybackRequest(trackURI)
        }
        
        self.playRequestCancellable =
            self.spotify.api.getAvailableDeviceThenPlay(playbackRequest)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.alert = AlertItem(
                            title: alertTitle,
                            message: error.localizedDescription
                        )
                    }
                })
        
    }
    
    /// Removes the authorization information for the user.
    var logoutButton: some View {
        Button(action: spotify.api.authorizationManager.deauthorize, label: {
            Text("Logout")
                .foregroundColor(.white)
                .padding(7)
                .background(
                    Color(red: 0.392, green: 0.720, blue: 0.197)
                )
                .cornerRadius(10)
                .shadow(radius: 3)
            
        })
    }
}

struct RootView_Previews: PreviewProvider {
    
    static let spotify: Spotify = {
        let spotify = Spotify()
        spotify.isAuthorized = true
        return spotify
    }()
    
    static var previews: some View {
        RootView()
            .environmentObject(spotify)
    }
}
