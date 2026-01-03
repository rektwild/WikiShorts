import SwiftUI

extension View {
    @ViewBuilder
    func searchableResponsive(text: Binding<String>, isPresented: Binding<Bool>, prompt: String) -> some View {
        if #available(iOS 17.0, *) {
            self.searchable(text: text, isPresented: isPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
        } else {
            self.searchable(text: text, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
        }
    }
}
