//
//  Even+CoreDataProperties.swift
//  Nostur
//
//  Created by Fabian Lachman on 15/01/2023.
//
//

import Foundation
import CoreData
import NostrEssentials

// TODO: This file is too long, needs big refactor
extension Event {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        let fr = NSFetchRequest<Event>(entityName: "Event")
        fr.sortDescriptors = []
        return fr
    }
    
    @NSManaged public var insertedAt: Date // Needed for correct ordering of events in timeline
    
    @NSManaged public var content: String?
    @NSManaged public var created_at: Int64
    @NSManaged public var id: String
    @NSManaged public var kind: Int64
    @NSManaged public var pubkey: String
    @NSManaged public var sig: String?
    @NSManaged public var tagsSerialized: String?
    @NSManaged public var relays: String
    
    @NSManaged public var replyToRootId: String?
    @NSManaged public var replyToId: String?
    @NSManaged public var firstQuoteId: String?
    
    @NSManaged public var isRepost: Bool // Cache
    
    // Counters (cached)
    @NSManaged public var likesCount: Int64 // Cache
    @NSManaged public var repostsCount: Int64 // Cache
    @NSManaged public var repliesCount: Int64 // Cache
    @NSManaged public var mentionsCount: Int64 // Cache
    @NSManaged public var zapsCount: Int64 // Cache
    
    @NSManaged public var bookmarkedBy: Set<Account>?
    @NSManaged public var contact: Contact?
    @NSManaged public var personZapping: Contact?
    @NSManaged public var replyTo: Event?
    @NSManaged public var replyToRoot: Event?
    @NSManaged public var firstQuote: Event?
    @NSManaged public var zapTally: Int64
    
    @NSManaged public var replies: Set<Event>?
    
    @NSManaged public var contacts: Set<Contact>?
    
    @NSManaged public var deletedById: String?
    @NSManaged public var dTag: String
    
    var aTag:String { (String(kind) + ":" + pubkey  + ":" + dTag) }
    
    // For events with multiple versions (like NIP-33)
    // Most recent version should be nil
    // All older versions have a pointer to the most recent id
    // This makes it easy to query for the most recent event (mostRecentId = nil)
    @NSManaged public var mostRecentId: String?
    
    
    // Can be used for anything
    // Now we use it for:
    // - "is_update": to not show same article over and over in feed when it gets updates
    @NSManaged public var flags: String
    
    var contact_: Contact? {
        guard contact == nil else { return contact }
        guard let ctx = managedObjectContext else { return nil }
        if let found = Contact.fetchByPubkey(pubkey, context: ctx) {
            if Thread.isMainThread {
                found.objectWillChange.send()
                self.contact = found
            }
            else {
                self.contact = found
            }
            return found
        }
        return nil
    }
    
    var replyTo_:Event? {
        guard replyTo == nil else { return replyTo }
        if replyToId == nil && replyToRootId != nil { // Only replyToRootId? Treat as replyToId
            replyToId = replyToRootId
        }
        guard let replyToId = replyToId else { return nil }
        guard let ctx = managedObjectContext else { return nil }
        if let found = try? Event.fetchEvent(id: replyToId, context: ctx) {
            self.replyTo = found
            found.addToReplies(self)
            return found
        }
        return nil
    }
    
    var replyTo__:Event? {
        guard replyTo == nil else { return replyTo }
        if replyToId == nil && replyToRootId != nil { // Only replyToRootId? Treat as replyToId
            replyToId = replyToRootId
        }
        guard let replyToId = replyToId else { return nil }
        guard let ctx = managedObjectContext else { return nil }
        if let found = try? Event.fetchEvent(id: replyToId, context: ctx) {
            self.replyTo = found
            found.addToReplies(self)
            return found
        }
        return nil
    }
    
    var firstQuote_:Event? {
        guard firstQuote == nil else { return firstQuote }
        guard let firstQuoteId = firstQuoteId else { return nil }
        guard let ctx = managedObjectContext else { return nil }
        if let found = try? Event.fetchEvent(id: firstQuoteId, context: ctx) {
            self.firstQuote = found
            return found
        }
        return nil
    }

    var replies_: [Event] { Array(replies ?? []) }

    // Gets all parents. If until(id) is set, it will stop and wont traverse further, to prevent rendering duplicates
    static func getParentEvents(_ event:Event, fixRelations:Bool = false, until:String? = nil) -> [Event] {
        let RECURSION_LIMIT = 35 // PREVENT SPAM THREADS
        var parentEvents = [Event]()
        var currentEvent:Event? = event
        var i = 0
        while (currentEvent != nil) {
            if i > RECURSION_LIMIT {
                break
            }
            
            if until != nil && currentEvent!.replyToId == until {
                break
            }
            
            if let replyTo = fixRelations ? currentEvent?.replyTo__ : currentEvent?.replyTo {
                parentEvents.append(replyTo)
                currentEvent = replyTo
                i = (i + 1)
            }
            else {
                currentEvent = nil
            }
        }
        return parentEvents
            .sorted(by: { $0.created_at < $1.created_at })
    }
    
    func toMain() -> Event? {
        if Thread.isMainThread {
            return DataProvider.shared().viewContext.object(with: self.objectID) as? Event
        }
        else {
            return DispatchQueue.main.sync {
                return DataProvider.shared().viewContext.object(with: self.objectID) as? Event
            }
        }
    }
    
    func toBG() -> Event? {
        if Thread.isMainThread {
            L.og.info("🔴🔴🔴 toBG() should be in bg already, switching now but should fix code")
            return bg().performAndWait {
                return bg().object(with: self.objectID) as? Event
            }
        }
        else {
            return bg().object(with: self.objectID) as? Event
        }
    }
}

// MARK: Generated accessors for contacts
extension Event {
    
    @objc(addContactsObject:)
    @NSManaged public func addToContacts(_ value: Contact)
    
    @objc(removeContactsObject:)
    @NSManaged public func removeFromContacts(_ value: Contact)
    
    @objc(addContacts:)
    @NSManaged public func addToContacts(_ values: NSSet)
    
    @objc(removeContacts:)
    @NSManaged public func removeFromContacts(_ values: NSSet)
    
}


// MARK: Generated accessors for bookmarkedBy
// Old bookmark relations, no longer needed, but can't remove yet because needed for
// one time migration. After migration we can remove the code but need to figure out to do that
extension Event {
    
    @objc(addBookmarkedByObject:)
    @NSManaged public func addToBookmarkedBy(_ value: Account)
    
    @objc(removeBookmarkedByObject:)
    @NSManaged public func removeFromBookmarkedBy(_ value: Account)
    
    @objc(addBookmarkedBy:)
    @NSManaged public func addToBookmarkedBy(_ values: NSSet)
    
    @objc(removeBookmarkedBy:)
    @NSManaged public func removeFromBookmarkedBy(_ values: NSSet)
    
    var bookmarkedBy_:Set<Account> {
        get { bookmarkedBy ?? [] }
    }
    
}

// MARK: Generated accessors for replies
extension Event {
    
    @objc(addRepliesObject:)
    @NSManaged public func addToReplies(_ value: Event)
    
    @objc(removeRepliesObject:)
    @NSManaged public func removeFromReplies(_ value: Event)
    
    @objc(addReplies:)
    @NSManaged public func addToReplies(_ values: NSSet)
    
    @objc(removeReplies:)
    @NSManaged public func removeFromReplies(_ values: NSSet)
    
}

// MARK: Generated accessors for zaps
extension Event {
    //    @NSManaged public var zapFromRequestId: String? // We ALWAYS have zapFromRequest (it is IN the 9735, so not needed)
    @NSManaged public var zappedEventId: String?
    @NSManaged public var otherPubkey: String?
    
    @NSManaged public var zapFromRequest: Event?
    @NSManaged public var zappedEvent: Event?
    @NSManaged public var zappedContact: Contact?
}

// MARK: Generated accessors for reactions
extension Event {
    @NSManaged public var reactionToId: String?
    @NSManaged public var reactionTo: Event?
}

extension Event {
    
    var isSpam:Bool {
        // combine all the checks here
        
        if kind == 9735, let zapReq = zapFromRequest, zapReq.naiveSats >= 250 { // TODO: Make amount configurable
            // Never consider zaps of more than 250 sats as spam
            return false
        }
        
        // Flood check
        // TODO: Add flood check here
        
        // Block list
        // TODO: Move block list check here
        
        // Mute list
        // TODO: Move mute list check here
        
        
        // TODO: Think of more checks
        
        // Web of Trust filter
        if WOT_FILTER_ENABLED() {
            if inWoT { return false }
//            L.og.debug("🕸️🕸️ WebOfTrust: Filtered by WoT: kind: \(self.kind) id: \(self.id): \(self.content ?? "")")
            return true
        }
        
        return false
    }
    
    var inWoT:Bool {
        if kind == 9735, let zapReq = zapFromRequest {
            return WebOfTrust.shared.isAllowed(zapReq.pubkey)
        }
        return WebOfTrust.shared.isAllowed(pubkey)
    }
    
    var plainText: String {
        return NRTextParser.shared.copyPasteText(fastTags: self.fastTags, event: self, text: self.content ?? "").text
    }
    
    var date: Date {
        get {
            Date(timeIntervalSince1970: Double(created_at))
        }
    }
    
    var ago: String { date.agoString }
    
    var authorKey: String {
        String(pubkey.prefix(5))
    }
    
    var noteText: String {
        if kind == 4 {
            guard let account = account(), let pk = account.privateKey, let encrypted = content else {
                return convertToHieroglyphs(text: "(Encrypted content)")
            }
            if pubkey == account.publicKey, let firstP = self.firstP() {
                return NKeys.decryptDirectMessageContent(withPrivateKey: pk, pubkey: firstP, content: encrypted) ?? "(Encrypted content)"
            }
            else {
                return NKeys.decryptDirectMessageContent(withPrivateKey: pk, pubkey: pubkey, content: encrypted) ?? "(Encrypted content)"
            }
        }
        else {
            return content ?? "(empty note)"
        }
    }
    
    var noteTextPrepared: String {
        let tags = fastTags
        guard !tags.isEmpty else { return content ?? "" }
        
        var newText = content ?? ""
        for index in tags.indices {
            if (tags[index].0 == "e") {
                if let note1string = note1(tags[index].1) {
                    newText = newText.replacingOccurrences(of: String("#[\(index)]"), with: "nostr:\(note1string)")
                }
            }
        }
        return newText
    }
    
    var noteId:String {
        try! NIP19(prefix: "note", hexString: id).displayString
    }
    
    var npub:String { try! NIP19(prefix: "npub", hexString: pubkey).displayString }
    
    var via:String? { fastTags.first(where: { $0.0 == "client" })?.1 }
    
    static func textNotes(byAuthorPubkey:String? = nil) -> NSFetchRequest<Event> {
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.entity = Event.entity()
        request.includesPendingChanges = false
        if (byAuthorPubkey != nil) {
            request.predicate = NSPredicate(format: "pubkey == %@ AND kind == 1", byAuthorPubkey!)
        }
        else {
            request.predicate = NSPredicate(format: "kind == 1")
        }
        request.sortDescriptors = [NSSortDescriptor(key: "created_at", ascending: false)]
        
        return request
    }
    
    // GETTER for "setMetaData" Events. !! NOT A SETTER !!
    static func setMetaDataEvents(byAuthorPubkey:String? = nil, context:NSManagedObjectContext) -> [Event]? {
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        if (byAuthorPubkey != nil) {
            request.predicate = NSPredicate(format: "pubkey == %@ AND kind == 0", byAuthorPubkey!)
        }
        else {
            request.predicate = NSPredicate(format: "kind == 0")
        }
        request.sortDescriptors = [NSSortDescriptor(key: "created_at", ascending: false)]
        
        return try? context.fetch(request)
    }
    
    static func contactListEvents(byAuthorPubkey:String? = nil, context:NSManagedObjectContext) -> [Event]? {
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        if (byAuthorPubkey != nil) {
            request.predicate = NSPredicate(format: "kind == 3 AND pubkey == %@", byAuthorPubkey!)
        }
        else {
            request.predicate = NSPredicate(format: "kind == 3")
        }
        request.sortDescriptors = [NSSortDescriptor(key: "created_at", ascending: false)]
        
        return try? context.fetch(request)
    }
    
    static func metadataEvent(byAuthorPubkey:String? = nil, context:NSManagedObjectContext) -> [Event]? {
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        if (byAuthorPubkey != nil) {
            request.predicate = NSPredicate(format: "kind == 0 AND pubkey == %@", byAuthorPubkey!)
        }
        else {
            request.predicate = NSPredicate(format: "kind == 0")
        }
        request.sortDescriptors = [NSSortDescriptor(key: "created_at", ascending: false)]
        
        return try? context.fetch(request)
    }
    
    @discardableResult
    static func makePreviews(count: Int) -> [Event] {
        var events = [Event]()
        let viewContext = DataProvider.shared().container.viewContext
        for index in 0..<count {
            let event = Event(context: viewContext)
            event.insertedAt = Date.now
            event.pubkey = "pubkey\(index)" //rand from preview keys
            event.id = "id\(index)"
            event.created_at = Int64(Date().timeIntervalSince1970)
            event.content = "Preview event"
            event.kind = 0
            event.sig = "ddd"
            events.append(event)
        }
        return events
    }
    
    // NIP-25: The generic reaction, represented by the content set to a + string, SHOULD be interpreted as a "like" or "upvote".
    // NIP-25: The content MAY be an emoji, in this case it MAY be interpreted as a "like" or "dislike", or the client MAY display this emoji reaction on the post.
    // TODO: 167.00 ms    1.5%    0 s          specialized static Event.updateLikeCountCache(_:content:context:)
    static func updateLikeCountCache(_ event: Event, content: String, context: NSManagedObjectContext) throws -> Bool {
        switch content {
            case "-": // (down vote)
                break
            default:
                // # NIP-25: The last e tag MUST be the id of the note that is being reacted to.
                if let lastEtag = event.lastE() {
                    if let reactingToEvent = EventRelationsQueue.shared.getAwaitingBgEvent(byId: lastEtag) {
                        guard !reactingToEvent.isDeleted else { break }
                        reactingToEvent.likesCount = (reactingToEvent.likesCount + 1)
                        ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: reactingToEvent.id, likes: reactingToEvent.likesCount))
                        event.reactionTo = reactingToEvent
                        event.reactionToId = reactingToEvent.id
                    }
                    else {
                        let request = NSFetchRequest<Event>(entityName: "Event")
                        request.entity = Event.entity()
                        request.predicate = NSPredicate(format: "id == %@", lastEtag)
                        request.fetchLimit = 1
                        if let reactingToEvent = try context.fetch(request).first {
                            guard !reactingToEvent.isDeleted else { break }
                            reactingToEvent.likesCount = (reactingToEvent.likesCount + 1)
                            ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: reactingToEvent.id, likes: reactingToEvent.likesCount))
                            event.reactionTo = reactingToEvent
                            event.reactionToId = reactingToEvent.id
                        }
                    }
                }
        }
        return true
    }
    
    // To fix event.reactionTo but not count+1, because +1 is instant at tap, but this relation happens after 8 sec (unpublisher)
    static func updateReactionTo(_ event:Event, context:NSManagedObjectContext) throws {
        if let lastEtag = event.lastE() {
            let request = NSFetchRequest<Event>(entityName: "Event")
            request.entity = Event.entity()
            request.predicate = NSPredicate(format: "id == %@", lastEtag)
            request.fetchLimit = 1
            
            if let reactingToEvent = try context.fetch(request).first {
//                reactingToEvent.likesDidChange.send(reactingToEvent.likesCount)
                ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: reactingToEvent.id, likes: reactingToEvent.likesCount))
                event.reactionTo = reactingToEvent
                event.reactionToId = reactingToEvent.id
            }
        }
    }
    
    
    static func updateZapTallyCache(_ zap: Event, context: NSManagedObjectContext) -> Bool {
        guard let zappedContact = zap.zappedContact else { // NO CONTACT
            if let zappedPubkey = zap.otherPubkey {
                L.fetching.debug("⚡️⏳ missing contact for zap. fetching: \(zappedPubkey), and queueing zap \(zap.id)")
                QueuedFetcher.shared.enqueue(pTag: zappedPubkey)
                ZapperPubkeyVerificationQueue.shared.addZap(zap)
            }
            return false
        }
        
        if zappedContact.metadata_created_at == 0 {
            L.fetching.debug("⚡️⏳ missing contact info for zap. fetching: \(zappedContact.pubkey), and queueing zap \(zap.id)")
            QueuedFetcher.shared.enqueue(pTag: zappedContact.pubkey)
            ZapperPubkeyVerificationQueue.shared.addZap(zap)
        }
        
        // Check if contact matches the zapped event contact
        if let otherPubkey = zap.otherPubkey, let zappedEvent = zap.zappedEvent {
            guard otherPubkey == zappedEvent.pubkey else {
                L.og.debug("⚡️🔴🔴 zapped contact pubkey is not the same as zapped event pubkey. zap: \(zap.id)")
                zap.flags = "zpk_mismatch_event"
                return false
            }
        }
        
        // Check if zapper pubkey matches contacts published zapper pubkey
        if let zappedContact = zap.zappedContact, let zapperPubkey = zappedContact.zapperPubkey {
            guard zap.pubkey == zapperPubkey else {
                L.og.debug("⚡️🔴🔴 zapper pubkey does not match contacts published zapper pubkey. zap: \(zap.id)")
                zap.flags = "zpk_mismatch"
                return false
            }
            zap.flags = "zpk_verified" // zapper pubkey is correct
        }
        else {
            zap.flags = "zpk_unverified" // missing contact
//            return false
        }
                
        if let zappedEvent = zap.zappedEvent {
            zappedEvent.zapTally = (zappedEvent.zapTally + Int64(zap.naiveSats))
            zappedEvent.zapsCount = (zappedEvent.zapsCount + 1)
//            zappedEvent.zapsDidChange.send((zappedEvent.zapsCount, zappedEvent.zapTally))
            ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: zappedEvent.id, zaps: zappedEvent.zapsCount, zapTally: zappedEvent.zapTally))
        }
        return true
    }
    
    // NIP-10: Those marked with "mention" denote a quoted or reposted event id.
    static func updateMentionsCountCache(_ tags:[NostrTag], context: NSManagedObjectContext) throws -> Bool {
        // NIP-10: Those marked with "mention" denote a quoted or reposted event id.
        if let mentionEtags = TagsHelpers(tags).newerMentionEtags() {
            for etag in mentionEtags {
                if let mentioningEvent = EventRelationsQueue.shared.getAwaitingBgEvent(byId: etag.id) {
                    guard !mentioningEvent.isDeleted else { continue }
                    mentioningEvent.mentionsCount = (mentioningEvent.mentionsCount + 1)
                }
                else {
                    let request = NSFetchRequest<Event>(entityName: "Event")
                    request.entity = Event.entity()
                    request.predicate = NSPredicate(format: "id == %@", etag.id)
                    request.fetchLimit = 1
                    
                    if let mentioningEvent = try context.fetch(request).first {
                        mentioningEvent.mentionsCount = (mentioningEvent.mentionsCount + 1)
                    }
                }
            }
        }
        return true
    }
    
    var fastPs: [(String, String, String?, String?, String?)] {
        fastTags.filter { $0.0 == "p" && $0.1.count == 64 }
    }
    
    var fastEs: [(String, String, String?, String?, String?)] {
        fastTags.filter { $0.0 == "e" && $0.1.count == 64 }
    }
    
    var fastTs: [(String, String, String?, String?, String?)] {
        fastTags.filter { $0.0 == "t" && !$0.1.isEmpty }
    }
    
    
    func tags() -> [NostrTag] {
        let decoder = JSONDecoder()
        
        if (tagsSerialized != nil) {
            guard let tags = try? decoder.decode([NostrTag].self, from: Data(tagsSerialized!.utf8)) else {
                return []
            }
            
            return tags
        }
        else {
            return []
        }
    }
    
    func naiveBolt11() -> String? {
        guard let tagsSerialized else { return nil }
        if let match = NostrRegexes.default.cache[.bolt11]!.firstMatch(in: tagsSerialized, range: NSRange(tagsSerialized.startIndex..., in: tagsSerialized)) {
            
            if let range = Range(match.range(at: 1), in: tagsSerialized) {
                return String(tagsSerialized[range])
            }
        }
        return nil
    }
    
    func bolt11() -> String? {
        tags().first(where: { $0.type == "bolt11" })?.tag[1]
    }
    
    func firstP() -> String? {
        tags().first(where: { $0.type == "p" })?.pubkey
    }
    
    func firstE() -> String? {
        tags().first(where: { $0.type == "e" })?.id
    }
    
    func lastE() -> String? {
        tags().last(where: { $0.type == "e" })?.id
    }
    
    func lastP() -> String? {
        tags().last(where: { $0.type == "p" })?.pubkey
    }
    
    func pTags() -> [String] {
        tags().filter { $0.type == "p" }.map { $0.pubkey }
    }
    
    func firstA() -> String? {
        tags().first(where: { $0.type == "a" })?.value
    }
    
    func firstD() -> String? {
        tags().first(where: { $0.type == "d" })?.value
    }
    
    func contactPubkeys() -> [String]? {
        let decoder = JSONDecoder()
        
        if (tagsSerialized != nil) {
            guard let tags = try? decoder.decode([NostrTag].self, from: Data(tagsSerialized!.utf8)) else {
                return nil
            }
            
            return tags.filter { $0.type == "p" && $0.pubkey.count == 64 } .map { $0.pubkey }
        }
        else {
            return nil
        }
    }
    
    static func fetchLastSeen(pubkey:String, context:NSManagedObjectContext) -> Event? {
        let request = NSFetchRequest<Event>(entityName: "Event")
        request.predicate = NSPredicate(format: "pubkey == %@", pubkey)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.created_at, ascending: false)]
        request.fetchLimit = 1
        request.fetchBatchSize = 1
        return try? context.fetch(request).first
    }
    
    static func fetchEvent(id: String, context: NSManagedObjectContext) throws -> Event? {
        if !Thread.isMainThread {
            guard Importer.shared.existingIds[id]?.status == .SAVED else { return nil }
        }
        
        if !Thread.isMainThread {
            if let eventfromCache = EventCache.shared.retrieveObject(at: id) {
                return eventfromCache
            }
        }
                
        let request = NSFetchRequest<Event>(entityName: "Event")
        //        request.entity = Event.entity()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        request.fetchBatchSize = 1
        return try context.fetch(request).first
    }
    
    static func fetchEventsBy(pubkey:String, andKind kind:Int, context:NSManagedObjectContext) -> [Event] {
        let fr = Event.fetchRequest()
        fr.sortDescriptors = [NSSortDescriptor(keyPath: \Event.created_at, ascending: false)]
        fr.predicate = NSPredicate(format: "pubkey == %@ AND kind == %d", pubkey, kind)
        return (try? context.fetch(fr)) ?? []
    }
    
    static func fetchMostRecentEventBy(pubkey:String, andOtherPubkey otherPubkey:String? = nil, andKind kind:Int, context:NSManagedObjectContext) -> Event? {
        let fr = Event.fetchRequest()
        fr.sortDescriptors = [NSSortDescriptor(keyPath: \Event.created_at, ascending: false)]
        fr.predicate = otherPubkey != nil
            ? NSPredicate(format: "pubkey == %@ AND otherPubkey == %@ AND kind == %d", pubkey, otherPubkey!, kind)
            : NSPredicate(format: "pubkey == %@ AND kind == %d", pubkey, kind)
        fr.fetchLimit = 1
        fr.fetchBatchSize = 1
        return try? context.fetch(fr).first
    }
    
    static func fetchReplacableEvent(_ kind:Int64, pubkey:String, definition:String, context:NSManagedObjectContext) -> Event? {
        let request = NSFetchRequest<Event>(entityName: "Event")
        request.predicate = NSPredicate(format: "kind == %d AND pubkey == %@ AND dTag == %@ AND mostRecentId == nil", kind, pubkey, definition)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.created_at, ascending: false)]
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    static func fetchReplacableEvent(aTag:String, context:NSManagedObjectContext) -> Event? {
        let elements = aTag.split(separator: ":")
        guard elements.count >= 3 else { return nil }
        guard let kindString = elements[safe: 0], let kind = Int64(kindString) else { return nil }
        guard let pubkey = elements[safe: 1] else { return nil }
        guard let definition = elements[safe: 2] else { return nil }
        
        return Self.fetchReplacableEvent(kind, pubkey: String(pubkey), definition: String(definition), context: context)
    }
    
    static func fetchReplacableEvent(_ kind: Int64, pubkey: String, context: NSManagedObjectContext) -> Event? {
        let request = NSFetchRequest<Event>(entityName: "Event")
        request.predicate = NSPredicate(format: "kind == %d AND pubkey == %@", kind, pubkey)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.created_at, ascending: false)]
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    static func fetchProfileBadgesByATag(_ badgeA:String, context:NSManagedObjectContext) -> [Event] {
        // find all kind 30008 where serialized tags contains
        // ["a","30009:aa77d356ac5a59dbedc78f0da17c6bdd3ae315778b5c78c40a718b5251391da6:test_badge"]
        // notify any related profile badge
        let fr = Event.fetchRequest()
        fr.sortDescriptors = [NSSortDescriptor(keyPath: \Event.created_at, ascending: false)]
        fr.predicate = NSPredicate(format: "kind == 30008 AND mostRecentId == nil AND tagsSerialized CONTAINS %@", badgeA)
        return (try? context.fetch(fr)) ?? []
    }
    
    static func fetchReplacableEvents(_ kind: Int64, pubkeys: Set<String>, context: NSManagedObjectContext) -> [Event] {
        let request = NSFetchRequest<Event>(entityName: "Event")
        request.predicate = NSPredicate(format: "kind == %d AND pubkey IN %@", kind, pubkeys)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.created_at, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }
    
    static func eventExists(id: String, context: NSManagedObjectContext) -> Bool {
        if Thread.isMainThread {
            L.og.info("☠️☠️☠️☠️ eventExists")
        }
        let request = NSFetchRequest<Event>(entityName: "Event")
        request.entity = Event.entity()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.resultType = .countResultType
        request.fetchLimit = 1
        request.includesPropertyValues = false
        
        var count = 0
        do {
            count = try context.count(for: request)
        } catch {
            L.og.error("some error in eventExists() \(error)")
            return false
        }
        
        if count > 0 {
            return true
        }
        return false
    }
    
    
    static func extractZapRequest(tags:[NostrTag]) -> NEvent? {
        let description:NostrTag? = tags.first(where: { $0.type == "description" })
        guard description?.tag[safe: 1] != nil else { return nil }
        
        let decoder = JSONDecoder()
        if let zapReqNEvent = try? decoder.decode(NEvent.self, from: description!.tag[1].data(using: .utf8, allowLossyConversion: false)!) {
            do {
                
                // Its note in note, should we verify? is this verified by relays? or zapper? should be...
                guard try (!MessageParser.shared.isSignatureVerificationEnabled) || (zapReqNEvent.verified()) else { return nil }
                
                return zapReqNEvent
            }
            catch {
                L.og.error("extractZapRequest \(error)")
                return nil
            }
        }
        return nil
    }
    
    static func saveZapRequest(event:NEvent, context:NSManagedObjectContext) -> Event? {
        if let existingZapReq = try? Event.fetchEvent(id: event.id, context: context) {
            return existingZapReq
        }
        
        // CREATE ZAP REQUEST EVENT
        let zapRequest = Event(context: context)
        zapRequest.insertedAt = Date.now
        
        zapRequest.id = event.id
        zapRequest.kind = Int64(event.kind.id)
        zapRequest.created_at = Int64(event.createdAt.timestamp)
        zapRequest.content = event.content
        zapRequest.sig = event.signature
        zapRequest.pubkey = event.publicKey
        zapRequest.likesCount = 0
        
        
        // set relation to Contact
        zapRequest.contact = Contact.fetchByPubkey(event.publicKey, context: context)
        
        zapRequest.tagsSerialized = TagSerializer.shared.encode(tags: event.tags)
        
        return zapRequest
    }
    
    // TODO: 115.00 ms    1.0%    0 s          closure #1 in static Event.updateRelays(_:relays:)
    static func updateRelays(_ id: String, relays: String, context: NSManagedObjectContext) {
        #if DEBUG
            if Thread.isMainThread && ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                fatalError("Should only be called from bg()")
            }
        #endif
        if let event = EventRelationsQueue.shared.getAwaitingBgEvent(byId: id) {
            guard !event.isDeleted else { return }
            let existingRelays = event.relays.split(separator: " ").map { String($0) }
            let newRelays = relays.split(separator: " ").map { String($0) }
            let uniqueRelays = Set(existingRelays + newRelays)
            if uniqueRelays.count > existingRelays.count {
                event.relays = uniqueRelays.joined(separator: " ")
//                    event.relaysUpdated.send(event.relays)
                ViewUpdates.shared.eventStatChanged.send(EventStatChange(
                    id: event.id,
                    relaysCount: event.relays.split(separator: " ").count,
                    relays: event.relays
                ))
                do {
                    try context.save()
                }
                catch {
                    L.og.error("🔴🔴 error updateRelays \(error)")
                }
            }
        }
        else if let event = try? Event.fetchEvent(id: id, context: context) {
            guard !event.isDeleted else { return }
            let existingRelays = event.relays.split(separator: " ").map { String($0) }
            let newRelays = relays.split(separator: " ").map { String($0) }
            let uniqueRelays = Set(existingRelays + newRelays)
            if uniqueRelays.count > existingRelays.count {
                event.relays = uniqueRelays.joined(separator: " ")
                ViewUpdates.shared.eventStatChanged.send(EventStatChange(
                    id: event.id,
                    relaysCount: event.relays.split(separator: " ").count,
                    relays: event.relays
                ))
                do {
                    try context.save()
                }
                catch {
                    L.og.error("🔴🔴 error updateRelays \(error)")
                }
            }
        }
    }
    
    // TODO: .saveEvent() and .importEvents() needs a refactor, to cleanly handle each kind in a reusable/maintainable way, this long list of if statements is becoming a mess.
    static func saveEvent(event: NEvent, relays: String? = nil, flags: String = "", kind6firstQuote: Event? = nil, context: NSManagedObjectContext) -> Event {
        #if DEBUG
            if Thread.isMainThread && ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                fatalError("Should only be called from bg()")
            }
        #endif
        
        let savedEvent = Event(context: context)
        savedEvent.insertedAt = Date.now
        savedEvent.id = event.id
        savedEvent.kind = Int64(event.kind.id)
        savedEvent.created_at = Int64(event.createdAt.timestamp)
        savedEvent.content = event.content
        savedEvent.sig = event.signature
        savedEvent.pubkey = event.publicKey
        savedEvent.likesCount = 0
        savedEvent.isRepost = event.kind == .repost
        savedEvent.flags = flags
        if let contact = EventRelationsQueue.shared.getAwaitingBgContacts().first(where: { $0.pubkey == event.publicKey }) {
            savedEvent.contact = contact
        }
        else {
            // 100.00 ms    0.6%    0 s                     static Contact.fetchByPubkey(_:context:)
            savedEvent.contact = Contact.fetchByPubkey(event.publicKey, context: context)
        }
        savedEvent.tagsSerialized = TagSerializer.shared.encode(tags: event.tags) // TODO: why encode again, need to just store what we received before (performance)
        
        if let relays = relays?.split(separator: " ").map({ String($0) }) {
            let uniqueRelays = Set(relays)
            savedEvent.relays = uniqueRelays.joined(separator: " ")
        }
        updateEventCache(event.id, status: .SAVED, relays: relays)
        
        if event.kind == .profileBadges {
            savedEvent.contact?.objectWillChange.send()
        }
        
        //        if event.kind == .badgeAward {
        //            // find and notify all kind 30008 where serialized tags contains
        //            // ["a","30009:aa77d356ac5a59dbedc78f0da17c6bdd3ae315778b5c78c40a718b5251391da6:test_badge"]
        //            // notify any related profile badge
        //            let profileBadges = Event.fetchProfileBadgesByATag(event.badgeA, context:context)
        //            for pb in profileBadges {
        //                pb.objectWillChange.send()
        //            }
        ////            sendNotification(.badgeAwardFetched)
        //        }
        if event.kind == .badgeDefinition {
            // notify any related profile badge
            savedEvent.contact?.objectWillChange.send()
            let profileBadges = Event.fetchProfileBadgesByATag(event.badgeA, context:context)
            for pb in profileBadges {
                pb.objectWillChange.send()
            }
            //            sendNotification(.badgeDefinitionFetched)
        }
        
        if event.kind == .community {
            saveCommunityDefinition(savedEvent: savedEvent, nEvent: event)
        }
        
        if event.kind == .zapNote {
            // save 9734 seperate
            // so later we can do --> event(9735).zappedEvent(9734).contact
            let nZapRequest = Event.extractZapRequest(tags: event.tags)
            if (nZapRequest != nil) {
                let zapRequest = Event.saveZapRequest(event: nZapRequest!, context: context)
                
                savedEvent.zapFromRequest = zapRequest
                if let firstE = event.firstE() {
                    savedEvent.zappedEventId = firstE
                    
                    if let awaitingEvent = EventRelationsQueue.shared.getAwaitingBgEvent(byId: firstE) {
                        savedEvent.zappedEvent = awaitingEvent // Thread 3273: "Illegal attempt to establish a relationship 'zappedEvent' between objects in different contexts
                        // _PFManagedObject_coerceValueForKeyWithDescription
                        // _sharedIMPL_setvfk_core
                        // TODO: Maybe wrong main context event added somewhere?
                    }
                    else {
                        context.perform { // set relation on next .perform to fix context crash?
                            savedEvent.zappedEvent = try? Event.fetchEvent(id: firstE, context: context)
                        }
                    }
                    if let zapRequest, zapRequest.pubkey == NRState.shared.activeAccountPublicKey {
                        context.perform { // we don't have .zappedEvent yet without .perform { } .. see few lines above
                            savedEvent.zappedEvent?.zapState = .zapReceiptConfirmed
                        }
                        ViewUpdates.shared.zapStateChanged.send(ZapStateChange(pubkey: savedEvent.pubkey, eTag: savedEvent.zappedEventId, zapState: .zapReceiptConfirmed))
                    }
                }
                if let firstP = event.firstP() {
//                    savedEvent.objectWillChange.send()
                    savedEvent.otherPubkey = firstP
                    savedEvent.zappedContact = Contact.fetchByPubkey(firstP, context: context)
                }
            }
            
            // bolt11 -- replaced with naiveBolt11Decoder
            //            if let bolt11 = event.bolt11() {
            //                let invoice = Invoice.fromStr(s: bolt11)
            //                if let parsedInvoice = invoice.getValue() {
            //                    savedEvent.cachedSats = Double((parsedInvoice.amountMilliSatoshis() ?? 0) / 1000)
            //                }
            //            }
        }
        
        if event.kind == .reaction {
            if let lastE = event.lastE() {
                savedEvent.reactionToId = lastE
                // Thread 927: "Illegal attempt to establish a relationship 'reactionTo' between objects in different contexts
                // here savedEvent is not saved yet, so appears it can crash on context, even when its the same context
                context.perform { // so we save on next .perform?
                    savedEvent.reactionTo = try? Event.fetchEvent(id: lastE, context: context)
                    if let otherPubkey =  savedEvent.reactionTo?.pubkey {
                        savedEvent.otherPubkey = otherPubkey
                    }
                    if savedEvent.otherPubkey == nil, let lastP = event.lastP() {
                        savedEvent.otherPubkey = lastP
                    }
                }
            }
        }
        
        if (event.kind == .textNote) {
            
            EventCache.shared.setObject(for: event.id, value: savedEvent)
            L.og.debug("Saved \(event.id) in cache")
            
            if event.content == "#[0]", let firstE = event.firstE() {
                savedEvent.isRepost = true
                
                savedEvent.firstQuoteId = firstE
                savedEvent.firstQuote = kind6firstQuote // got it passed in as parameter on saveEvent() already.
                
                if savedEvent.firstQuote == nil { // or we fetch it if we dont have it yet
                    // IF WE ALREADY HAVE THE FIRST QUOTE, ADD OUR NEW EVENT + UPDATE REPOST COUNT
                    if let repostedEvent = EventRelationsQueue.shared.getAwaitingBgEvent(byId: firstE) {
                        savedEvent.firstQuote = repostedEvent
                        repostedEvent.repostsCount = (repostedEvent.repostsCount + 1)
//                        repostedEvent.repostsDidChange.send(repostedEvent.repostsCount)
                        ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: repostedEvent.id, reposts: repostedEvent.repostsCount))
                    }
                    else if let repostedEvent = try? Event.fetchEvent(id: savedEvent.firstQuoteId!, context: context) {
                        savedEvent.firstQuote = repostedEvent
                        repostedEvent.repostsCount += 1
//                        repostedEvent.repostsDidChange.send(repostedEvent.repostsCount)
                        ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: repostedEvent.id, reposts: repostedEvent.repostsCount))
                    }
                }
                
                // Also save reposted pubkey in .otherPubkey for easy querying for repost notifications
                // if we already have the firstQuote (reposted post), we use that .pubkey
                if let otherPubkey = savedEvent.firstQuote?.pubkey {
                    savedEvent.otherPubkey = otherPubkey
                } // else we take the pubkey from the tags (should be there)
                else if let firstP = event.firstP() {
                    savedEvent.otherPubkey = firstP
                }
            }
            
            if let replyToAtag = event.replyToAtag() { // Comment on article
                if let dbArticle = Event.fetchReplacableEvent(aTag: replyToAtag.value, context: context) {
                    savedEvent.replyToId = dbArticle.id
                    savedEvent.replyTo = dbArticle
                    
                    dbArticle.addToReplies(savedEvent)
                    dbArticle.repliesCount += 1
//                    dbArticle.repliesUpdated.send(dbArticle.replies_)
                    ViewUpdates.shared.repliesUpdated.send(EventRepliesChange(id: dbArticle.id, replies: dbArticle.replies_))
                    ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: dbArticle.id, replies: dbArticle.repliesCount))
                }
                else {
                    // we don't have the article yet, store aTag in replyToId
                    savedEvent.replyToId = replyToAtag.value
                }
            }
            else if let replyToRootAtag = event.replyToRootAtag() {
                // Comment has article as root, but replying to other comment, not to article.
                if let dbArticle = Event.fetchReplacableEvent(aTag: replyToRootAtag.value, context: context) {
                    savedEvent.replyToRootId = dbArticle.id
                    savedEvent.replyToRoot = dbArticle
                }
                else {
                    // we don't have the article yet, store aTag in replyToRootId
                    savedEvent.replyToRootId = replyToRootAtag.value
                }
                
                // if there is no replyTo (e or a) then the replyToRoot is the replyTo
                // but check first if we maybe have replyTo from e tags
            }
             
            // Original replyTo/replyToRoot handling, don't overwrite aTag handling
                
            // THIS EVENT REPLYING TO SOMETHING
            // CACHE THE REPLY "E" IN replyToId
            if let replyToEtag = event.replyToEtag(), savedEvent.replyToId == nil {
                savedEvent.replyToId = replyToEtag.id
                
                // IF WE ALREADY HAVE THE PARENT, ADD OUR NEW EVENT IN THE REPLIES
                if let parent = EventRelationsQueue.shared.getAwaitingBgEvent(byId: replyToEtag.id) ?? (try? Event.fetchEvent(id: replyToEtag.id, context: context)) {
                    savedEvent.replyTo = parent
                    parent.addToReplies(savedEvent)
                    parent.repliesCount += 1
//                    replyTo.repliesUpdated.send(replyTo.replies_)
                    ViewUpdates.shared.repliesUpdated.send(EventRepliesChange(id: parent.id, replies: parent.replies_))
                    ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: parent.id, replies: parent.repliesCount))
                }
            }
            
            // IF THE THERE IS A ROOT, AND ITS NOT THE SAME AS THE REPLY TO. AND ROOT IS NOT ALREADY SET FROM ROOTATAG
            // DO THE SAME AS WITH THE REPLY BEFORE
            if let replyToRootEtag = event.replyToRootEtag(), savedEvent.replyToRootId == nil {
                savedEvent.replyToRootId = replyToRootEtag.id
                // Need to put it in queue to fix relations for replies to root / grouped replies
                //                EventRelationsQueue.shared.addAwaitingEvent(savedEvent, debugInfo: "saveEvent.123")
                
                if (savedEvent.replyToId == nil) {
                    savedEvent.replyToId = savedEvent.replyToRootId // NO REPLYTO, SO REPLYTOROOT IS THE REPLYTO
                }
                if let root = EventRelationsQueue.shared.getAwaitingBgEvent(byId: replyToRootEtag.id) ?? (try? Event.fetchEvent(id: replyToRootEtag.id, context: context)), !root.isDeleted {
                    savedEvent.replyToRoot = root
                    
                    ViewUpdates.shared.eventRelationUpdate.send(EventRelationUpdate(relationType: .replyToRoot, id: savedEvent.id, event: root))
                    ViewUpdates.shared.eventRelationUpdate.send(EventRelationUpdate(relationType: .replyToRootInverse, id:  root.id, event: savedEvent))
                    if (savedEvent.replyToId == savedEvent.replyToRootId) {
                        savedEvent.replyTo = root // NO REPLYTO, SO REPLYTOROOT IS THE REPLYTO
                        root.addToReplies(savedEvent)
                        root.repliesCount += 1
                        ViewUpdates.shared.repliesUpdated.send(EventRepliesChange(id: root.id, replies: root.replies_))
                        ViewUpdates.shared.eventRelationUpdate.send(EventRelationUpdate(relationType: .replyTo, id: savedEvent.id, event: root))
                        ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: root.id, replies: root.repliesCount))
                    }
                }
            }
            
            // Finally, we have a reply to root set from aTag, but we still don't have a replyTo
            else if savedEvent.replyToRootId != nil, savedEvent.replyToId == nil {
                // so set replyToRoot (aTag) as replyTo
                savedEvent.replyToId = savedEvent.replyToRootId
                savedEvent.replyTo = savedEvent.replyToRoot
                
                if let parent = savedEvent.replyTo {
                    parent.addToReplies(savedEvent)
                    parent.repliesCount += 1
//                    replyTo.repliesUpdated.send(replyTo.replies_)
                    ViewUpdates.shared.repliesUpdated.send(EventRepliesChange(id: parent.id, replies: parent.replies_))
                    ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: parent.id, replies: parent.repliesCount))
                }
            }
            
        }
        
        if (event.kind == .directMessage) { // needed to fetch contact in DMS: so event.firstP is in event.contacts
            savedEvent.otherPubkey = event.firstP()
            
            if let contactPubkey = savedEvent.otherPubkey { // If we have a DM kind 4, but no p, then something is wrong
                if let dmState = CloudDMState.fetchExisting(event.publicKey, contactPubkey: contactPubkey, context: context) {
                    
                    // if we already track the conversation, consider accepted if we replied to the DM
                    // DM is sent from one of our current logged in pubkey
                    if !dmState.accepted && NRState.shared.accountPubkeys.contains(event.publicKey) {
                        dmState.accepted = true
                        
                        if let current = dmState.markedReadAt_, savedEvent.date > current {
                            dmState.markedReadAt_ = savedEvent.date
                        }
                        else if dmState.markedReadAt_ == nil {
                            dmState.markedReadAt_ = savedEvent.date
                        }
                    }
                    // Let DirectMessageViewModel handle view updates
                    DirectMessageViewModel.default.newMessage(dmState)
                    DirectMessageViewModel.default.checkNeedsNotification(savedEvent)
                }
                // Same but account / contact switched, because we support multiple accounts so we need to be able to track both ways
                else if let dmState = CloudDMState.fetchExisting(contactPubkey, contactPubkey: event.publicKey, context: context) {
                    
                    // if we already track the conversation, consider accepted if we replied to the DM
                    if !dmState.accepted && NRState.shared.accountPubkeys.contains(event.publicKey) {
                        dmState.accepted = true
                    }
                    // Let DirectMessageViewModel handle view updates
                    DirectMessageViewModel.default.newMessage(dmState)
                    DirectMessageViewModel.default.checkNeedsNotification(savedEvent)
                }
                else {
                    // if we are sender with full account
                    if NRState.shared.fullAccountPubkeys.contains(event.publicKey) {
                        let dmState = CloudDMState(context: context)
                        dmState.accountPubkey_ = event.publicKey
                        dmState.contactPubkey_ = contactPubkey
                        dmState.accepted = true
                        dmState.markedReadAt_ = savedEvent.date
                        // Let DirectMessageViewModel handle view updates
                        DirectMessageViewModel.default.newMessage(dmState)
                        DirectMessageViewModel.default.checkNeedsNotification(savedEvent)
                    }
                    
                    // if we are receiver with full account
                    else if NRState.shared.fullAccountPubkeys.contains(contactPubkey) {
                        let dmState = CloudDMState(context: context)
                        dmState.accountPubkey_ = contactPubkey
                        dmState.contactPubkey_ = event.publicKey
                        dmState.accepted = false
                        // Let DirectMessageViewModel handle view updates
                        DirectMessageViewModel.default.newMessage(dmState)
                        DirectMessageViewModel.default.checkNeedsNotification(savedEvent)
                    }
                    
                    // if we are sender with read only account
                    else if NRState.shared.accountPubkeys.contains(event.publicKey) {
                        let dmState = CloudDMState(context: context)
                        dmState.accountPubkey_ = event.publicKey
                        dmState.contactPubkey_ = contactPubkey
                        dmState.accepted = true
                        dmState.markedReadAt_ = savedEvent.date
                        // Let DirectMessageViewModel handle view updates
                        DirectMessageViewModel.default.newMessage(dmState)
                        DirectMessageViewModel.default.checkNeedsNotification(savedEvent)
                    }
                    
                    // if we are receiver with read only account
                    else if NRState.shared.accountPubkeys.contains(contactPubkey) {
                        let dmState = CloudDMState(context: context)
                        dmState.accountPubkey_ = contactPubkey
                        dmState.contactPubkey_ = event.publicKey
                        dmState.accepted = false
                        // Let DirectMessageViewModel handle view updates
                        DirectMessageViewModel.default.newMessage(dmState)
                        DirectMessageViewModel.default.checkNeedsNotification(savedEvent)
                    }
                }
            }
        }
        
        // handle REPOST with normal mentions in .kind 1
        // TODO: handle first nostr:nevent or not?
        var alreadyCounted = false
        if event.kind == .textNote, let firstE = event.firstMentionETag(), let replyToId = savedEvent.replyToId, firstE.id != replyToId { // also fQ not the same as replyToId
            savedEvent.firstQuoteId = firstE.id
            
            // IF WE ALREADY HAVE THE FIRST QUOTE, ADD OUR NEW EVENT IN THE MENTIONS
            if let firstQuote = try? Event.fetchEvent(id: savedEvent.firstQuoteId!, context: context) {
                savedEvent.firstQuote = firstQuote
                
                if (firstE.tag[safe: 3] == "mention") {
//                    firstQuote.objectWillChange.send()
                    firstQuote.mentionsCount += 1
                    alreadyCounted = true
                }
            }
        }
        
        // hmm above firstQuote doesn't seem to handle #[0] at .content end and "e" without "mention as first tag, so special case?
        if !alreadyCounted && event.kind == .textNote && event.content.contains("#[0]"), let firstE = event.firstMentionETag() {
            savedEvent.firstQuoteId = firstE.id
            
            // IF WE ALREADY HAVE THE FIRST QUOTE, ADD OUR NEW EVENT IN THE MENTIONS
            if let firstQuote = try? Event.fetchEvent(id: savedEvent.firstQuoteId!, context: context) {
                savedEvent.firstQuote = firstQuote
                
//                firstQuote.objectWillChange.send()
                firstQuote.mentionsCount += 1
            }
        }
        
        // kind6 - repost, the reposted post is put in as .firstQuote
        if event.kind == .repost {
            savedEvent.firstQuoteId = kind6firstQuote?.id ?? event.firstE()
            savedEvent.firstQuote = kind6firstQuote // got it passed in as parameter on saveEvent() already.
            
            if let repostedEvent = savedEvent.firstQuote { // we already got firstQuote passed in as param
                repostedEvent.repostsCount = (repostedEvent.repostsCount + 1)
//                repostedEvent.repostsDidChange.send(repostedEvent.repostsCount)
                ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: repostedEvent.id, reposts: repostedEvent.repostsCount))
            }
            else {
                // We need to get firstQuote from db or cache
                if let firstE = event.firstE() {
                    if let repostedEvent = EventRelationsQueue.shared.getAwaitingBgEvent(byId: firstE) {
                        savedEvent.firstQuote = repostedEvent // "Illegal attempt to establish a relationship 'firstQuote' between objects in different contexts 
                        repostedEvent.repostsCount = (repostedEvent.repostsCount + 1)
//                        repostedEvent.repostsDidChange.send(repostedEvent.repostsCount)
                        ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: repostedEvent.id, reposts: repostedEvent.repostsCount))
                    }
                    else if let repostedEvent = try? Event.fetchEvent(id: firstE, context: context) {
                        savedEvent.firstQuote = repostedEvent
                        repostedEvent.repostsCount = (repostedEvent.repostsCount + 1)
//                        repostedEvent.repostsDidChange.send(repostedEvent.repostsCount)
                        ViewUpdates.shared.eventStatChanged.send(EventStatChange(id: repostedEvent.id, reposts: repostedEvent.repostsCount))
                    }
                }
            }
            
            // Also save reposted pubkey in .otherPubkey for easy querying for repost notifications
            // if we already have the firstQuote (reposted post), we use that .pubkey
            if let otherPubkey = savedEvent.firstQuote?.pubkey {
                savedEvent.otherPubkey = otherPubkey
            } // else we take the pubkey from the tags (should be there)
            else if let firstP = event.firstP() {
                savedEvent.otherPubkey = firstP
            }
        }
        
        if (event.kind == .contactList) {
            // delete older events
            let r = NSFetchRequest<NSFetchRequestResult>(entityName: "Event")
            r.predicate = NSPredicate(format: "kind == 3 AND pubkey == %@ AND created_at < %d", event.publicKey, savedEvent.created_at)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: r)
            batchDelete.resultType = .resultTypeCount
            
            do {
                _ = try context.execute(batchDelete) as! NSBatchDeleteResult
            } catch {
                L.og.error("🔴🔴 Failed to delete older kind 3 events")
            }
        }
        
        if (event.kind == .relayList) {
            // delete older events
            let r = NSFetchRequest<NSFetchRequestResult>(entityName: "Event")
            r.predicate = NSPredicate(format: "kind == 10002 AND pubkey == %@ AND created_at < %d", event.publicKey, savedEvent.created_at)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: r)
            batchDelete.resultType = .resultTypeCount
            
            do {
                _ = try context.execute(batchDelete) as! NSBatchDeleteResult
            } catch {
                L.og.error("🔴🔴 Failed to delete older kind 10002 events")
            }
        }
        
        if event.kind == .delete {
            let eventIdsToDelete = event.eTags()
            
            let eventIdsToDeleteReq = NSFetchRequest<Event>(entityName: "Event")
            eventIdsToDeleteReq.predicate = NSPredicate(format: "kind IN {1,6,9802,30023,34235} AND id IN %@", eventIdsToDelete)
            eventIdsToDeleteReq.sortDescriptors = []
            if let eventsToDelete = try? context.fetch(eventIdsToDeleteReq) {
                for d in eventsToDelete {
                    if (d.pubkey == event.publicKey) {
//                        d.objectWillChange.send()
                        d.deletedById = event.id
                        ViewUpdates.shared.postDeleted.send((d.id, event.id))
                    }
                }
            }
        }
        
        // Handle replacable event (NIP-33)
        if (event.kind.id >= 30000 && event.kind.id < 40000) {
            savedEvent.dTag = event.tags.first(where: { $0.type == "d" })?.value ?? ""
            // update older events:
            // 1. set pointer to most recent (this one)
            // 2. set "is_update" flag on this one so it doesn't show up as new in feed
            let r = Event.fetchRequest()
            r.predicate = NSPredicate(format: "dTag == %@ AND kind == %d AND pubkey == %@ AND created_at < %d", savedEvent.dTag, savedEvent.kind, event.publicKey, savedEvent.created_at)
            
            
            var existingArticleIds = Set<String>() // need to repoint all replies to older articles to the newest id
            
            if let olderEvents = try? context.fetch(r) {
                for olderEvent in olderEvents {
                    olderEvent.mostRecentId = savedEvent.id
                    existingArticleIds.insert(olderEvent.id)
                }
                
                if olderEvents.count > 0 {
                    savedEvent.flags = "is_update"
                }
            }
            
            // Find existing events referencing this event (can only be replyToRootId = "3XXXX:pubkey:dTag", or replyToRootId = "<older article ids>")
            // or same but for replyToId
            existingArticleIds.insert(savedEvent.aTag)
            let fr = Event.fetchRequest()
            fr.predicate = NSPredicate(format: "replyToRootId IN %@", existingArticleIds)
            if let existingReplies = try? context.fetch(fr) {
                for existingReply in existingReplies {
                    existingReply.replyToRootId = savedEvent.id
                    existingReply.replyToRoot = savedEvent
                }
            }
            
            let fr2 = Event.fetchRequest()
            fr2.predicate = NSPredicate(format: "replyToId IN %@", existingArticleIds)
            if let existingReplies = try? context.fetch(fr) {
                for existingReply in existingReplies {
                    existingReply.replyToId = savedEvent.id
                    existingReply.replyTo = savedEvent
                }
            }
            
        }
        
        
        
        
        
        // Use new EventRelationsQueue to fix relations
        if (event.kind == .textNote) {
            
            let awaitingEvents = EventRelationsQueue.shared.getAwaitingBgEvents()
            
            for waitingEvent in awaitingEvents {
                if (waitingEvent.replyToId != nil) && (waitingEvent.replyToId == savedEvent.id) {
                    waitingEvent.replyTo = savedEvent
//                    waitingEvent.replyToUpdated.send(savedEvent)
                    ViewUpdates.shared.eventRelationUpdate.send((EventRelationUpdate(relationType: .replyTo, id: waitingEvent.id, event: savedEvent)))
                }
                if (waitingEvent.replyToRootId != nil) && (waitingEvent.replyToRootId == savedEvent.id) {
                    waitingEvent.replyToRoot = savedEvent
//                    waitingEvent.replyToRootUpdated.send(savedEvent)
                    ViewUpdates.shared.eventRelationUpdate.send((EventRelationUpdate(relationType: .replyToRoot, id: waitingEvent.id, event: savedEvent)))
                    ViewUpdates.shared.eventRelationUpdate.send((EventRelationUpdate(relationType: .replyToRootInverse, id: savedEvent.id, event: waitingEvent)))
                }
                if (waitingEvent.firstQuoteId != nil) && (waitingEvent.firstQuoteId == savedEvent.id) {
                    waitingEvent.firstQuote = savedEvent
//                    waitingEvent.firstQuoteUpdated.send(savedEvent)
                    ViewUpdates.shared.eventRelationUpdate.send((EventRelationUpdate(relationType: .firstQuote, id: waitingEvent.id, event: savedEvent)))
                }
            }
        }
        
        
        return savedEvent
    }
    
    func toNEvent() -> NEvent {
        var nEvent = NEvent(content: content ?? "")
        nEvent.id = id
        nEvent.publicKey = pubkey
        nEvent.createdAt = NTimestamp(timestamp: Int(created_at))
        nEvent.kind = NEventKind(id: Int(kind))
        nEvent.tags = tags()
        nEvent.signature = sig ?? ""
        return nEvent
    }
    
    func getMetadataContent() throws -> NSetMetadata? {
        if kind != NEventKind.setMetadata.id {
            throw "Event is not kind 0"
        }
        let decoder = JSONDecoder()
        
        if (content != nil) {
            guard let setMetadata = try? decoder.decode(NSetMetadata.self, from: Data(content!.utf8)) else {
                return nil
            }
            
            return setMetadata
        }
        else {
            return nil
        }
    }
    
    static func zapsForEvent(_ id:String, context:NSManagedObjectContext) -> [Event] {
        let fr = Event.fetchRequest()
        fr.sortDescriptors = [NSSortDescriptor(keyPath: \Event.created_at, ascending: false)]
        fr.predicate = NSPredicate(format: "zappedEventId == %@ AND kind == 9735", id)
        
        return (try? context.fetch(fr)) ?? []
    }
}


extension DataProvider {
    func fetchEvent(id:String, context:NSManagedObjectContext? = nil) throws -> Event? {
        let request = NSFetchRequest<Event>(entityName: "Event")
        request.entity = Event.entity()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        request.fetchBatchSize = 1
        return try (context ?? viewContext).fetch(request).first
    }
}
