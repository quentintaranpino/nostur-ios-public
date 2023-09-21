//
//  FetchVM.swift
//  Nostur
//
//  Created by Fabian Lachman on 17/09/2023.
//

import SwiftUI

// Generic reusable fetcher
class FetchVM<T: Equatable>: ObservableObject {
    
    public typealias FetchParams = (req: () -> Void, onComplete: (RelayMessage?) -> Void, altReq: (() -> Void)?)
    
    @Published var state:State
    private let backlog:Backlog
    private let debounceTime:Double
    private var fetchParams: FetchParams? = nil
    
    init(timeout:Double = 5.0, debounceTime:Double = 0.5) {
        self.state = .initializing
        self.debounceTime = debounceTime
        self.backlog = Backlog(timeout: timeout, auto: true)
    }
    
    public func setFetchParams(_ fetchParams: FetchParams) {
        self.fetchParams = fetchParams
    }
    
    public func ready(_ item:T) {
        DispatchQueue.main.async {
            self.backlog.clear()
            self.state = .ready(item)
        }
    }

    public func altFetch() {
        guard let fetchParams = self.fetchParams else { L.og.error("🔴🔴 FetchVM: missing fetchParams"); return }
        guard let altReq = fetchParams.altReq else { L.og.error("🔴🔴 FetchVM: missing fetchParams.altReq"); return }
        let reqTask = ReqTask(
            debounceTime: self.debounceTime,
            reqCommand: { taskId in
                self.state = .altLoading
                altReq()
            },
            processResponseCommand: { taskId, relayMessage in
                L.og.info("FetchVM: ready to process relay response")
                fetchParams.onComplete(relayMessage)
                self.backlog.clear()
            },
            timeoutCommand: { taskId in
                L.og.info("FetchVM: timeout ")
                fetchParams.onComplete(nil)
                self.backlog.clear()
            })

        self.backlog.add(reqTask)
        reqTask.fetch()
    }
    
    public func timeout() {
        DispatchQueue.main.async {
            self.state = .timeout
        }
    }
    
    public func error(_ text:String) {
        DispatchQueue.main.async {
            self.state = .error(text)
        }
    }
    
    public func fetch() {
        guard let fetchParams = self.fetchParams else { L.og.error("🔴🔴 FetchVM: missing fetchParams"); return }
        let reqTask = ReqTask(
            debounceTime: self.debounceTime,
            reqCommand: { taskId in
                fetchParams.req()
            },
            processResponseCommand: { taskId, relayMessage in
                L.og.info("FetchVM: ready to process relay response")
                fetchParams.onComplete(relayMessage)
                self.backlog.clear()
            },
            timeoutCommand: { taskId in
                L.og.info("FetchVM: timeout ")
                fetchParams.onComplete(nil)
                self.backlog.clear()
            })

        self.backlog.add(reqTask)
        reqTask.fetch()
    }
    
    enum State: Equatable {
        case initializing
        case loading
        case altLoading
        case ready(T)
        case timeout
        case error(String)
    }
}
