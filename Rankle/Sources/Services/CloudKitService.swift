import Foundation
import CloudKit

final class CloudKitService {
    static let shared = CloudKitService()
    
    private let container: CKContainer
    private let publicDB: CKDatabase
    
    // Record types
    private let listRecordType = "RankleList"
    private let contributionRecordType = "CollaboratorRanking"
    
    private init() {
        self.container = CKContainer.default()
        self.publicDB = container.publicCloudDatabase
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
    
    // MARK: - Lists
    
    func saveList(_ list: RankleList) async throws {
        // Fetch the existing record first so CloudKit treats this as an update (not an insert).
        // If the record doesn't exist yet, create a fresh one.
        let recordID = CKRecord.ID(recordName: list.id.uuidString, zoneID: .default)
        let record: CKRecord
        if let existing = try? await publicDB.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: listRecordType, recordID: recordID)
        }
        try populateListRecord(record, from: list)
        _ = try await publicDB.save(record)
    }
    
    func fetchListById(id: UUID) async throws -> RankleList? {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: .default)
        guard let record = try? await publicDB.record(for: recordID) else {
            return nil
        }
        return try listFromRecord(record)
    }
    
    /// Fetches all collaborative lists owned by the given user from the public database.
    /// NOTE: Requires the `ownerId` field to be marked as Queryable in the CloudKit Dashboard schema.
    func fetchOwnedLists(ownerId: UUID) async throws -> [RankleList] {
        let predicate = NSPredicate(format: "ownerId == %@", ownerId.uuidString)
        let query = CKQuery(recordType: listRecordType, predicate: predicate)

        var lists: [RankleList] = []
        var cursor: CKQueryOperation.Cursor?

        do {
            repeat {
                let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

                if let existingCursor = cursor {
                    result = try await publicDB.records(continuingMatchFrom: existingCursor, desiredKeys: nil, resultsLimit: 100)
                } else {
                    result = try await publicDB.records(matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100)
                }
                cursor = result.queryCursor

                for (_, recordResult) in result.matchResults {
                    switch recordResult {
                    case .success(let record):
                        if let list = try? listFromRecord(record) {
                            lists.append(list)
                        }
                    case .failure(let error):
                        #if DEBUG
                        print("Error fetching record: \(error)")
                        #endif
                    }
                }
            } while cursor != nil
        } catch let error as CKError where error.code == .unknownItem {
            // Record type doesn't exist in the schema yet (no list has ever been saved).
            // Return empty — the schema will be auto-created when the first list is saved.
            return []
        }

        return lists
    }
    
    func deleteList(id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: .default)
        try await publicDB.deleteRecord(withID: recordID)
    }
    
    // MARK: - Contributions
    
    func saveContribution(_ ranking: CollaboratorRanking, for listId: UUID) async throws {
        // Fetch existing record so CloudKit treats this as an update, not a conflicting insert.
        let recordName = "\(listId.uuidString)-\(ranking.userId.uuidString)"
        let recordID = CKRecord.ID(recordName: recordName, zoneID: .default)
        let record: CKRecord
        if let existing = try? await publicDB.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: contributionRecordType, recordID: recordID)
        }
        record["userId"] = ranking.userId.uuidString
        record["displayName"] = ranking.displayName
        record["ranking"] = ranking.ranking.map { $0.uuidString }.joined(separator: ",")
        record["updatedAt"] = ranking.updatedAt
        record["listId"] = listId.uuidString
        _ = try await publicDB.save(record)
    }
    
    func fetchContributions(for listId: UUID) async throws -> [CollaboratorRanking] {
        let predicate = NSPredicate(format: "listId == %@", listId.uuidString)
        let query = CKQuery(recordType: contributionRecordType, predicate: predicate)

        var contributions: [CollaboratorRanking] = []

        do {
            let result = try await publicDB.records(matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100)

            for (_, recordResult) in result.matchResults {
                switch recordResult {
                case .success(let record):
                    if let contribution = try? contributionFromRecord(record) {
                        contributions.append(contribution)
                    }
                case .failure(let error):
                    #if DEBUG
                    print("Error fetching contribution: \(error)")
                    #endif
                }
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Record type doesn't exist yet — no contributions have ever been saved.
            return []
        }

        return contributions
    }
    
    // MARK: - Subscriptions (Real-time updates)
    
    /// Subscribe to structural changes on a specific list (owner adds/removes items, etc).
    /// Uses the `listId` field stored on the list record for queryable subscription.
    func subscribeToListChanges(listId: UUID) async throws -> CKSubscription {
        let predicate = NSPredicate(format: "listId == %@", listId.uuidString)
        let subscription = CKQuerySubscription(
            recordType: listRecordType,
            predicate: predicate,
            subscriptionID: "list-\(listId.uuidString)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.soundName = ""
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await publicDB.save(subscription)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Subscription with this ID already exists — that's fine, nothing to do.
        }
        return subscription
    }

    /// Subscribe to new contributions from collaborators for a given list.
    func subscribeToContributionChanges(listId: UUID) async throws -> CKSubscription {
        let predicate = NSPredicate(format: "listId == %@", listId.uuidString)
        let subscription = CKQuerySubscription(
            recordType: contributionRecordType,
            predicate: predicate,
            subscriptionID: "contributions-\(listId.uuidString)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.soundName = ""
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await publicDB.save(subscription)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Subscription with this ID already exists — that's fine, nothing to do.
        }
        return subscription
    }
    
    // MARK: - Record Conversion
    
    /// Write all list fields onto an existing CKRecord (used for both create and update).
    private func populateListRecord(_ record: CKRecord, from list: RankleList) throws {
        // `listId` mirrors the record name so it can be used in subscription predicates
        record["listId"] = list.id.uuidString
        record["name"] = list.name
        record["items"] = try encodeItems(list.items)
        record["colorRGBA"] = try encodeColor(list.colorRGBA)
        record["isCollaborative"] = list.isCollaborative ? 1 : 0
        record["ownerId"] = list.ownerId.uuidString
        record["collaborators"] = try encodeCollaborators(list.collaborators)
    }
    
    private func listFromRecord(_ record: CKRecord) throws -> RankleList {
        guard let name = record["name"] as? String,
              let itemsData = record["items"] as? String,
              let colorData = record["colorRGBA"] as? String,
              let ownerIdString = record["ownerId"] as? String,
              let ownerId = UUID(uuidString: ownerIdString),
              let isCollaborative = record["isCollaborative"] as? Int else {
            throw CloudKitError.invalidRecord
        }
        
        let items = try decodeItems(itemsData)
        let colorRGBA = try decodeColor(colorData)
        var list = RankleList(id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
                             name: name,
                             items: items,
                             color: colorRGBA.color,
                             isCollaborative: isCollaborative == 1)
        list.ownerId = ownerId
        
        if let collaboratorsData = record["collaborators"] as? String {
            list.collaborators = try decodeCollaborators(collaboratorsData)
        }
        
        return list
    }
    
    private func contributionFromRecord(_ record: CKRecord) throws -> CollaboratorRanking {
        guard let userIdString = record["userId"] as? String,
              let userId = UUID(uuidString: userIdString),
              let rankingString = record["ranking"] as? String,
              let updatedAt = record["updatedAt"] as? Date else {
            throw CloudKitError.invalidRecord
        }
        
        let ranking = rankingString.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        let displayName = record["displayName"] as? String
        
        return CollaboratorRanking(
            userId: userId,
            displayName: displayName,
            ranking: ranking,
            updatedAt: updatedAt
        )
    }
    
    // MARK: - Encoding/Decoding Helpers
    
    private func encodeItems(_ items: [RankleItem]) throws -> String {
        let itemsToEncode = items.map { item in
            RankleItem(id: item.id, title: item.title, media: [])
        }
        let data = try JSONEncoder().encode(itemsToEncode)
        return data.base64EncodedString()
    }
    
    private func decodeItems(_ base64: String) throws -> [RankleItem] {
        guard let data = Data(base64Encoded: base64) else {
            throw CloudKitError.invalidData
        }
        return try JSONDecoder().decode([RankleItem].self, from: data)
    }
    
    private func encodeColor(_ color: RGBAColor) throws -> String {
        let data = try JSONEncoder().encode(color)
        return data.base64EncodedString()
    }
    
    private func decodeColor(_ base64: String) throws -> RGBAColor {
        guard let data = Data(base64Encoded: base64) else {
            throw CloudKitError.invalidData
        }
        return try JSONDecoder().decode(RGBAColor.self, from: data)
    }
    
    private func encodeCollaborators(_ collaborators: [CollaboratorRanking]) throws -> String {
        let data = try JSONEncoder().encode(collaborators)
        return data.base64EncodedString()
    }
    
    private func decodeCollaborators(_ base64: String) throws -> [CollaboratorRanking] {
        guard let data = Data(base64Encoded: base64) else {
            throw CloudKitError.invalidData
        }
        return try JSONDecoder().decode([CollaboratorRanking].self, from: data)
    }
}

enum CloudKitError: Error {
    case invalidRecord
    case invalidData
    case accountNotAvailable
}
