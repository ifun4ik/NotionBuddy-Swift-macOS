import SwiftUI

struct TemplatesList: View {
    @ObservedObject var viewModel: TemplatesListViewModel

    var body: some View {
        List {
            ForEach(viewModel.templates) { template in
                TemplateRow(template: template)
            }
            .onDelete(perform: viewModel.deleteTemplate)
            .onMove(perform: viewModel.moveTemplate)
        }
    }
}
