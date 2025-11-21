import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: ListsViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    @State private var isPresentingCreate = false
    @State private var isPresentingCreateTier = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: Color.themeBackground(colorScheme),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                if viewModel.lists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 48, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.themePrimary(colorScheme).opacity(0.8))
                        Text("No lists yet")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Tap + to create your first list")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.lists) { list in
                            NavigationLink(destination: destinationView(for: list)) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(list.color)
                                        .frame(width: 28, height: 28)
                                    Text(list.name)
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.primary)
                                    if list.listType == .tier {
                                        HStack(spacing: 4) {
                                            Image(systemName: "square.grid.3x3.fill")
                                            Text("Tier List")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())
                                    }
                                    if list.isCollaborative {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.2.fill")
                                            Text("Collaborative")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            // Only allow deletion if user is owner for collaborative lists
                            viewModel.deleteList(at: offsets)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text("R")
                            .font(.custom("Avenir Next", size: 28))
                            .fontWeight(.heavy)
                            .foregroundColor(Color.themePrimary(colorScheme))
                            .padding(8)
                            .background(Circle().fill(colorScheme == .dark ? Color.nightDarkGray : .white))
                            .shadow(color: Color.themePrimary(colorScheme).opacity(0.3), radius: 4)
                        Text("My Lists")
                            .font(.custom("Avenir Next", size: 24))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        themeManager.toggle()
                    } label: {
                        Image(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.fill")
                            .foregroundColor(Color.themePrimary(colorScheme))
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            isPresentingCreate = true
                        } label: {
                            Label("Regular List", systemImage: "list.bullet")
                        }
                        Button {
                            isPresentingCreateTier = true
                        } label: {
                            Label("Tier List", systemImage: "square.grid.3x3")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Color.themePrimary(colorScheme))
                    }
                }
            }
            .sheet(isPresented: $isPresentingCreate) {
                CreateListView(
                    onCreate: { name, items, color, isCollaborative in
                        viewModel.createList(name: name, items: items, color: color, isCollaborative: isCollaborative)
                    },
                    onCreateWithItems: { name, items, color, isCollaborative in
                        viewModel.createListWithItems(name: name, items: items, color: color, isCollaborative: isCollaborative)
                    },
                    isTierList: false
                )
            }
            .sheet(isPresented: $isPresentingCreateTier) {
                CreateListView(
                    onCreate: { name, items, color, isCollaborative in
                        viewModel.createTierList(name: name, items: items, color: color, isCollaborative: isCollaborative)
                    },
                    onCreateWithItems: { name, items, color, isCollaborative in
                        viewModel.createTierListWithItems(name: name, items: items, color: color, isCollaborative: isCollaborative)
                    },
                    isTierList: true
                )
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for list: RankleList) -> some View {
        if list.listType == .tier {
            TierListView(list: list, onUpdate: { updated in
                viewModel.replaceList(updated)
            }, listsViewModel: viewModel)
        } else {
            ListDetailView(list: list, onUpdate: { updated in
                viewModel.replaceList(updated)
            }, listsViewModel: viewModel)
        }
    }
}

#Preview {
    HomeView(viewModel: ListsViewModel())
}
