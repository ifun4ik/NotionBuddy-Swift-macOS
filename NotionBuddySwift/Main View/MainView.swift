import SwiftUI

struct MainView: View {
    @ObservedObject private var viewModel: MainViewModel
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var showTemplateCreator = false
    @State private var shouldDismiss = false
    
    init(sessionManager: SessionManager) {
        _viewModel = ObservedObject(wrappedValue: MainViewModel(sessionManager: sessionManager))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let account = viewModel.currentAccount {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(account.name)
                            .font(.headline)
                        Text(account.workspaceName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let urlString = account.avatarUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .frame(width: 32, height: 32)
                    }
                }
                .padding()
//                .background(Color(NSColor.secondarySystemFill))
                
                Divider()
                
                // Template List
                TemplateListView(viewModel: viewModel)
                
                Divider()
                
                // Add New Template Button
                Button(action: {
                    showTemplateCreator = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Template")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.bottom)
            } else {
                VStack {
                    Text("Please add an account.")
                        .font(.headline)
                        .padding()
                    
                    Button("Add New Account") {
                        viewModel.addNewAccount()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showTemplateCreator) {
            DatabaseNavigatorView(accessToken: viewModel.currentAccount?.accessToken ?? "", shouldDismiss: $shouldDismiss)
                .environment(\.managedObjectContext, managedObjectContext)
        }
    }
}

struct TemplateListView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedTemplate: Template?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.templates) { template in
                    TemplateRowView(template: template)
                        .onTapGesture {
                            selectedTemplate = template
                        }
                }
            }
            .padding(.vertical, 8)
        }
        .sheet(item: $selectedTemplate) { template in
            EditTemplateView(viewModel: TemplateViewModel(template: template), accessToken: viewModel.currentAccount?.accessToken ?? "")
                .environment(\.managedObjectContext, viewModel.managedObjectContext)
        }
    }
}

struct TemplateRowView: View {
    let template: Template
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
            Text(template.name ?? "Unnamed Template")
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
//        .background(Color(NSColor.secondarySystemFill))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
