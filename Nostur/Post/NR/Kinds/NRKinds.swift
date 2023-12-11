//
//  NRKinds.swift
//  Nostur
//
//  Created by Fabian Lachman on 26/05/2023.
//

import SwiftUI

struct KindFileMetadata {
    var url:String
    var m:String?
    var hash:String?
    var dim:String?
    var blurhash:String?
}

let SUPPORTED_VIEW_KINDS:Set<Int64> = [1,6,9802,30023]

struct AnyKind: View {
    @ObservedObject private var nrPost: NRPost
    private var theme:Theme
    
    init(_ nrPost: NRPost, theme: Theme) {
        self.nrPost = nrPost
        self.theme = theme
    }
    
    var body: some View {
        if SUPPORTED_VIEW_KINDS.contains(nrPost.kind) {
            switch nrPost.kind {
//                case 9735: TODO: ....
//                    ZapReceipt(sats: <#T##Double#>, receiptPubkey: <#T##String#>, fromPubkey: <#T##String#>, from: <#T##Event#>)
                default:
                    EmptyView()
            }
        }
        else {
            Label(String(localized:"kind \(Double(nrPost.kind).clean) type not (yet) supported", comment: "Message shown when a 'kind X' post is not yet supported"), systemImage: "exclamationmark.triangle.fill")
                .hCentered()
                .frame(maxWidth: .infinity)
                .background(theme.lineColor.opacity(0.2))
//                            .withoutAnimation()
//                            .transaction { t in
//                                t.animation = nil
//                            }
            // TODO: Render ALT
        }
    }
}
