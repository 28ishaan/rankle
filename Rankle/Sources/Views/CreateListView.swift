import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var currentItem: String = ""
    @State private var items: [String] = []
    @State private var isCollaborative: Bool = false
    @State private var selectedColor: Color = .cyan

    var onCreate: (String, [String], Color, Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("List Name") {
                    TextField("e.g., Favorite Movies", text: $name)
                }
                Section("Icon Color") {
                    ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                }
                Section("Collaboration") {
                    Toggle("Create as collaborative list", isOn: $isCollaborative)
                }
                Section("Add Items") {
                    HStack {
                        TextField("Item name", text: $currentItem)
                        Button("Add") {
                            let trimmed = currentItem.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            items.append(trimmed)
                            currentItem = ""
                        }
                        .buttonStyle(ThemeButtonStyle())
                        .disabled(currentItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Section("Items (\(items.count))") {
                    if items.isEmpty {
                        Text("No items yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundColor(.secondary)
                                Text(item)
                            }
                        }
                        .onDelete { offsets in
                            items.remove(atOffsets: offsets)
                        }
                    }
                }
            }
            .navigationTitle("New List")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, items, selectedColor, isCollaborative)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || items.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CreateListView { _, _, _, _ in }
}
