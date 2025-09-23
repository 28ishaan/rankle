import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var itemsText: String = ""
    @State private var selectedColor: Color = .cyan

    var onCreate: (String, [String], Color) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("List Name") {
                    TextField("e.g., Favorite Movies", text: $name)
                }
                Section("Icon Color") {
                    ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                }
                Section("Items (one per line)") {
                    TextEditor(text: $itemsText)
                        .frame(minHeight: 160)
                        .font(.system(.body, design: .rounded))
                }
            }
            .navigationTitle("New List")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let items = itemsText.split(separator: "\n").map { String($0) }
                        onCreate(name, items, selectedColor)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    CreateListView { _, _, _ in }
}
