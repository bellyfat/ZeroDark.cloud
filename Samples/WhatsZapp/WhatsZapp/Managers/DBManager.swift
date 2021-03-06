/// ZeroDark.cloud
///
/// Homepage      : https://www.zerodark.cloud
/// GitHub        : https://github.com/4th-ATechnologies/ZeroDark.cloud
/// Documentation : https://zerodarkcloud.readthedocs.io/en/latest
/// API Reference : https://apis.zerodark.cloud
///
/// Sample App: WhatsZapp

import Foundation
import CocoaLumberjack
import YapDatabase

let DBExt_ConversationsView  = "ConversationsView"
let DBExt_MessagesView       = "MessagesView"
let DBExt_UnreadMessagesView = "UnreadMessagesView"

/// We're using YapDatabase in this example.
/// You don't have to use it (but it's pretty awesome).
///
/// https://github.com/yapstudios/YapDatabase
///
class DBManager {
	
	public static var sharedInstance: DBManager = {
		let dbManager = DBManager()
		return dbManager
	}()
	
	private init() {
		
		// Configure logging level (for CocoaLumberjack)
	#if DEBUG
		dynamicLogLevel = .all
	#else
		dynamicLogLevel = .warning
	#endif
	}
	
	public func configureDatabase(_ database: YapDatabase) {
		
		// YapDatabase allows us to store any objects that conform to Swift's Codable protocol.
		// All we have to do is register the class.
		//
		// YapDatabase is a collection/key/value store.
		// So we're registering the class with the collection in which we're going to store instances of the class.
		//
		database.registerCodableSerialization(Conversation.self, forCollection: kCollection_Conversations)
		database.registerCodableSerialization(Message.self, forCollection: kCollection_Messages)
		
		// In addtion to being a collection/key/value store, YapDatabase comes with a bunch of extensions.
		// These extensions allow us to do a bunch of cool stuff such as:
		// - order & sort items in the database
		// - create various indexes on object properties (for searching, etc)
		// - full text search extension
		// - etc
		//
		registerExtension_ConversationsView(database)
		registerExtension_MessagesView(database)
		registerExtension_UnreadMessagesView(database)
		registerExtension_Hooks(database)
	}
	
	/// In the user interface, we need to display a tableView of all the conversations.
	/// So we want to sort these conversations based on their `lastActivity` property.
	/// We use a `YapDatabaseAutoView` to accomplish this.
	///
	private func registerExtension_ConversationsView(_ database: YapDatabase) -> Void {
		
		// YapDatabaseAutoView is a YapDatabase extension.
		// It allows us to store an ordered list of {collection,key} tuples.
		// Furthermore, the view creates this list automatically using a grouping & sorting block.
		//
		// YapDatabase has extensive documentation for views:
		// https://github.com/yapstudios/YapDatabase/wiki/Views
		//
		// Here's the cliff notes version:
		//
		// Imagine you're storing a large collection of Book's in the databse.
		// You'd like to create a "view" of this data wherein each book is first grouped
		// according to its genre. For example, "fiction", "mystery", "travel", etc.
		// Then, within each genre, you want to sort the books by title, in alphabetical order.
		//
		// So there are 2 tasks:
		// Task 1: GROUP the books by genre
		// Task 2: SORT the books within each genre
		//
		// And this is what we're doing here.
		//
		// The grouping closure allows us to group item in the database.
		// We simply return a string, and the view will place the item into a group that matches this string.
		// From our Books example above, this means we'd return a string like "fiction" or "sci-fi".
		// If you return nil, then the item isn't included any group. (i.e. it gets excluded from the View altogether.)
		//
		// And the sorting block does what you think it does.
		// It sorts 2 items just like any comparison block.
		// And YapDatabaseAutoView uses it to sort all the items in a group.
		// (Just like an Array would use a similar technique to sort the items in an Array.)
		
		// GROUPING CLOSURE:
		//
		// We're only going to have 1 group in our view.
		// So the group name will just be the empty string.
		//
		let grouping = YapDatabaseViewGrouping.withObjectBlock({
			(transaction, collection, key, obj) -> String? in
			
			if let _ = obj as? Conversation {
				return ""
			}
			return nil
		})
		
		// SORTING CLOSURE:
		//
		// Sort the Conversations's by lastActivity.
		//
		let sorting = YapDatabaseViewSorting.withObjectBlock({
			(transaction, group, collection1, key1, obj1, collection2, key2, obj2) -> ComparisonResult in
			
			let conversation1 = obj1 as! Conversation
			let conversation2 = obj2 as! Conversation
			
			let cmp = conversation1.lastActivity.compare(conversation2.lastActivity)
			
			// We want:
			// - Most recent conversation at index 0.
			// - Least recent conversation at the end.
			//
			// This is descending order.
			// But standard comparison order is ascending.
			// So we swap it.
			
			if cmp == .orderedAscending { return .orderedDescending }
			if cmp == .orderedDescending { return .orderedAscending }
			
			return .orderedSame
		})
		
		let version = "1"; // <---------- change me if you modify grouping or sorting closure
		
		let options = YapDatabaseViewOptions()
		options.allowedCollections = YapWhitelistBlacklist(whitelist: Set([kCollection_Conversations]))
		
		let view =
			YapDatabaseAutoView(grouping: grouping,
			                     sorting: sorting,
			                  versionTag: version,
			                     options: options)
		
		let extName = DBExt_ConversationsView
		database.asyncRegister(view, withName: extName) {(ready) in
			
			if !ready {
				DDLogError("Error registering \(extName) !!!")
			}
		}
	}
	
	/// In the user interface, we need to display a tableView of all the messages in a conversation.
	/// So we need to sort these messages based on their `date` property.
	/// We use a `YapDatabaseAutoView` to accomplish this.
	///
	private func registerExtension_MessagesView(_ database: YapDatabase) -> Void {
		
		// YapDatabaseAutoView is described above, in the `registerExtension_conversationsView`
		
		// GROUPING CLOSURE:
		//
		// We're going to group messages by the `conversationID`.
		//
		let grouping = YapDatabaseViewGrouping.withObjectBlock({
			(transaction, collection, key, obj) -> String? in
			
			if let message = obj as? Message {
				return message.conversationID
			}
			return nil
		})
		
		// SORTING CLOSURE:
		//
		// Sort the Messages by date.
		//
		let sorting = YapDatabaseViewSorting.withObjectBlock({
			(transaction, group, collection1, key1, obj1, collection2, key2, obj2) -> ComparisonResult in
			
			let msg1 = obj1 as! Message
			let msg2 = obj2 as! Message
			
			return msg1.date.compare(msg2.date)
		})
		
		let version = "1" // <---------- change me if you modify grouping or sorting closure
		
		let options = YapDatabaseViewOptions()
		options.allowedCollections = YapWhitelistBlacklist(whitelist: Set([kCollection_Messages]))
		
		let view =
			YapDatabaseAutoView(grouping: grouping,
			                     sorting: sorting,
			                  versionTag: version,
			                     options: options)
		
		let extName = DBExt_MessagesView
		database.asyncRegister(view, withName: extName) {(ready) in
			
			if !ready {
				DDLogError("Error registering \(extName) !!!")
			}
		}
	}
	
	/// In the user interface, we need the ability to quickly retrieve the unread count
	/// for a conversation. That is, the number of unread messages within that conversation.
	/// We use a `YapDatabaseFilteredView` to accomplish this.
	///
	private func registerExtension_UnreadMessagesView(_ database: YapDatabase) -> Void {
		
		// YapDatabaseFilteredView simply "filters" another view.
		//
		// So we're just going to filter the MessagesView.
		// Thus the UnreadMessagesView will have the same structure as the MessagesView,
		// but it will only contain unread messages.
		
		let filtering = YapDatabaseViewFiltering.withObjectBlock({
			(transaction, group, collection, key, object) -> Bool in
			
			if let message = object as? Message {
				return (message.isRead == false)
			}
			else {
				return false
			}
		})
		
		let versionTag = "2" // <---------- change me if you modify filtering closure
		
		let view =
		  YapDatabaseFilteredView(parentViewName: DBExt_MessagesView,
		                               filtering: filtering,
		                              versionTag: versionTag)
		
		let extName = DBExt_UnreadMessagesView
		database.asyncRegister(view, withName: extName) {(ready) in
			
			if !ready {
				DDLogError("Error registering \(extName) !!!")
			}
		}
	}
	
	/// We want to automatically update the `Conversation.lastActivity` property.
	/// We can accomplish this with YapDatabaseHooks extension.
	///
	private func registerExtension_Hooks(_ database: YapDatabase) {
		
		// YapDatabaseHooks is a database extension that allows us to inject code when:
		//
		// - willModifyRow     / didModifyRow
		// - willDeleteRow     / didDeleteRow
		// - willDeleteAllRows / didDeleteAllRows
		//
		let hooks = YapDatabaseHooks()
		
		// Game plan:
		//
		// If we insert a new message into a conversation,
		// then let's automatically update the corresponding conversation.lastActivity.
		//
		hooks.didModifyRow = {(transaction, collection, key, proxyObject, proxyMetadata, flags) in
			
			// didModifyRow -> invoked AFTER the row has been modified
			
			guard
				let msg = proxyObject.realObject as? Message,
				var conversation = transaction.conversation(id: msg.conversationID)
			else {
				return
			}
			
			// When a message is inserted or modified, there are 2 things we want to do:
			//
			// 1. Automatically update the conversation.lastActivity
			// 2. Touch the conversation (if needed)
			
			var didUpdateConversation = false
				
			if let msgsViewTransaction = transaction.ext(DBExt_MessagesView) as? YapDatabaseViewTransaction,
				let latestMsg = msgsViewTransaction.lastObject(inGroup: msg.conversationID) as? Message
			{
				// msgsViewTransaction -> This is the YapDatabaseAutoView that we created in
				// the registerExtension_MessagesView() function above.
				//
				// It has all of the messages that belong to the conversation, sorted for us by date.
				// So if we want to find the most recent message in the conversation,
				// we can just ask this view for the lastObject in the conversation group.
				
				let old_lastActivity = conversation.lastActivity
				let new_lastActivity = latestMsg.date
				
				if new_lastActivity != old_lastActivity {
					
					conversation = conversation.copy() as! Conversation
					conversation.lastActivity = new_lastActivity
					
					transaction.setConversation(conversation)
					didUpdateConversation = true
				}
			}
			
			if !didUpdateConversation {
				
				// We want the ConversationsViewController to update properly.
				// However, the ConversationsVC is only monitoring the Conversation objects in the database.
				//
				// That is, it receives a UIDatabaseConnectionDidUpdate notification,
				// and then asks: "Did any Conversation objects change ?"
				//
				// However, if a Message is modified, this might actually affect the ConversationsVC.
				//
				// - A message.isRead changes from false to true.
				//   In this case, the ConversationsVC needs to update the badge count.
				//
				// - A message.isAttachment changes.
				//   If the message is the most recent message in the conversation, this should trigger a cell refresh.
				//
				// Now this all boils down to how we decide to solve these problems.
				// We can code the ConversationsVC to look for these edge cases.
				// Or we can use the Hooks extension to "touch" the Conversation object.
				//
				// A "touch" will get reported to our ConversationsVC as an update for this Conversation object.
				// Which will trigger it to reload the appropriate tableView row.
				
				transaction.touchConversation(id: conversation.uuid)
			}
		}
		
		// Game plan:
		//
		// If we delete the most recent message in a conversation,
		// then let's automatically update the corresponding conversation.lastActivity.
		//
		hooks.willRemoveRow = {(transaction, collection, key) in
			
			// willRemoveRow -> invoked BEFORE the row is deleted
			
			if collection != kCollection_Messages {
				return
			}
			
			guard
				let msg = transaction.message(id: key),
				var conversation = transaction.conversation(id: msg.conversationID)
			else {
				return
			}
			
			var didUpdateConversation = false
			
			if let msgsViewTransaction = transaction.ext(DBExt_MessagesView) as? YapDatabaseViewTransaction,
				let latestMsg = msgsViewTransaction.lastObject(inGroup: msg.conversationID) as? Message
			{
				if latestMsg.uuid == key {
					
					// We're deleting the most recent message in the conversation.
					// So the new conversation.lastActivity becomes either:
					//
					// - the 2nd to last message in the conversation (if available)
					// - epoch
					
					var new_lastActivity = Date(timeIntervalSince1970: 0)
					
					let count = msgsViewTransaction.numberOfItems(inGroup: msg.conversationID)
					if count > 1,
					   let nextMsg = msgsViewTransaction.object(at: count-2, inGroup: msg.conversationID) as? Message {
						
						new_lastActivity = nextMsg.date
					}
					
					conversation = conversation.copy() as! Conversation
					conversation.lastActivity = new_lastActivity
					
					transaction.setConversation(conversation)
					didUpdateConversation = true
				}
			}
			
			if !didUpdateConversation {
				
				transaction.touchConversation(id: conversation.uuid)
			}
		}
		
		let extName = "hooks"
		database.asyncRegister(hooks, withName: extName) {(ready) in
			
			if !ready {
				DDLogError("Error registering \(extName) !!!")
			}
		}
	}
}
