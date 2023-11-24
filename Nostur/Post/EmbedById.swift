//
//  EmbedById.swift
//  Nostur
//
//  Created by Fabian Lachman on 21/09/2023.
//

import SwiftUI

struct EmbedById: View {
    @EnvironmentObject private var dim:DIMENSIONS
    public let id:String
    public var forceAutoload:Bool = false
    public var theme:Theme
    @StateObject private var vm = FetchVM<NRPost>(timeout: 2.5, debounceTime: 0.05)
    
    var body: some View {
        Group {
            switch vm.state {
            case .initializing, .loading, .altLoading:
                ProgressView()
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .task {
                        vm.setFetchParams((
                            prio: true,
                            req: { taskId in
                                bg().perform {
                                    if let event = try? Event.fetchEvent(id: self.id, context: bg()) {
                                        vm.ready(NRPost(event: event, withFooter: false, isPreview: dim.isScreenshot))
                                    }
                                    else {
                                        req(RM.getEvent(id: self.id, subscriptionId: taskId))
                                    }
                                }
                            },
                            onComplete: { relayMessage, event in
                                if let event = event {
                                    vm.ready(NRPost(event: event, withFooter: false, isPreview: dim.isScreenshot))
                                }
                                else if let event = try? Event.fetchEvent(id: self.id, context: bg()) {
                                    vm.ready(NRPost(event: event, withFooter: false, isPreview: dim.isScreenshot))
                                }
                                else if [.initializing, .loading].contains(vm.state) {
                                    // try search relays
                                    vm.altFetch()
                                }
                                else {
                                    vm.timeout()
                                }
                            },
                            altReq: { taskId in
                                // Try search relays
                                req(RM.getEvent(id: self.id, subscriptionId: taskId), relayType: .SEARCH)
                            }
                        ))
                        vm.fetch()
                    }
            case .ready(let nrPost):
                if nrPost.kind == 30023 {
                    ArticleView(nrPost, hideFooter: true, forceAutoload: forceAutoload, theme: theme)
                        .padding(20)
                        .background(
                            Color(.secondarySystemBackground)
                                .cornerRadius(15)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.regularMaterial, lineWidth: 1)
                        )
//                        .transaction { t in t.animation = nil }
//                        .debugDimensions("EmbedById.ArticleView")
                }
                else {
                    QuotedNoteFragmentView(nrPost: nrPost, forceAutoload: forceAutoload, theme: theme)
//                        .transaction { t in t.animation = nil }
//                        .debugDimensions("EmbedById.QuotedNoteFragmentView")
                }
            case .timeout:
                VStack {
                    Text("Unable to fetch content")
                    Button("Retry") { vm.state = .loading; vm.fetch() }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .center)
            case .error(let error):
                Text(error)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(theme.lineColor.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    PreviewContainer({ pe in pe.loadPosts() }) {
        if let post = PreviewFetcher.fetchNRPost() {
            EmbedById(id: post.id, theme: Themes.default.theme)
        }
    }
}
