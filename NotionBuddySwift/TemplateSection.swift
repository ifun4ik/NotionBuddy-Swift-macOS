import SwiftUI

struct TemplatesSection: View {
    @ObservedObject var viewModel: TemplatesListViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Templates")
                    .font(.headline)
                Text("\(viewModel.templates.count)")
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            ForEach(viewModel.templates) { template in
                TemplateRow(template: template)
            }
        }
    }
}
