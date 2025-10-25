import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: ListsViewModel

    @State private var isPresentingCreate = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 7/255, green: 16/255, blue: 39/255)
                    .ignoresSafeArea()
                if viewModel.lists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 48, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        Text("No lists yet")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Tap + to create your first list")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.lists) { list in
                            NavigationLink(destination: ListDetailView(list: list, onUpdate: { updated in
                                viewModel.replaceList(updated)
                            })) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(list.color)
                                        .frame(width: 28, height: 28)
                                    Text(list.name)
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 6)
                            }
                            .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: viewModel.deleteList)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("My Lists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $isPresentingCreate) {
                CreateListView { name, items, color in
                    viewModel.createList(name: name, items: items, color: color)
                }
            }
        }
    }
}

#Preview {
    HomeView(viewModel: ListsViewModel())
}
