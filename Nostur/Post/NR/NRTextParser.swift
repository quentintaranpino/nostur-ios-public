//
//  NRTextBuilder.swift
//  Nostur
//
//  Created by Fabian Lachman on 12/05/2023.
//

import Foundation
import MarkdownUI
import SwiftUI

// Renders links for the text parts of post contents (in TEXT)
// Handles profile links
// Tag links
// Other links
// DOES NOT handle note links or image links, because those are embeds, handled by ContentRenderer
class NRTextParser { // TEXT things
    static let shared = NRTextParser()
    private let context = bg()
    
    private init() { }

    func parseText(_ event: Event, text: String, availableWidth: CGFloat? = nil, primaryColor: Color? = nil) -> AttributedStringWithPs {
        let fontColor = primaryColor ?? Themes.default.theme.primary
        let availableWidth = availableWidth ??  DIMENSIONS.shared.availableNoteRowImageWidth()

        // Remove image links + Handle naddr1...
        // because they get rendered as embeds in PostDetail.
        // and NoteRow shows them in ImageViewer
        var newText = Self.replaceNaddrWithMarkdownLinks(
            in: self.removeImageLinks(
                event: event,
                text: text
            )
        )

        // Handle #hashtags
        newText = Self.replaceHashtagsWithMarkdownLinks(in: newText)

        // NIP-08, handle #[0] #[1] etc
        let textWithPs = parseTagIndexedMentions(event: event, text: newText)

        // NIP-28 handle nostr:npub1, nostr:nprofile ...
        var newerTextWithPs = parseUserMentions(event: event, text: textWithPs.text)
        if newerTextWithPs.text.suffix(1) == "\n" {
            newerTextWithPs.text = String(newerTextWithPs.text.dropLast(1))
        }

        do {
            let mutableAttributedString = try NSMutableAttributedString(markdown: newerTextWithPs.text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            let attributes:[NSAttributedString.Key: NSObject] = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor(fontColor)
            ]
            
            mutableAttributedString.addAttributes(
                attributes,
                range: NSRange(location: 0, length: mutableAttributedString.length)
            )
            
            mutableAttributedString.addHashtagIcons()
            
            let height = mutableAttributedString.boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).height
            
            let a = AttributedStringWithPs(input:text, output: NSAttributedString(attributedString: mutableAttributedString), pTags: textWithPs.pTags + newerTextWithPs.pTags, event:event, height: height)
            
            return a
        }
        catch {
            let mutableAttributedString = NSMutableAttributedString(string: newerTextWithPs.text)
            let attributes:[NSAttributedString.Key: NSObject] = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor(fontColor)
            ]
            
            mutableAttributedString.addAttributes(
                attributes,
                range: NSRange(location: 0, length: mutableAttributedString.length)
            )
            
            mutableAttributedString.addHashtagIcons()
            
            let height = mutableAttributedString.boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).height
            
            L.og.error("NRTextParser: \(error)")
            let a = AttributedStringWithPs(input:text, output: NSAttributedString(attributedString: mutableAttributedString), pTags: textWithPs.pTags + newerTextWithPs.pTags, event:event, height: height)
            return a
        }
    }
    
    func parseMD(_ event:Event, text: String) -> MarkdownContentWithPs {

        // 1) Replace naddr
        // 2) NIP-08, handle #[0] #[1] etc
        let textWithPs = parseTagIndexedMentions(
            event: event,
            text:  Self.replaceNaddrWithMarkdownLinks(in: text)
        )

        // NIP-28 handle nostr:npub1, nostr:nprofile ...
        var newerTextWithPs = parseUserMentions(event: event, text: textWithPs.text)
        if newerTextWithPs.text.suffix(1) == "\n" {
            newerTextWithPs.text = String(newerTextWithPs.text.dropLast(1))
        }

        newerTextWithPs.text = Self.replaceHashtagsWithMarkdownLinks(in: newerTextWithPs.text)
//        print(newerTextWithPs.text)
        let finalText = MarkdownContent(newerTextWithPs.text)
        
//        print(finalText)
        
        let a = MarkdownContentWithPs(input:text, output: finalText, pTags: textWithPs.pTags + newerTextWithPs.pTags, event:event)
        return a
    }

    func copyPasteText(_ event:Event, text: String) -> TextWithPs {
        // NIP-08, handle #[0] #[1] etc
        let textWithPs = parseTagIndexedMentions(event: event, text: text, plainText: true)

        // NIP-28 handle nostr:npub1, nostr:nprofile ...
        let newerTextWithPs = parseUserMentions(event: event, text: textWithPs.text, plainText: true)

        return TextWithPs(text: newerTextWithPs.text, pTags: textWithPs.pTags + newerTextWithPs.pTags)
    }

    // NIP-08 (deprecated in favor of NIP-27)
    private func parseTagIndexedMentions(event: Event, text: String, plainText: Bool = false) -> TextWithPs {
        guard !event.fastTags.isEmpty else { return TextWithPs(text: text, pTags: []) }

        var pTags = [Ptag]()
        var newText = text

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = NEvent.indexedMentionRegex15.matches(in: text, options: [], range: nsRange)

        for match in matches.prefix(100).reversed() { // 100 limit for sanity
            let range = match.range(at: 1)
            guard let swiftRange = Range(range, in: text),
                  let tagIndex = Int(text[swiftRange]),
                  tagIndex < event.fastTags.count else {
                continue
            }
            
            let tag = event.fastTags[tagIndex]

            if tag.0 == "p" {
                pTags.append(tag.1)
                let replacementString = !plainText ?
                    "[@\(contactUsername(fromPubkey: tag.1, event: event).escapeMD())](nostur:p:\(tag.1))" :
                    "@\(contactUsername(fromPubkey: tag.1, event: event))"
                let entireMatchRange = match.range(at: 0)
                if let entireSwiftRange = Range(entireMatchRange, in: newText) {
                    newText = newText.replacingOccurrences(of: String(newText[entireSwiftRange]), with: replacementString)
                }
            } else if tag.0 == "e" {
                let key = try! NIP19(prefix: "note1", hexString: tag.1)
                let replacementString = !plainText ?
                    "[@\(String(key.displayString).prefix(11))](nostur:e:\(tag.1))" :
                    "@\(String(key.displayString).prefix(11))"
                let entireMatchRange = match.range(at: 0)
                if let entireSwiftRange = Range(entireMatchRange, in: newText) {
                    newText = newText.replacingOccurrences(of: String(newText[entireSwiftRange]), with: replacementString)
                }
            }
        }
        
        return TextWithPs(text: newText, pTags: pTags)
    }

    
    // Cached regex
    static let npubNprofRegex = try! NSRegularExpression(pattern: "nostr:npub1[023456789acdefghjklmnpqrstuvwxyz]{58}|(nostr:nprofile1[023456789acdefghjklmnpqrstuvwxyz]+)\\b", options: [])
    
    // NIP-27 handle nostr:npub or nostr:nprofile
    private func parseUserMentions(event: Event, text: String, plainText: Bool = false) -> TextWithPs {
        var replacedString = text
        let nsRange = NSRange(replacedString.startIndex..<replacedString.endIndex, in: text)
        var pTags = [Ptag]()

        var sanityIndex = 0
        for match in Self.npubNprofRegex.matches(in: replacedString, range: nsRange).reversed() {
            if sanityIndex > 200 { break }
            sanityIndex += 1
            var replacement = (replacedString as NSString).substring(with: match.range)
            
            let pub1OrProfile1 = replacement.prefix(11) == "nostr:npub1"
                ? "npub1"
                : "nprofile1"
            
            switch pub1OrProfile1 {
                case "npub1":
                    let npub = replacement.replacingOccurrences(of: "nostr:", with: "")
                    do {
                        let pubkey = try toPubkey(npub)
                        pTags.append(pubkey)
                        if !plainText {
                            replacement = "[@\(contactUsername(fromPubkey: pubkey, event: event).escapeMD())](nostur:p:\(pubkey))"
                        }
                        else {
                            replacement = "" + contactUsername(fromPubkey: pubkey, event: event)
                        }
                    }
                    catch {
                        L.og.debug("problem decoding npub")
                    }
                case "nprofile1":
                let nprofile = replacement.replacingOccurrences(of: "nostr:", with: "")
                    do {
                        let identifier = try ShareableIdentifier(nprofile)
                        if let pubkey = identifier.pubkey {
                            pTags.append(pubkey)
                            if !plainText {
                                replacement = "[@\(contactUsername(fromPubkey: pubkey, event: event).escapeMD())](nostur:p:\(pubkey))"
                            }
                            else {
                                replacement = "" + contactUsername(fromPubkey: pubkey, event: event)
                            }
                        }
                    }
                    catch {
                        L.og.debug("problem decoding nprofile")
                    }
                default:
                    L.og.debug("eeuh")
            }
            
          
            if let range = Range(match.range, in: replacedString) {
                replacedString.replaceSubrange(range, with: replacement)
            }
        }

        return TextWithPs(text: replacedString, pTags: pTags)
    }


    private func removeImageLinks(event: Event, text:String) -> String {
        text.replacingOccurrences(of: #"(?i)https?:\/\/\S+?\.(?:png#?|jpe?g#?|gif#?|webp#?|bmp#?)(\??\S+){0,1}\b"#,
                                  with: "",
                                  options: .regularExpression)
    }

    // Takes a string and replaces any link with a markdown link. Also handles subdomains
    static func replaceURLsWithMarkdownLinks(in string: String) -> String {
        return string
            .replacingOccurrences(of: #"(?!.*\.\.)(?<!https?:\/\/)(?<!\S)[a-zA-Z0-9\-\.]+(?:\.[a-zA-Z]{2,999}+)+([\/\?\=\&\#\.]\@?[\w-]+)*\/?"#,
                                  with: "[$0](https://$0)",
                                  options: .regularExpression) // REPLACE ALL DOMAINS WITHOUT PROTOCOL, WITH MARKDOWN LINK AND ADD PROTOCOL
            .replacingOccurrences(of: #"(?!.*\.\.)(?<!\S)([\w+]+\:\/\/)?[a-zA-Z0-9\-\.]+(?:\.[a-zA-Z]{2,999}+)+([\/\?\=\&\#\%\+\.]\@?[\S]+)*\/?"#,
                                  with: "[$0]($0)",
                                  options: .regularExpression) // REPLACE THE REMAINING URLS THAT HAVE PROTOCOL, BUT IGNORE ALREADY MARKDOWNED LINKS
    }
    
    static func replaceNaddrWithMarkdownLinks(in string: String) -> String {
        return string
            .replacingOccurrences(of: ###"(?:nostr:)?(naddr1[023456789acdefghjklmnpqrstuvwxyz]+)\b"###,
                                  with: "[naddr1...](nostur:nostr:$1)",
                                  options: .regularExpression)
    }

    static func replaceHashtagsWithMarkdownLinks(in string: String) -> String {
        return string
            .replacingOccurrences(of: ###"(?<![/\?]|\b)(\#)([^\s#\]\[]\S{2,})\b"###,
                                  with: "[$0](nostur:t:$2)",
                                  options: .regularExpression)
    }
    
    // hashtag -> image name
    static let hashtags = ["#bitcoin": "HashtagBitcoin",
                               "#btc": "HashtagBitcoin",
                               "#sats": "HashtagBitcoin",
                               "#satoshis": "HashtagBitcoin",
                               "#биткоин": "HashtagBitcoin",
                               "#nostur": "HashtagNostur",
                               "#nostr": "HashtagNostr",
                               "#lightning": "HashtagLightning",
                               "#zapping": "HashtagLightning",
                               "#zapper": "HashtagLightning",
                               "#zapped": "HashtagLightning",
                               "#zaps": "HashtagLightning",
                               "#zap": "HashtagLightning",
                               "#nostrich": "HashtagNostrich",
                               "#eth": "HashtagShitcoin",
                               "#ethereum": "HashtagShitcoin",
                               "#bnb": "HashtagShitcoin",
                               "#sol": "HashtagShitcoin",
                               "#solana": "HashtagShitcoin",
                               "#xrp": "HashtagShitcoin",
                               "#cardano": "HashtagShitcoin",
                               "#ada": "HashtagShitcoin",
                               "#dogecoin": "HashtagShitcoin",
                               "#doge": "HashtagShitcoin",
                               "#bitcoincash": "HashtagShitcoin",
                               "#bch": "HashtagShitcoin",
                               "#bsv": "HashtagShitcoin",
                               "#bitcoinsv": "HashtagShitcoin",
                               "#iota": "HashtagShitcoin",
                               "#ftt": "HashtagShitcoin",
                               "#fil": "HashtagShitcoin",
                               "#filecoin": "HashtagShitcoin",
                               "#xlm": "HashtagShitcoin",
                               "#stellar": "HashtagShitcoin",
                               "#aptos": "HashtagShitcoin",
                               "#apt": "HashtagShitcoin",
                               "#near": "HashtagShitcoin",
                               "#icp": "HashtagShitcoin",
                               "#shib": "HashtagShitcoin",
                               "#link": "HashtagShitcoin",
                               "#chainlink": "HashtagShitcoin",
                               "#polygon": "HashtagShitcoin",
                               "#matic": "HashtagShitcoin",
                               "#dot": "HashtagShitcoin",
                               "#polkadot": "HashtagShitcoin",
                               "#tron": "HashtagShitcoin",
                               "#trx": "HashtagShitcoin",
                               "#avax": "HashtagShitcoin",
                               "#avalanche": "HashtagShitcoin",
                               "#litecoin": "HashtagShitcoin",
                               "#ltc": "HashtagShitcoin",
                               "#toncoin": "HashtagShitcoin",
                               "#ton": "HashtagShitcoin",
                               "#zcash": "HashtagShitcoin",
                               "#zec": "HashtagShitcoin",
                               "#dash": "HashtagShitcoin",
                               "#monero": "HashtagShitcoin",
                               "#xmr": "HashtagShitcoin",
                               "#hex": "HashtagShitcoin",
                               "#pls": "HashtagShitcoin",
                               "#pulsechain": "HashtagShitcoin",
                               "#nano": "HashtagShitcoin",
                               "#xno": "HashtagShitcoin",
                               "#nostriches": "HashtagNostrich"]
    
    // Cached regex that is used in NSMutableAttributedString.addHashtagIcons()
    static let htRegex = try! NSRegularExpression(pattern: "\\b\(hashtags.keys.joined(separator: "\\b|"))\\b", options: [.caseInsensitive])
    
    // Build NSAttributedString hashtag icons once for reuse in NSMutableAttributedString.addHashtagIcons()
    public lazy var hashtagIcons: [String: NSAttributedString] = {
        
        let font = UIFont.preferredFont(forTextStyle: .body)
        let size = (font.capHeight - font.pointSize).rounded() / 2
        
        return Self.hashtags.mapValues { imageName in
            let attachment = NSTextAttachment()
            attachment.image = UIImage(named: imageName)
            attachment.bounds = CGRect(x: 0, y: size, width: font.pointSize, height: font.pointSize)
            
            let attributedImageString = NSAttributedString(attachment: attachment)
            return attributedImageString
        }
    }()
}

struct TextWithPs: Hashable {
    var text: String
    var pTags: [Ptag]
}

extension String {
    func escapeMD() -> String {
        return self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "**", with: "\\*\\*")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "/", with: "\\/")
            .replacingOccurrences(of: "__", with: "\\_\\_")
    }
}
