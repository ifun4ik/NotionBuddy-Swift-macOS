import SwiftUI

struct AccountPickerView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var isExpanded = false
    @State private var accountToLogout: NotionAccount?
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: sessionManager.currentAccount?.avatarUrl ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sessionManager.currentAccount?.name ?? "No Account")
                            .font(.custom("Onest-Medium", size: 16))
                            .foregroundColor(.textPrimary)
                        Text(sessionManager.currentAccount?.email ?? "")
                            .font(.custom("Onest-Regular", size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.iconSecondary)
                        .rotationEffect(Angle(degrees: isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cardBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sessionManager.accounts.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            Button(action: {
                                sessionManager.selectedAccountIndex = index
                                withAnimation {
                                    isExpanded = false
                                }
                            }) {
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: sessionManager.accounts[index].avatarUrl ?? "")) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.crop.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    
                                    Text(sessionManager.accounts[index].name)
                                        .font(.custom("Onest-Regular", size: 14))
                                        .foregroundColor(.textPrimary)
                                    
                                    Spacer()
                                    
                                    if index == sessionManager.selectedAccountIndex {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                accountToLogout = sessionManager.accounts[index]
                                showLogoutConfirmation = true
                            }) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(index == sessionManager.selectedAccountIndex ? Color.bgSecondary : Color.clear)
                        
                        if index < sessionManager.accounts.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                    
                    Button(action: {
                        sessionManager.startWebAuthSession()
                        withAnimation {
                            isExpanded = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("Add New Account")
                                .font(.custom("Onest-Medium", size: 14))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(Color.cardBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .animation(.easeInOut, value: isExpanded)
        .alert(isPresented: $showLogoutConfirmation) {
            Alert(
                title: Text("Logout Confirmation"),
                message: Text("Are you sure you want to log out of \(accountToLogout?.name ?? "this account")?"),
                primaryButton: .destructive(Text("Logout")) {
                    if let account = accountToLogout {
                        sessionManager.logoutAccount(account)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
}
