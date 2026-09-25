//
//  SearchFieldBar.swift
//  Watchnow
//

import SwiftUI

/// The app's own search field, replacing `.searchable`.
///
/// The system field was placed by the OS, and the placement moved under us
/// between releases: iOS 26 put it in the tab bar for a `role: .search` tab,
/// iOS 27 split that treatment into `TabRole.prominent` and left the field in
/// the navigation bar drawer — so hiding that bar to give the poster band the
/// top of the display took the only search field in the app with it. Owning
/// the field ends that: the search screen now looks and behaves identically
/// on 18, 26 and 27, and the hero keeps the top edge on all of them.
///
/// Shown only once search is active. Before that the hero's chip is the way
/// in, so the start screen stays art and nothing else.
struct SearchFieldBar: View {

    @Binding var text: String
    /// Owned by `SearchView` so it can focus the field the moment the bar
    /// appears — a `FocusState` can't be driven from outside the view that
    /// declares it, so the binding is passed down rather than the state.
    var isFocused: FocusState<Bool>.Binding
    /// Full reset: drop the query, the results and the keyboard.
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            field
            Button("Cancel", action: onCancel)
                .appFont(16, relativeTo: .body)
                .tint(.accentColor)
                .accessibilityHint("Leaves search and returns to the start screen")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .appFont(15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(.secondary)

            TextField("Movies, TV series, actors", text: $text)
                .appFont(16, relativeTo: .body)
                .focused(isFocused)
                // The query runs on a debounce as the user types, so Return
                // has nothing left to submit — it just puts the keyboard
                // away over the results it already fetched.
                .submitLabel(.search)
                .onSubmit { isFocused.wrappedValue = false }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                    // Clearing is not leaving: keep the keyboard up so the
                    // next query can be typed straight away.
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .appFont(16, relativeTo: .body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // `tertiarySystemFill` rather than a background colour: it is the
        // fill UIKit uses for search fields, so it reads as an input in both
        // appearances. `secondarySystemBackground` was very nearly the page
        // colour in light mode and the capsule disappeared.
        .background {
            Capsule(style: .continuous)
                .fill(Color(.tertiarySystemFill))
        }
        // The whole capsule takes the tap, not just the glyphs inside it.
        .contentShape(Capsule(style: .continuous))
        .onTapGesture { isFocused.wrappedValue = true }
        .animation(.easeInOut(duration: AppMotion.quick), value: text.isEmpty)
    }
}
