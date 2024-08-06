import SwiftUI

struct TemplateListHeaderView: View {
    let count: Int
    let addNewTemplate: () -> Void
    
    var body: some View {
        HStack {
            Text("Templates \(count)")
                .font(.custom("Onest-Medium", size: 20))
                .foregroundColor(.textPrimary)
            Spacer()
            Button(action: addNewTemplate) {
                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 16)
    }
}
