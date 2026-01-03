//
//  SearchView.swift
//  WikiShorts
//
//  Created by Sefa Cem Turan on 16.08.2025.
//

import SwiftUI

struct SearchView: View {
    @ObservedObject var storeManager = StoreManager() // Reusing storeManager logic if needed later
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchView()
}
