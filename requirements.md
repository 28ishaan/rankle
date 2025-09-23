# Project Requirements Document (PRD)

**App Name:** Rankle  
**Platform:** iOS (with potential expansion to Android/web later)  
**Prepared For:** Initial Concept Phase  

---

## 1. Purpose
Rankle is an iOS app that allows users to create and manage ranked lists of any items (e.g., artists, movies, TV shows, cars). By engaging users in simple 1v1 matchups, the app determines personalized ordered lists that reflect the user’s preferences.  

---

## 2. Goals and Objectives
- Provide a **fun and intuitive** way to rank personal favorites.  
- Reduce the complexity of ranking large lists by breaking the process into **pairwise comparisons**.  
- Allow users to **add new items** into existing ranked lists seamlessly.  
- Create a **personalized and persistent space** for storing and reviewing ranked lists.  

---

## 3. Target Audience
- Individuals who enjoy ranking, debating, and organizing personal preferences.  
- Fans of media (movies, music, TV, etc.), hobbies, or products who want to record and share rankings.  
- Social groups who may compare their rankings with friends (future potential feature).  

---

## 4. Key Features

### 4.1 Core Features
1. **List Creation**  
   - Users can create a new list and name it (e.g., "Favorite Movies").  
   - Add multiple items manually to initialize the list.  

2. **Ranking via Matchups**  
   - App generates random or algorithmically selected 1v1 matchups.  
   - User chooses their preferred item in each matchup.  
   - The app dynamically adjusts and builds an ordered list based on responses.  

3. **Adding New Items**  
   - Users can add new items to an existing list.  
   - New items are ranked by comparing them against selected items in the existing list (not all items, to save time).  
   - Algorithm determines the best insertion point for the new item.  

4. **My Lists Home Screen**  
   - Dashboard displays all user-created lists.  
   - Each list shows title, number of items, and preview of top items.  

5. **Persistence**  
   - Lists and rankings are stored locally on the device (cloud sync optional future feature).  

### 4.2 Secondary Features (Future Roadmap)
- **Sharing**: Export and share ranked lists with friends.  
- **Social Comparison**: Compare lists against friends’ lists (e.g., overlap %).  
- **Custom Matchup Settings**: Allow users to pick how many matchups are generated.  
- **Data Sync**: Cloud backup across devices.  

---

## 5. Functional Requirements

### 5.1 User Actions
- Create, edit, delete lists.  
- Add, remove, or rename list items.  
- Rank items by responding to matchup prompts.  
- Add new items to an existing list and rank them.  
- View ranked lists at any time.  

### 5.2 System Behavior
- Generate matchups dynamically.  
- Store results of matchups to update rankings.  
- Insert new items into existing rankings efficiently without requiring full re-ranking.  
- Display final ordered lists clearly and consistently.  

---

## 6. Non-Functional Requirements
- **Usability:** Simple, clean interface that minimizes friction in list creation and ranking.  
- **Performance:** Matchup generation and list reordering must feel instantaneous.  
- **Scalability:** Support large lists (e.g., 100+ items) without slowing down.  
- **Persistence:** Data remains available even if the app is closed or device restarts.  
- **Security & Privacy:** Lists remain private to the user unless explicitly shared.  

---

## 7. User Flows

### Flow 1: Creating a New List
1. User taps **“New List”**.  
2. User enters list name and adds items.  
3. App begins showing 1v1 matchups until ranking is determined.  
4. Final ranked list appears and is saved to **My Lists**.  

### Flow 2: Adding a New Item to an Existing List
1. User selects an existing list.  
2. User taps **“Add Item”** and inputs new item.  
3. App generates matchups between new item and select items from the list.  
4. Ranking algorithm inserts new item into appropriate position.  
5. Updated list is saved.  

### Flow 3: Browsing Lists
1. User opens app.  
2. Home screen shows **My Lists** with previews.  
3. User taps into a list to view or edit.  

---

## 8. Success Metrics
- **User Engagement:** Average number of lists created per user.  
- **Ranking Completion Rate:** % of lists where users complete the ranking process.  
- **Retention:** How often users return to update/add to lists.  
- **Satisfaction:** Positive user reviews in the App Store.  

---

## 9. Constraints and Assumptions
- MVP is **iOS only**, no cross-platform at launch.  
- Data stored **locally** at first (cloud sync optional later).  
- Matchup algorithm should minimize fatigue by avoiding excessive comparisons.  

---

## 10. Open Questions
- Should users be able to set list categories (e.g., “Movies,” “Sports,” “Misc”)?  
- How much onboarding/tutorial is needed to explain matchups?  
- Will there be a social component at MVP stage, or kept for v2?  
