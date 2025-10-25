import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: ListsViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    @State private var isPresentingCreate = false

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
                            NavigationLink(destination: ListDetailView(list: list, onUpdate: { updated in
                                viewModel.replaceList(updated)
                            })) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(list.color)
                                        .frame(width: 28, height: 28)
                                    Text(list.name)
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.primary)
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
                    Button {
                        isPresentingCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Color.themePrimary(colorScheme))
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
