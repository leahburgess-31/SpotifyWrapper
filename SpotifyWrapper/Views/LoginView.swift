import SwiftUI
import Combine

struct LoginView: ViewModifier {

    fileprivate static var debugAlwaysShowing = false
    
    static let animation = Animation.spring()
    
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var spotify: Spotify

    @State private var finishedViewLoadDelay = false
    
    let backgroundGradient = LinearGradient(
        gradient: Gradient(
            colors: [
                Color(red: 0.467, green: 0.765, blue: 0.267),
                Color(red: 0.190, green: 0.832, blue: 0.437)
            ]
        ),
        startPoint: .leading, endPoint: .trailing
    )
    
    
    func body(content: Content) -> some View {
        content
            .blur(
                radius: spotify.isAuthorized && !Self.debugAlwaysShowing ? 0 : 3
            )
            .overlay(
                ZStack {
                    if !spotify.isAuthorized || Self.debugAlwaysShowing {
                        Color.black
                            .edgesIgnoringSafeArea(.all)
                        if self.finishedViewLoadDelay || Self.debugAlwaysShowing {
                            loginView
                        }
                    }
                }
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(LoginView.animation) {
                        self.finishedViewLoadDelay = true
                    }
                }
            }
    }
    
    var loginView: some View {
        spotifyButton
            .padding()
            .background(Color(.black))
            .cornerRadius(20)
            .shadow(radius: 5)
            .transition(
                AnyTransition.scale(scale: 1.2)
                    .combined(with: .opacity)
            )
    }
    
    var spotifyButton: some View {

        Button(action: spotify.authorize) {
            HStack {
                Text("Log In With Spotify")
                    .font(.title)
            }
            .padding()
            .background(backgroundGradient)
            .clipShape(Capsule())
            .shadow(radius: 5)
        }
        .accessibility(identifier: "Log in with Spotify Identifier")
        .buttonStyle(PlainButtonStyle())
        .allowsHitTesting(!spotify.isRetrievingTokens)
        .padding(.bottom, 5)
        
    }
    
}

struct LoginView_Previews: PreviewProvider {
    
    static let spotify = Spotify()
    
    static var previews: some View {
        RootView()
            .environmentObject(spotify)
            .onAppear(perform: onAppear)
    }
    
    static func onAppear() {
        spotify.isAuthorized = false
        spotify.isRetrievingTokens = true
        LoginView.debugAlwaysShowing = true
    }

}
