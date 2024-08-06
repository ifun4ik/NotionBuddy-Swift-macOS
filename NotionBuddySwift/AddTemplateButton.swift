import SwiftUI

struct AddTemplateButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus")
                Text("Add Template")
            }
        }
        .buttonStyle(.borderedProminent)
    }
}
