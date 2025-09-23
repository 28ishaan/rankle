import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: ListsViewModel

    @State private var isPresentingCreate = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.lists) { list in
                    NavigationLink(destination: ListDetailView(list: list, onUpdate: { updated in
                        viewModel.replaceList(updated)
                    })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(list.name)
                                .font(.headline)
                            if !list.items.isEmpty {
                                Text(list.items.prefix(3).map { $0.title }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No items yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: viewModel.deleteList)
            }
            .navigationTitle("My Lists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingCreate) {
                CreateListView { name, items in
                    viewModel.createList(name: name, items: items)
                }
            }
        }
    }
}

#Preview {
    HomeView(viewModel: ListsViewModel())
}
