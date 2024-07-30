//
//  View+withNavigationDestinations.swift
//  Nostur
//
//  Created by Fabian Lachman on 02/02/2023.
//

import Foundation
import SwiftUI
import NavigationBackport

struct NotePath: IdentifiableDestination {
    var id: String
    var navigationTitle: String? = nil
}

struct ContactPath: IdentifiableDestination {
    var id: String { key }
    var key: String
    var navigationTitle: String? = nil
    var tab: String? = nil
}

struct NRContactPath: IdentifiableDestination {
    var id: String { nrContact.pubkey }
    var nrContact: NRContact
    var navigationTitle: String? = nil
    var tab: String? = nil
}

struct HashtagPath: IdentifiableDestination {
    var id: String { hashTag }
    var hashTag: String
    var navigationTitle: String? = nil
}

struct Nevent1Path: IdentifiableDestination {
    var id: String { nevent1 }
    var nevent1: String
    var navigationTitle: String? = nil
}

struct Naddr1Path: IdentifiableDestination {
    public var id: String { naddr1 }
    public var naddr1: String
    public var navigationTitle: String? = nil
    
    public var kind: Int { // -999999912 means we dont have a kind
        Int((try? ShareableIdentifier(naddr1).kind) ?? -999899912)
    }
    
    public var navId: String { 
        (try? ShareableIdentifier(naddr1))?.aTag ?? id
    }
    
    init(naddr1: String, navigationTitle: String? = nil) {
        self.naddr1 = naddr1
        self.navigationTitle = navigationTitle
    }
}

struct ArticlePath: IdentifiableDestination {
    var id: String
    var navigationTitle: String? = nil
}

struct Nprofile1Path: IdentifiableDestination {
    var id: String { nprofile1 }
    var nprofile1: String
    var navigationTitle: String? = nil
}

struct ArticleCommentsPath: Identifiable, IdentifiableDestination {
    var id: String { article.id }
    let article: NRPost
}

enum ViewPath: IdentifiableDestination {
    var id: String { UUID().uuidString }
    
    case Post(nrPost: NRPost)
    case Blocklist
    case Bookmarks(account: CloudAccount)
    case PostReactions(eventId: String)
    case NoteReposts(id: String)
    case PostZaps(eventId: String)
    case Settings
    case Lists
    case Relays
    case Badges
    case Gallery(vm: GalleryViewModel)
}

extension View {
    func withNavigationDestinations() -> some View {
        return self
            .nbNavigationDestination(for: NRPost.self) { nrPost in
                switch nrPost.kind {
                case 30023:
                    ArticleView(nrPost, isDetail: true, fullWidth: SettingsStore.shared.fullWidthImages, hideFooter: false)
                case 30311:
                    if let nrLiveEvent = nrPost.nrLiveEvent {
                        LiveEventDetail(liveEvent: nrLiveEvent)
                    }
                    else {
                        Text("Missing nrLiveEvent")
                    }
                default:
                    PostDetailView(nrPost: nrPost)
                        .equatable()
                        .debugDimensions("nbNavigationDestination.PostDetailView", alignment: .topLeading)
                }
            }
            .nbNavigationDestination(for: Naddr1Path.self) { path in
                switch path.kind {
                case 30311:
                    LiveEventByNaddr(naddr1: path.naddr1, navigationTitle: path.navigationTitle)
                default:
                    ArticleByNaddr(naddr1: path.naddr1, navigationTitle: path.navigationTitle)
                }
            }       
            .nbNavigationDestination(for: NRLiveEvent.self) { nrLiveEvent in
                LiveEventDetail(liveEvent: nrLiveEvent)
            }
            .nbNavigationDestination(for: ArticlePath.self) { path in
                ArticleById(id: path.id, navigationTitle: path.navigationTitle)
            }
            .nbNavigationDestination(for: ArticleCommentsPath.self) { articleCommentsPath in
                ArticleCommentsView(article: articleCommentsPath.article)
            }
            .nbNavigationDestination(for: NotePath.self) { path in
                NoteById(id: path.id)
            }
            .nbNavigationDestination(for: ContactPath.self) { path in
                ProfileByPubkey(pubkey: path.key, tab: path.tab)
            }
            .nbNavigationDestination(for: NRContactPath.self) { path in
                ProfileView(nrContact: path.nrContact, tab: path.tab)
            }
            .nbNavigationDestination(for: NRContact.self) { nrContact in
                ProfileView(nrContact: nrContact)
            }
            .nbNavigationDestination(for: Badge.self) { badge in
                BadgeDetailView(badge: badge.badge)
            }
            .nbNavigationDestination(for: CloudFeed.self) { list in
                if list.type == LVM.ListType.relays.rawValue {
                    EditRelaysNosturList(list: list)
                }
                else {
                    EditNosturList(list: list)
                }
            }
            .nbNavigationDestination(for: ViewPath.self) { path in
                switch (path) {
                    case .Post(let post):
                        PostDetailView(nrPost: post)
                            .equatable()
                            .debugDimensions("nbNavigationDestination2.PostDetailView", alignment: .topLeading)
                    case .Blocklist:
                        BlockListView()
                    case .PostReactions(let eventId):
                        PostReactions(eventId: eventId)
                    case .NoteReposts(let id):
                        NoteReposts(id: id)
                    case .PostZaps(let id):
                        PostZaps(eventId: id)
                    case .Settings:
                        Settings()
                    case .Lists:
                        NosturListsView()
                    case .Relays:
                        RelaysView()    
                    case .Badges:
                        BadgesView()
                    default:
                        EmptyView()
                }
            }
    }
}

struct NavigationDestination {
    let destination: any IdentifiableDestination
}

protocol IdentifiableDestination: Hashable, Identifiable {
    
}

func navigateTo(_ path: any IdentifiableDestination) {
    sendNotification(.scrollingUp) // this makes the tab bars appear for navigating
    
    if (type(of: path) == NRPost.self) {
        let nrPost = path as! NRPost
        if nrPost.kind == 30023 {
            sendNotification(.navigateTo, NavigationDestination(destination: ArticlePath(id: nrPost.id, navigationTitle: nrPost.eventTitle ?? "Article")))
        }
        else {
            sendNotification(.navigateTo, NavigationDestination(destination: path))
        }
    }
    else {
        sendNotification(.navigateTo, NavigationDestination(destination: path))
    }
}

func navigateToOnMain(_ path: any IdentifiableDestination) {
    sendNotification(.navigateToOnMain, NavigationDestination(destination: path))
}

func navigateOnDetail(_ path: any IdentifiableDestination) {
    sendNotification(.navigateToOnDetail, NavigationDestination(destination: path))
}
