//
//  Kind0.swift
//  Nostur
//
//  Created by Fabian Lachman on 04/10/2023.
//

import Foundation
import Combine

class Kind0Processor {
    
    static let shared = Kind0Processor()

    public var queue = DispatchQueue(label: "kind0processor", qos: .utility, attributes: .concurrent)
    public var request = PassthroughSubject<Pubkey, Never>()
    public var receive = PassthroughSubject<Profile, Never>()
    
    private init() {
        setupProcessors()
    }
    
    private var subscriptions = Set<AnyCancellable>()
    
    // Don't access directly, use get/setProfile which goes through own queue
    private var _lru = [Pubkey: Profile]() // TODO: Turn into real LRU
    
    private func getProfile(_ pubkey:String) -> Profile? {
        queue.sync { return _lru[pubkey] }
    }
    
    private func setProfile(_ profile: Profile) {
        queue.async(flags: .barrier) {
            self._lru[profile.pubkey] = profile
        }
    }
    
    private func setupProcessors() {
        request
            // TODO: Add throttle and batching
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .sink { pubkey in
                // check LRU
                if let profile = self.getProfile(pubkey) {
                    self.receive.send(profile)
                    return
                }
                
                // check DB
                bg().perform {
                    if let profile = self.fetchProfile(pubkey: pubkey) {
                        self.receive.send(profile)
                        self.setProfile(profile)
                    }
                    else {
                        // req relay
                        req(RM.getUserMetadata(pubkey: pubkey))
                    }
                }
            }
            .store(in: &subscriptions)
        
        receive
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .sink { profile in
                self.setProfile(profile)
            }
            .store(in: &subscriptions)
    }
    
    private func fetchProfile(pubkey: Pubkey) -> Profile? {
        guard let contact = Contact.fetchByPubkey(pubkey, context: bg())
        else { return nil }
        return Profile(pubkey: pubkey, name: contact.anyName, pictureUrl: contact.pictureUrl)
    }
}

struct Profile {
    let pubkey:String
    let name:String
    var pictureUrl:URL?
}
