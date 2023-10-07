//
//  FollowingGuardian.swift
//  Nostur
//
//  Created by Fabian Lachman on 02/04/2023.
//

import Foundation
import Combine

// The following guardian, watches for any changes in your contact list
// If contacts are reduced (by another (broken) client) it can ask you to restore
// It also adds new followers you added through other clients

class FollowingGuardian: ObservableObject {
    
    @Published var didReceiveContactListThisSession = false {
        didSet {
            if didReceiveContactListThisSession {
                L.og.info("🙂🙂 FollowingGuardian.didReceiveContactListThisSession: \(self.didReceiveContactListThisSession)")
            }
        }
    }
    
    static let shared = FollowingGuardian()
    
    var subscriptions = Set<AnyCancellable>()
    var checkForNewTimer:Timer?
    
    init() {
#if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }
#endif
        listenForNewContactListEvents()
        listenForAccountChanged()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.checkForUpdatedContactList()
        }
    }
    
    func checkForUpdatedContactList() {
        guard !NRState.shared.activeAccountPublicKey.isEmpty else { return }
        L.og.info("FollowingGuardian: Checking for updated contact list")
        reqP(RM.getAuthorContactsList(pubkey: NRState.shared.activeAccountPublicKey, subscriptionId: "RM.getAuthorContactsList"))
    }
    
    func listenForAccountChanged() {
        receiveNotification(.activeAccountChanged)
            .debounce(for: .seconds(15), scheduler: RunLoop.main)
            .sink { notification in
                let account = notification.object as! Account
                guard account.privateKey != nil else { return }
                reqP(RM.getAuthorContactsList(pubkey: account.publicKey, subscriptionId: "RM.getAuthorContactsList"))
            }
            .store(in: &subscriptions)
    }
    
    func listenForNewContactListEvents() {
        receiveNotification(.newFollowingListFromRelay)
            .receive(on: RunLoop.main)
            .sink { notification in
                let nEvent = notification.object as! NEvent
                guard nEvent.kind == .contactList else { return }
                guard nEvent.publicKey == NRState.shared.activeAccountPublicKey else { return }
                guard let account = NRState.shared.loggedInAccount?.account else { return }
                
                // TODO: Make this work for all accounts, not just active
                let pubkeysOwn = Set(account.follows?.filter { !$0.privateFollow } .map({ c in c.pubkey }) ?? [])
                let pubkeysRelay = Set(nEvent.pTags())
                
                let removed = pubkeysOwn.subtracting(pubkeysRelay)
                let added = pubkeysRelay.subtracting(pubkeysOwn)
                L.og.info("FollowingGuardian: receiveNotification(.newFollowingListFromRelay): added: \(added)")
                
                self.followNewContacts(added: added, account: account)
                let tagsRelay = nEvent.tTags()
                self.followTags(tagsRelay, account: account)
                
                guard account.privateKey != nil else { return }
                
                if !removed.isEmpty {
                    if removed.count < 10 {
                        bg().perform {
                            let removedContacts = Contact.fetchByPubkeys(Array(removed), context: bg())
                            let names = removedContacts.map { String($0.anyName.prefix(30)) }.joined(separator: ", ")
                            DispatchQueue.main.async {
                                sendNotification(.requestConfirmationChangedFollows, RemovedPubkeys(pubkeys: removed, namesString: names))
                            }
                        }
                    }
                    else {
                        sendNotification(.requestConfirmationChangedFollows, RemovedPubkeys(pubkeys: removed))
                        L.og.info("FollowingGuardian: receiveNotification(.newFollowingListFromRelay): removed: \(removed)")
                    }
                }
            }
            .store(in: &subscriptions)
    }
    
    func followNewContacts(added:Set<String>, account:Account) {
        guard !added.isEmpty else { return }
        account.objectWillChange.send()
        
        let context = DataProvider.shared().viewContext
        for pubkey in added {
            let contact = Contact.fetchByPubkey(pubkey, context: context)
            if let contact {
                contact.couldBeImposter = 0
                account.addToFollows(contact)
            }
            else {
                let newContact = Contact(context: context)
                newContact.pubkey = pubkey
                newContact.metadata_created_at = 0
                newContact.updated_at = 0
                newContact.couldBeImposter = 0
                account.addToFollows(newContact)
            }
        }
        DataProvider.shared().save()
        NRState.shared.loggedInAccount?.reloadFollows()
    }
    
    func followTags(_ tags:[String], account:Account) {
        guard !tags.isEmpty else { return }
        account.objectWillChange.send()
        for tag in tags {
            account.followingHashtags.insert(tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        } // TODO: CHECK FOLLOWING NEW HASHTAGS
//        sendNotification(.followersChanged, account.followingPublicKeys)
        LVMManager.shared.followingLVM(forAccount: account).loadHashtags()
    }
    
    func restoreFollowing(removed:Set<String>, republish:Bool = true) {
        guard let account = account() else { return }
        let context = DataProvider.shared().viewContext
        for pubkey in removed {
            let contact = Contact.fetchByPubkey(pubkey, context: context)
            if let contact {
                contact.couldBeImposter = 0
                account.addToFollows(contact)
            }
            else {
                let newContact = Contact(context: context)
                newContact.pubkey = pubkey
                newContact.metadata_created_at = 0
                newContact.updated_at = 0
                newContact.couldBeImposter = 0
                account.addToFollows(newContact)
            }
        }
        NRState.shared.loggedInAccount?.reloadFollows()
        guard republish else { return }
        account.publishNewContactList()
    }
    
    func removeFollowing(_ pubkeys:Set<String>) {
        guard let account = account() else { return }
        for contact in account.follows_ {
            if pubkeys.contains(contact.pubkey) {
                account.removeFromFollows(contact)
            }
        }
        NRState.shared.loggedInAccount?.reloadFollows()
        DataProvider.shared().save()
    }
}
