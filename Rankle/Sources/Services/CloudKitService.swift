import Foundation
import CloudKit

final class CloudKitService {
    static let shared = CloudKitService()
    
    private let container: CKContainer
    private let privateDB: CKDatabase
    private let publicDB: CKDatabase
    
    // Record types
    private let listRecordType = "RankleList"
    private let contributionRecordType = "CollaboratorRanking"
    
    private init() {
        self.container = CKContainer.default()
        self.privateDB = container.privateCloudDatabase
        self.publicDB = container.publicCloudDatabase
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
    
    // MARK: - Lists
    
    func saveList(_ list: RankleList) async throws {
        let record = try recordFromList(list)
        _ = try await privateDB.save(record)
        // Also save to local storage as backup
        let storage = StorageService()
        storage.saveLists([list])
    }
    
    func fetchList(id: UUID) async throws -> RankleList? {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: .default)
        guard let record = try? await privateDB.record(for: recordID) else {
            return nil
        }
        return try listFromRecord(record)
    }
    
    func fetchAllLists() async throws -> [RankleList] {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: listRecordType, predicate: predicate)
        
        var lists: [RankleList] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            
            if let existingCursor = cursor {
                result = try await privateDB.records(continuingMatchFrom: existingCursor, desiredKeys: nil, resultsLimit: 100)
            } else {
                result = try await privateDB.records(matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100)
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
        
        return lists
    }
    
    func deleteList(id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: .default)
        try await privateDB.deleteRecord(withID: recordID)
    }
    
    // MARK: - Contributions
    
    func saveContribution(_ ranking: CollaboratorRanking, for listId: UUID) async throws {
        let record = try recordFromContribution(ranking, listId: listId)
        _ = try await privateDB.save(record)
        
        // Update local storage
        let storage = StorageService()
        let lists = storage.loadLists()
        if let index = lists.firstIndex(where: { $0.id == listId }) {
            var list = lists[index]
            if let cidx = list.collaborators.firstIndex(where: { $0.userId == ranking.userId }) {
                list.collaborators[cidx] = ranking
            } else {
                list.collaborators.append(ranking)
            }
            let aggregated = storage.aggregateRanking(for: list)
            list.items = aggregated
            storage.saveLists(lists)
        }
    }
    
    func fetchContributions(for listId: UUID) async throws -> [CollaboratorRanking] {
        let predicate = NSPredicate(format: "listId == %@", listId.uuidString)
        let query = CKQuery(recordType: contributionRecordType, predicate: predicate)
        
        var contributions: [CollaboratorRanking] = []
        let result = try await privateDB.records(matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100)
        
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
        
        return contributions
    }
    
    // MARK: - Subscriptions (Real-time updates)
    
    func subscribeToListChanges(listId: UUID) async throws -> CKSubscription {
        let predicate = NSPredicate(format: "recordID.recordName == %@", listId.uuidString)
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
        
        _ = try await privateDB.save(subscription)
        return subscription
    }
    
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
        
        _ = try await privateDB.save(subscription)
        return subscription
    }
    
    // MARK: - Record Conversion
    
    private func recordFromList(_ list: RankleList) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: list.id.uuidString, zoneID: .default)
        let record = CKRecord(recordType: listRecordType, recordID: recordID)
        
        record["name"] = list.name
        record["items"] = try encodeItems(list.items)
        record["colorRGBA"] = try encodeColor(list.colorRGBA)
        record["isCollaborative"] = list.isCollaborative ? 1 : 0
        record["ownerId"] = list.ownerId.uuidString
        record["collaborators"] = try encodeCollaborators(list.collaborators)
        
        return record
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
        var list = RankleList(id: record.recordID.recordName.isEmpty ? UUID() : UUID(uuidString: record.recordID.recordName) ?? UUID(),
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
    
    private func recordFromContribution(_ ranking: CollaboratorRanking, listId: UUID) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: ranking.id.uuidString, zoneID: .default)
        let record = CKRecord(recordType: contributionRecordType, recordID: recordID)
        
        record["userId"] = ranking.userId.uuidString
        record["displayName"] = ranking.displayName
        record["ranking"] = ranking.ranking.map { $0.uuidString }.joined(separator: ",")
        record["updatedAt"] = ranking.updatedAt
        record["listId"] = listId.uuidString
        
        return record
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
            id: record.recordID.recordName.isEmpty ? UUID() : UUID(uuidString: record.recordID.recordName) ?? UUID(),
            userId: userId,
            displayName: displayName,
            ranking: ranking,
            updatedAt: updatedAt
        )
    }
    
    // MARK: - Encoding/Decoding Helpers
    
    private func encodeItems(_ items: [RankleItem]) throws -> String {
        // For collaborative lists, exclude media from items
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

