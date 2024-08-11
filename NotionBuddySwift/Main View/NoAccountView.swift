import SwiftUI

struct NoAccountView: View {
    let addNewAccount: () -> Void
    
    var body: some View {
        VStack {
            Text("Please add an account.")
                .font(.custom("Onest-Medium", size: 18))
                .foregroundColor(.textPrimary)
            
            Button(action: addNewAccount) {
                Text("Add New Account")
                    .font(.custom("Onest-Medium", size: 16))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.top, 16)
        }
    }
}
