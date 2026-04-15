//
//  ContentListResult.swift
//  Watchnow
//
//  Created by k.christopoulos on 28/9/25.
//

import Foundation

struct ContentListResult: LoadMoreContentProtocol {
    private(set) var result: GenericResultResponse
    var currentPage: Int = 1

    init(result: GenericResultResponse) {
        self.result = result
    }
    mutating func appendResult(_ result: GenericResultResponse) {
        self.result.results.append(contentsOf: result.results)
    }
    mutating func incrementCurrentPage() {
        self.currentPage += 1
    }
    
    func getResults() -> [Result] {
        return result.results
    }
}

protocol LoadMoreContentProtocol {
    
    var currentPage: Int { get set }
    var result: GenericResultResponse { get }
}

extension LoadMoreContentProtocol {
    
    func canLoadMoreContent() -> Bool {
        
        guard let totalPages = result.total_pages else {
            return false
        }
        return currentPage < totalPages
    }
}
