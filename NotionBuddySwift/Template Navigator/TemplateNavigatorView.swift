import SwiftUI

struct TemplateNavigatorView: View {
    @StateObject private var viewModel: TemplateNavigatorViewModel
    @Environment(\.colorScheme) var colorScheme
    
    init(managedObjectContext: NSManagedObjectContext, sessionManager: SessionManager) {
        let vm = TemplateNavigatorViewModel(managedObjectContext: managedObjectContext, sessionManager: sessionManager)
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            userInfoHeader
            templateList
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .sheet(isPresented: $viewModel.showDatabaseNavigatorView) {
            DatabaseNavigatorView(accessToken: viewModel.sessionManager.accounts[viewModel.sessionManager.selectedAccountIndex].accessToken, shouldDismiss: .constant(false))
        }
        .sheet(item: $viewModel.selectedTemplate) { template in
            EditTemplateView(viewModel: TemplateViewModel(template: template), accessToken: viewModel.sessionManager.accounts[viewModel.sessionManager.selectedAccountIndex].accessToken)
        }
    }
    
    private var userInfoHeader: some View {
        HStack {
            AsyncImage(url: URL(string: viewModel.userInfo.avatarUrl ?? "")) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.crop.circle")
                    .resizable()
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(viewModel.userInfo.name)
                    .font(.headline)
                Text(viewModel.userInfo.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.down")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
    }
    
    private var templateList: some View {
        List {
            HStack {
                Text("Templates")
                    .font(.headline)
                Text("\(viewModel.templates.count)")
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: viewModel.addTemplate) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                }
            }
            
            ForEach(viewModel.templates) { template in
                TemplateRowView(template: template)
                    .onTapGesture {
                        viewModel.editTemplate(template)
                    }
            }
            .onDelete(perform: viewModel.deleteTemplate)
        }
        .listStyle(PlainListStyle())
    }
}

struct TemplateRowView: View {
    let template: Template
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)
            VStack(alignment: .leading) {
                Text(template.name ?? "Unnamed Template")
                    .font(.headline)
                Text(template.databaseId ?? "No database")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("⌘+\(template.order)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
    }
}
