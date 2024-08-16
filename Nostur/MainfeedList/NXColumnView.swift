//
//  NXColumnView.swift
//  Nosturix
//
//  Created by Fabian Lachman on 01/08/2024.
//

import SwiftUI
import NavigationBackport

struct NXColumnView: View {
    
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var dim: DIMENSIONS
    public let config: NXColumnConfig
    @StateObject private var viewModel = NXColumnViewModel()
    public var isVisible: Bool
    
    @State var showFeedSettings = false
    @State private var feedSettingsConfig: NXColumnConfig?
    @State private var didLoad = false
    
    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif
        NBNavigationStack {
            switch(viewModel.viewState) {
            case .loading:
                ProgressView()
            case .posts(let nrPosts):
                NXPostsFeed(vm: viewModel, posts: nrPosts)
            case .error(let errorMessage):
                Text(errorMessage)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            L.og.debug("☘️☘️ \(config.id) .onAppear")
            viewModel.isVisible = isVisible
            viewModel.availableWidth = dim.availableNoteRowWidth
            viewModel.load(config)
        }
        .onChange(of: isVisible) { newValue in
            L.og.debug("☘️☘️ \(config.id) .onChange(of: isVisible)")
            guard viewModel.isVisible != newValue else { return }
            viewModel.isVisible = newValue
        }
        .onChange(of: dim.availableNoteRowWidth) { newValue in
            L.og.debug("☘️☘️ \(config.id) .onChange(of: availableNoteRowWidth)")
            guard viewModel.availableWidth != newValue else { return }
            viewModel.availableWidth = newValue
        }
        .onReceive(receiveNotification(.showFeedToggles)) { _ in
            guard isVisible, let config = viewModel.config else { return }
            showFeedSettings = true
            feedSettingsConfig = config
        }
        .sheet(item: $feedSettingsConfig, content: { configToUse in
            NBNavigationStack {
                FeedSettings(config: configToUse)
            }
            .nbUseNavigationStack(.never)
        })
        
        
        // Resume on (re)connect or back from background
        .onChange(of: scenePhase) { newScenePhase in
            switch newScenePhase {
            case .active:
                if !IS_CATALYST {
                    if (NRState.shared.appIsInBackground) { // if we were actually in background (from .background, not just a few seconds .inactive)
                        viewModel.resume()
                    }
                }
                else {
                    viewModel.resume()
                }
                
            case .background:
                if !IS_CATALYST {
                    viewModel.pause()
                }
            default:
                break
            }
        }
    }
}

#Preview {
    PreviewContainer({ pe in
        pe.loadContacts()
        pe.loadPosts()
        pe.loadCloudFeeds(1)
    }) {
        
        if let list = PreviewFetcher.fetchList() {
            let config = NXColumnConfig(id: list.id?.uuidString ?? "?", columnType: .pubkeys(list), accountPubkey: "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e", name: "Following")
            NXColumnView(config: config, isVisible: true)
        }
    }
}
