//
//  TodayView.swift
//  WikiShorts
//
//  Created by Sefa Cem Turan on 16.08.2025.
//

import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Today")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .navigationTitle("Today")
        }
    }
}

#Preview {
    TodayView()
}
