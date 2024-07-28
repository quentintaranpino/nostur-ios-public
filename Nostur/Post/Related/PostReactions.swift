//
//  PostReactions.swift
//  Nostur
//
//  Created by Fabian Lachman on 27/07/2024.
//

import SwiftUI
import CoreData
import NavigationBackport

struct PostReactions: View {
    public var eventId: String
    @EnvironmentObject private var themes: Themes
    @StateObject private var model = PostReactionsModel()

    @State private var backlog = Backlog()
    @Namespace private var top
    
    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear.frame(height: 1).id(top)
                LazyVStack(spacing: 2) {
                    ForEach(model.reactions) { nrPost in
                        HStack(alignment: .top) {
                            PFP(pubkey: nrPost.pubkey, nrContact: nrPost.contact)
                                .onTapGesture {
                                    navigateTo(ContactPath(key: nrPost.pubkey))
                                }
                            VStack(alignment: .leading) {
                                NRPostHeaderContainer(nrPost: nrPost)
                                Text(nrPost.content == "+" ? "❤️" : nrPost.content ?? "")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            navigateTo(ContactPath(key: nrPost.pubkey))
                        }
                        .id(nrPost.id)
                        Divider()
                    }
                }
            }
        }
        .background(themes.theme.listBackground)
        .onAppear {
            model.setup(eventId: eventId)
            model.load(limit: 50)
            fetchNewer()
        }
        .onReceive(Importer.shared.importedMessagesFromSubscriptionIds.receive(on: RunLoop.main)) { [weak backlog] subscriptionIds in
            bg().perform {
                guard let backlog else { return }
                let reqTasks = backlog.tasks(with: subscriptionIds)
                reqTasks.forEach { task in
                    task.process()
                }
            }
        }
    }
    
    private func fetchNewer() {
        L.og.debug("🥎🥎 fetchNewer() (POST REACTIONS)")
        let fetchNewerTask = ReqTask(
            reqCommand: { taskId in
                bg().perform {
                    req(RM.getEventReferences(
                        ids: [eventId],
                        limit: 500,
                        subscriptionId: taskId,
                        kinds: [7],
                        since: NTimestamp(timestamp: Int(model.mostRecentReactionCreatedAt))
                    ))
                }
            },
            processResponseCommand: { (taskId, _, _) in
                model.load(limit: 500)
            },
            timeoutCommand: { taskId in
                model.load(limit: 500)
            })
        
        backlog.add(fetchNewerTask)
        fetchNewerTask.fetch()
    }
}
