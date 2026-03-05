# Rankle

An iOS app to create and manage ranked lists via quick 1v1 matchups.

## Description

Rankle helps you rank your favorites through simple pairwise comparisons. Whether you're ranking movies, music, restaurants, or anything else, Rankle breaks down the complex task of ordering large lists into easy 1v1 choices.

## Features

### Create Custom Lists
- **Named Lists**: Create lists with custom names and icon colors
- **Batch Add**: Enter multiple items at once using comma-separated values (e.g., "Item A, Item B, Item C")
- **List Types**: Choose between regular ranking lists or tier lists (S, A, B, C, D, F)

### Intelligent Ranking
- **Add & Rank**: Add new items to existing lists and rank them efficiently without disrupting your current order
- **Full Re-Rank**: Refresh your entire list ranking when preferences change
- **Binary Insertion**: Uses smart algorithms to minimize comparisons and find the perfect spot for each item

### Tier Lists
- **Drag & Drop Organization**: Organize items by dragging them into tiers (S, A, B, C, D, F)
- **Visual Tier System**: Color-coded tiers make it easy to categorize your items
- **Unassigned Items**: Start with all items unassigned and organize them at your own pace
- **No Matchups Required**: Skip the ranking process and organize items directly into tiers

### Media Support
- **Images as Items**: Add images directly as list items (not just text)
- **Attach Photos**: Add a photo to any item in your list
- **Full-Screen Matchups**: Enhanced matchup interface with top-vs-bottom layout for better image viewing

### Collaborative Lists
- **Share & Collaborate**: Create collaborative lists and share them via a deep link (`rankle://`)
- **Clear Role Boundaries**: Only the list owner can add/remove items, rename, or change the color. Collaborators can only submit their own ranking.
- **Real-Time Sync**: Changes from the owner and new contributions from collaborators are pushed to all devices via CloudKit silent push notifications. The list also refreshes automatically when you return to it.
- **Aggregated Rankings**: View a combined Borda-count ranking from all contributors — updated after every submission.
- **Contribution Links**: Share your personal ranking with others via a separate contribution deep link.
- **Note**: Tier lists cannot be collaborative (regular lists only).

### Privacy First
- **Local Storage**: Non-collaborative lists stay on your device — no cloud, no tracking, no data collection
- **iCloud Sync**: Collaborative lists use Apple's secure CloudKit (requires iCloud account)
- **Offline Support**: Non-collaborative lists work completely offline

## How to Use

### Creating a List
1. Tap the **+** button on the home screen
2. Choose **Regular List** or **Tier List**
3. Enter a list name and choose an icon color
4. Add initial items (comma-separated: "Item A, Item B, Item C")
5. Tap **Create**

### Adding Items to an Existing List
1. Open your list
2. Type new items in the text field (comma-separated)
3. Tap **Add & Rank**
4. Complete the quick matchups to insert items in the right position

### Ranking Items
1. Tap **Rank Items** on any list
2. Choose your preferred option in each 1v1 matchup
3. Your final ranked list is saved automatically

### Managing Items
- **Edit**: Tap any item to add a photo or manage details
- **Delete**: Swipe left on an item or tap Edit to delete multiple items
- **Manual Reorder**: Drag and drop items to reorder without going through matchups (regular lists)
- **Rank Items**: Use the ranking process to completely reorder your list via matchups (regular lists)
- **Tier Organization**: Drag items into tiers (S, A, B, C, D, F) to organize them (tier lists)

### Collaborating on a List
1. Open a regular list and enable **Collaborative list** in the Collaboration section (you must be the owner)
2. Tap the share button (↑) and choose **Share to Rankle Users** to copy a deep link
3. Send the link to collaborators — they open it to import the list
4. Collaborators tap **Rank Items** to submit their ranking; the aggregated result updates for everyone
5. Pull down to refresh or tap ↻ to fetch the latest contributions at any time

#### Owner vs. Collaborator permissions

| Action | Owner | Collaborator |
|---|---|---|
| Add / remove items | ✅ | ✗ |
| Rename list | ✅ | ✗ |
| Change color | ✅ | ✗ |
| Enable / disable collaboration | ✅ | ✗ |
| Submit a ranking | ✅ | ✅ |
| View aggregated ranking | ✅ | ✅ |
| Leave list (removes locally) | ✅ | ✅ |
| Delete list from CloudKit | ✅ | ✗ |

## Privacy

Rankle collects **zero** personal information. All your data stays on your device. Non-collaborative lists never leave your device. Collaborative lists use Apple's CloudKit infrastructure under your own iCloud account — Rankle has no servers.

See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for complete details.

## Requirements

- iOS 16.0 or later
- iPhone or iPad
- iCloud account required for collaborative lists

## Availability

Download Rankle from the App Store.

## Support

For questions or feedback, please contact us through the App Store listing.