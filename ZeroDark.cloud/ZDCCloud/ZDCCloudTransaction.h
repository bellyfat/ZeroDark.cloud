/**
 * ZeroDark.cloud
 * 
 * Homepage      : https://www.zerodark.cloud
 * GitHub        : https://github.com/4th-ATechnologies/ZeroDark.cloud
 * Documentation : https://zerodarkcloud.readthedocs.io/en/latest/
 * API Reference : https://apis.zerodark.cloud
**/

#import <Foundation/Foundation.h>

#import <YapDatabase/YapDatabaseCloudCoreTransaction.h>
#import <YapDatabase/YapCollectionKey.h>

#import "ZDCCloudLocator.h"
#import "ZDCCloudOperation.h"
#import "ZDCDropboxInvite.h"
#import "ZDCGraftInvite.h"
#import "ZDCNode.h"
#import "ZDCTreesystemPath.h"
#import "ZDCTrunkNode.h"
#import "ZDCUser.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * All errors returned from ZDCCloudTransaction will use an error code defined in this enumeration.
 */
typedef NS_ENUM(NSInteger, ZDCCloudErrorCode) {
	/**
	 * One of the parameters was invalid.
	 * The error description will tell you which parameter, and why it was invalid.
	 */
	ZDCCloudErrorCode_InvalidParameter = 1000,
	
	/**
	 * If you attempt to create a node from a path,
	 * all parents leading up to the last path component must already exist in the treesystem.
	 */
	ZDCCloudErrorCode_MissingParent,
	
	/**
	 * If you attempt to send a message to a user,
	 * the receiving user must exist in the database.
	 *
	 * (You can use the ZDCUserManager to create the user if needed.)
	 */
	ZDCCloudErrorCode_MissingReceiver,
	
	/**
	 * A conflict occurred.
	 * For example, you attempted to create a node at `/foo/bar`, but there's already a node at that path.
	 */
	ZDCCloudErrorCode_Conflict
};

/**
 * Bitmask for specifiying which components that need to be downloaded from the cloud.
 */
typedef NS_OPTIONS(NSUInteger, ZDCNodeComponents) {
	
	/** Bitmask flag that specifies the header should be downloaded. */
	ZDCNodeComponents_Header    = (1 << 0), // 00001
	
	/** Bitmask flag that specifies the metadata section should be downloaded (if present). */
	ZDCNodeComponents_Metadata  = (1 << 1), // 00010
	
	/** Bitmask flag that specifies the thumbnail section should be downloaded (if present). */
	ZDCNodeComponents_Thumbnail = (1 << 2), // 00100
	
	/** Bitmask flag that specifies the data section should be downloaded. */
	ZDCNodeComponents_Data      = (1 << 3), // 01000
	
	/** Bitmask flag that specifies all sections should be downloaded. */
	ZDCNodeComponents_All = (ZDCNodeComponents_Header    |
	                         ZDCNodeComponents_Metadata  |
	                         ZDCNodeComponents_Thumbnail |
	                         ZDCNodeComponents_Data      ) // 01111
};

/**
 * ZDCCloud is a YapDatabase extension.
 *
 * It manages the storage of the upload queue.
 * This allows your application to work offline.
 * Any changes that need to be pushed to the cloud will get stored in the database using
 * a lightweight operation object that encodes the minimum information necessary
 * to execute the operation at a later time.
 *
 * It extends YapDatabaseCloudCore, which we also developed,
 * and contributed to the open source community.
 */
@interface ZDCCloudTransaction : YapDatabaseCloudCoreTransaction

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Node Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the node with the given nodeID.
 *
 * @note You can find many other utility functions for inspecting the node treesystem in the `ZDCNodeManager`.
 *
 * @param nodeID
 *   The identifier of the node. (nodeID == ZDCNode.uuid)
 *
 * @return Returns the matching node, if it exists. Nil otherwise.
 */
- (nullable ZDCNode *)nodeWithID:(NSString *)nodeID
	NS_SWIFT_NAME(node(id:));

/**
 * Returns the existing node with the given path.
 *
 * @note You can find many other utility functions for inspecting the node treesystem in the `ZDCNodeManager`.
 *
 * @param path
 *   The treesystem path of the node.
 *
 * @return Returns the matching node, if it exists. Nil otherwise.
 */
- (nullable ZDCNode *)nodeWithPath:(ZDCTreesystemPath *)path
	NS_SWIFT_NAME(node(path:));

/**
 * Returns the parentNode for the given node.
 */
- (nullable ZDCNode *)parentNode:(ZDCNode *)node;

/**
 * If the given node is a pointer (node.isPointer == true),
 * then this method follows the pointer (recursively, if needed) until the target node is found.
 *
 * If the given node is not a pointer (node.isPointer == false), it simply returns the given node.
 *
 * Only returns nil if:
 * - node is a pointer
 * - node's target doesn't currently exist
 *
 * This method is short-hand for `[ZDCNodeManager targetNodeForNode:transaction:]`
 */
- (nullable ZDCNode *)targetNode:(ZDCNode *)node;

/**
 * Returns the corresponding trunk node (top-level root node).
 *
 * This method is short-hand for `[ZDCNodeManager trunkNodeForLocalUserID:treeID:trunk:transaction:]`
 */
- (nullable ZDCTrunkNode *)trunkNode:(ZDCTreesystemTrunk)trunk;

/**
 * Checks to see if there's already a node occupying the given path.
 * If so, this method will resolve the conflict by appending a number to the end of the nodeName until it's unique.
 * For example, if the given nodeNode is "Foobar.ext", this method may return "Foobar 2.ext".
 */
- (ZDCTreesystemPath *)conflictFreePath:(ZDCTreesystemPath *)path;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Node Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Creates a new node with the given path,
 * and queues upload operation(s) to push the node to the cloud.
 *
 * @param path
 *   The treesystem path of the node.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return The newly created node.
 */
- (nullable ZDCNode *)createNodeWithPath:(ZDCTreesystemPath *)path
                                   error:(NSError *_Nullable *_Nullable)outError
NS_SWIFT_NAME(createNode(withPath:));

/**
 * Creates a new node with the given path,
 * and queues upload operation(s) to push the node to the cloud.
 *
 * @param path
 *   The treesystem path of the node.
 *
 * @param dependencies
 *   If the upload operation should be dependent upon other operations, you may pass those dependencies here.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return The newly created node.
 */
- (nullable ZDCNode *)createNodeWithPath:(ZDCTreesystemPath *)path
                            dependencies:(nullable NSArray<ZDCCloudOperation*> *)dependencies
                                   error:(NSError *_Nullable *_Nullable)outError
NS_SWIFT_NAME(createNode(withPath:dependencies:));

/**
 * Inserts the given node into the treesystem (as configured),
 * and queues upload operation(s) to push the node to the cloud.
 *
 * @param node
 *   The node to insert into the treesystem.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return True on succeess. False otherwise.
 */
- (BOOL)insertNode:(ZDCNode *)node error:(NSError *_Nullable *_Nullable)outError
NS_SWIFT_NAME(insertNode(_:));

/**
 * Use this method to modify an existing node. For example, you can use it to:
 * - rename a node (i.e. you change node.name value)
 * - move a node (i.e. you change node.parentID value)
 * - change permissions (i.e. you modify node.shareList entries)
 *
 * If you didn't change the node metadata, but rather the node data (i.e. the data generated by your app),
 * then you should instead use the `queueDataUploadForNodeID::` method.
 *
 * @param node
 *   The node you want to modify.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return If the request was successful, returns the queued operation.
 *         Otherwise returns nil, in which case, outError will be set.
 */
- (nullable ZDCCloudOperation *)modifyNode:(ZDCNode *)node error:(NSError *_Nullable *_Nullable)outError;

/**
 * Moves the given node to a new location, and queues an operation to push the change to the cloud.
 *
 * On success, this method will change the following properties of the node:
 * - parentID
 * - name
 * - shareList (to match new parent)
 *
 * @param node
 *   The node you want to modify.
 *
 * @param path
 *   The treesystem path of the new location.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return If the request was successful, returns the modified node.
 *         Otherwise returns nil, in which case, outError will be set.
 */
- (nullable ZDCNode *)moveNode:(ZDCNode *)node
                        toPath:(ZDCTreesystemPath *)path
                         error:(NSError *_Nullable *_Nullable)outError;

/**
 * Use this method to queue a data upload operation for the given node.
 *
 * That is, you've modified the underlying data for a node.
 * Now you want the changed data (generated by your app) to be pushed to the cloud.
 * However, the node metadata hasn't changed (name, permissions, etc),
 * so there's no need to use the `modifyNode::` method.
 *
 * Invoking this method will create an return an operation to push the changes to the cloud.
 *
 * @param nodeID
 *   The node for which the data has changed. (nodeID == ZDCNode.uuid)
 *
 * @param changeset
 *   An optional changeset to store within the operation.
 *
 * @return If the request was successful, returns the queued operation.
 *         Otherwise returns nil, in which case, outError will be set.
 */
- (nullable ZDCCloudOperation *)queueDataUploadForNodeID:(NSString *)nodeID
                                           withChangeset:(nullable NSDictionary *)changeset;

/**
 * Removes the given node from the treesystem, and enqueues a delete operation to delete it from the cloud.
 *
 * @param node
 *   The node you want to delete.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return If the request was successful, returns the queued operation.
 *         Otherwise returns nil, in which case, outError will be set.
 */
- (nullable ZDCCloudOperation *)deleteNode:(ZDCNode *)node error:(NSError *_Nullable *_Nullable)outError;

/**
 * Removes the given node from the treesystem, and enqueues a delete operation to delete it from the cloud.
 *
 * @param node
 *   The node which you wish to delete.
 *
 * @param options
 *   A bitmask that specifies the options to use when deleting the node.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return If the request was successful, returns the queued operation.
 *         Otherwise returns nil, in which case, outError will be set.
 */
- (nullable ZDCCloudOperation *)deleteNode:(ZDCNode *)node
                               withOptions:(ZDCDeleteNodeOptions)options
                                     error:(NSError *_Nullable *_Nullable)outError;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Messaging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Enqueues a message to be sent to the specified recipients.
 *
 * Messages are first uploaded into the sender's outbox,
 * and then copied server-side into the recipient's inbox.
 *
 * You supply the data for the message via `[ZeroDarkCloudDelegate dataForNode:atPath:transaction:]`.
 * And you'll be informed of the message deliveries via `[ZeroDarkCloudDelegate didSendMessage:transaction:]`
 *
 * For more information about messaging, see the docs:
 * https://zerodarkcloud.readthedocs.io/en/latest/client/messaging/
 *
 * @param recipients
 *   A list of recipients that should receive the message.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return Returns the message node on success, nil otherwise.
 */
- (nullable ZDCNode *)sendMessageToRecipients:(NSArray<ZDCUser*> *)recipients
                                        error:(NSError *_Nullable *_Nullable)outError;

/**
 * Enqueues a message to be sent to the specified recipients.
 *
 * Messages are first uploaded into the sender's outbox,
 * and then copied server-side into the recipient's inbox.
 *
 * You supply the data for the message via `[ZeroDarkCloudDelegate dataForNode:atPath:transaction:]`.
 * And you'll be informed of the message deliveries via `[ZeroDarkCloudDelegate didSendMessage:transaction:]`
 *
 * For more information about messaging, see the docs:
 * https://zerodarkcloud.readthedocs.io/en/latest/client/messaging/
 *
 * In a collaboration scenario, your message may be dependent upon permissions changes.
 * For example, if Alice wants to share a branch of her treesystem with Bob, this is typically a 2-step process.
 * First Alice must give Bob read-write permission to the branch.
 * And then Alice can send Bob an invitation to collaborate on that branch.
 * This is typically achieved by first using the method `recursiveAddShareItem:forUserID:nodeID`.
 * This method returns an array of ZDCCloudOperations. So then you'd just pass that array of operations
 * to this method as dependencies. This ensures that the treesystem permissions are
 * modified before the message is sent.
 *
 * @param recipients
 *   A list of recipients that should receive the message.
 *
 * @param dependencies
 *   If the message operation should be dependent upon other operations, you may pass those dependencies here.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return Returns the message node on success, nil otherwise.
 */
- (nullable ZDCNode *)sendMessageToRecipients:(NSArray<ZDCUser*> *)recipients
                             withDependencies:(nullable NSArray<ZDCCloudOperation*> *)dependencies
                                        error:(NSError *_Nullable *_Nullable)outError;


/**
 * Enqueues a signal to be sent to the specified recipient.
 *
 * A signal is a lightweight outgoing message. (They're different from normal messaages.)
 *
 * Signals are delivered into the inbox of the recipient *ONLY*.
 * There is NOT a copy of the message within the outbox of the sender.
 * In other words, signals are designed to be minimal, and don't cause additional overhead for the sender.
 *
 * You supply the data for the message via `[ZeroDarkCloudDelegate dataForNode:atPath:transaction:]`.
 * And you'll be informed of the message deliveries via `[ZeroDarkCloudDelegate didSendMessage:transaction:]`
 *
 * For more information about messaging, see the docs:
 * https://zerodarkcloud.readthedocs.io/en/latest/client/messaging/
 *
 * @param recipient
 *   The user to send the message to.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return Returns a signal node on success, nil otherwise.
 */
- (nullable ZDCNode *)sendSignalToRecipient:(ZDCUser *)recipient
                                      error:(NSError *_Nullable *_Nullable)outError;

/**
 * Enqueues a signal to be sent to the specified recipient.
 *
 * A signal is a lightweight outgoing message. (They're different from normal messaages.)
 *
 * Signals are delivered into the inbox of the recipient *ONLY*.
 * There is NOT a copy of the message within the outbox of the sender.
 * In other words, signals are designed to be minimal, and don't cause additional overhead for the sender.
 *
 * You supply the data for the message via `[ZeroDarkCloudDelegate dataForNode:atPath:transaction:]`.
 * And you'll be informed of the message deliveries via `[ZeroDarkCloudDelegate didSendMessage:transaction:]`
 *
 * For more information about messaging, see the docs:
 * https://zerodarkcloud.readthedocs.io/en/latest/client/messaging/
 *
 * @param recipient
 *   The user to send the message to.
 *
 * @param dependencies
 *   If the signal operation should be dependent upon other operations, you may pass those dependencies here.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return Returns a signal node on success, nil otherwise.
 */
- (nullable ZDCNode *)sendSignalToRecipient:(ZDCUser *)recipient
                           withDependencies:(nullable NSArray<ZDCCloudOperation*> *)dependencies
                                      error:(NSError *_Nullable *_Nullable)outError;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Queues an operation to perform a server-side-copy, from the given node, to the recipient's inbox.
 *
 * The given node must be part of the localUser's treesystem.
 *
 * On success, a temporary node is returned.
 * The temporary node isn't part of the treesystem, but it is stored in the database.
 * This node will be automatically deleted after the operation has completed.
 *
 * @param node
 *   The node to copy.
 *
 * @param recipient
 *   The user to send the message to.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return Returns a temporary node on success, nil otherwise.
 */
- (nullable ZDCNode *)copyNode:(ZDCNode *)node
              toRecipientInbox:(ZDCUser *)recipient
                         error:(NSError *_Nullable *_Nullable)outError;

/**
 * Queues an operation to perform a server-side-copy, from the given node, to the recipient's inbox.
 *
 * The given node must be part of the localUser's treesystem.
 *
 * On success, a temporary node is returned.
 * The temporary node isn't part of the treesystem, but it is stored in the database.
 * This node will be automatically deleted after the operation has been completed.
 *
 * @note You can also add dependencies via the `-modifyOperation:` method,
 *       available via the superclass (YapDatabaseCloudCoreTransaction).
 *
 * @param node
 *   The node to copy.
 *
 * @param recipient
 *   The user to send the message to.
 *
 * @param dependencies
 *   If the message operation should be dependent upon other operations, you may pass those dependencies here.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return Returns a temporary node on success, nil otherwise.
 */
- (nullable ZDCNode *)copyNode:(ZDCNode *)node
              toRecipientInbox:(ZDCUser *)recipient
              withDependencies:(nullable NSArray<ZDCCloudOperation*> *)dependencies
                         error:(NSError *_Nullable *_Nullable)outError;

/**
 * Queues an operation to perform a server-side-copy, from the given node, to the recipient's treesystem.
 *
 * The given node must be part of the localUser's treesystem.
 *
 * On success, a temporary node is returned.
 * The temporary node isn't part of the treesystem, but it is stored in the database.
 * This node will be automatically deleted after the operation has been completed.
 *
 * @param node
 *   The node to copy.
 *
 * @param recipient
 *   The user to send the message to.
 *
 * @param nodeName
 *   The name of the destination node.
 *
 * @param parentNode
 *   The parent of the destination node.
 *
 * @return Returns a temporary node on success, nil otherwise.
 */
- (nullable ZDCNode *)copyNode:(ZDCNode *)node
                   toRecipient:(ZDCUser *)recipient
                      withName:(NSString *)nodeName
                    parentNode:(ZDCNode *)parentNode
                         error:(NSError *_Nullable *_Nullable)outError;

/**
 * Queues an operation to perform a server-side-copy, from the given node, to the recipient's treesystem.
 *
 * The given node must be part of the localUser's treesystem.
 *
 * On success, a temporary node is returned.
 * The temporary node isn't part of the treesystem, but it is stored in the database.
 * This node will be automatically deleted after the operation has been completed.
 *
 * @param node
 *   The node to copy.
 *
 * @param recipient
 *   The user to send the message to.
 *
 * @param remoteCloudPath
 *   The destination location to copy the node to.
 *   Typically this information is derived from a dropbox invite.
 *
 * @param shareList
 *   The shareList to use for the destination node.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return Returns a temporary node on success, nil otherwise.
 */
- (nullable ZDCNode *)copyNode:(ZDCNode *)node
                   toRecipient:(ZDCUser *)recipient
               remoteCloudPath:(ZDCCloudPath *)remoteCloudPath
                     shareList:(ZDCShareList *)shareList
                         error:(NSError *_Nullable *_Nullable)outError;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Dropbox
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * A "dropbox invite" encompasses the information required for another user to write into your treesystem.
 *
 * Imagine that Alice has a node in her treesystem at: /foo/bar/filesFromFriends
 *
 * She wants to setup the node as a dropbox for Bob:
 * That is:
 * - Bob should be allowed to write files into this directory
 * - But Bob doesn't have permission to read the files in this directory
 * - And Bob doesn't have permission to delete files from this directory
 *
 * Alice can accomplish this by:
 * - giving Bob write permission on the node
 * - sending Bob a "dropbox invite" for the node
 *
 * What's nice about this system is that Bob doesn't see the parentNode.
 * That is, Bob cannot discover the location of "/foo/bar/filesFromFriends".
 * So he wouldn't be able to determine, for example, who else Alice has given Dropbox permission to.
 *
 * Further, since Bob doesn't have read permission, he won't be able to see the other children of the node.
 * So he also won't be able to determine which other friends have sent Alice files.
 */
- (nullable ZDCDropboxInvite *)dropboxInviteForNode:(ZDCNode *)node;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Grafting
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Grafting allows you to add another user's branch into your own treesystem.
 * It's used for collaboration, as the branch is now shared between multiple users.
 *
 * More information about grafting can be found in the docs:
 * https://zerodarkcloud.readthedocs.io/en/latest/client/collaboration/
 */
- (nullable ZDCGraftInvite *)graftInviteForNode:(ZDCNode *)node;

/**
 * Grafting allows you to add another user's branch into your own treesystem.
 * It's used for collaboration, as the branch is now shared between multiple users.
 *
 * @see `graftInviteForNode:`
 *
 * @param path
 *   The local path for the pointer node.
 *   It will point to the node in the other user's treesystem.
 *
 * @param remoteCloudPath
 *   The location of the node in the other user's treesystem.
 *   Typically this information is delivered to you via a message/signal.
 *   And the remote user typically gets this information via the `graftInviteForNode:` method.
 *
 * @param remoteCloudID
 *   The cloudID of the node in the other user's treesystem.
 *   This parameter allows the system to find the corresponding node,
 *   even if the node gets moved/renamed.
 *
 * @param remoteUser
 *   The owner of the foreign treesystem.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return If the request was successful, returns the newly created node.
 *         Otherwise returns nil, in which case, outError will be set.
 */
- (nullable ZDCNode *)graftNodeWithLocalPath:(ZDCTreesystemPath *)path
                             remoteCloudPath:(ZDCCloudPath *)remoteCloudPath
                               remoteCloudID:(NSString *)remoteCloudID
                                  remoteUser:(ZDCUser *)remoteUser
                                       error:(NSError *_Nullable *_Nullable)outError;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Permissions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Modifies the permissons for a treesystem branch rooted at the specified node.
 *
 * This method adds the given shareItem to the specified node,
 * and all of the node's children, grand-children, etc (recursively).
 *
 * This is a convenience method for modifying a branch of the treesystem.
 * You can accomplish the same thing manually by:
 * - using the NodeManager to recursively enumerate the node
 * - modifying each node.shareList
 * - invoking cloudTransaction.modifyNode to save the changes, and queue the upload
 */
- (NSArray<ZDCCloudOperation*> *)recursiveAddShareItem:(ZDCShareItem *)shareItem
                                             forUserID:(NSString *)userID
                                                nodeID:(NSString *)nodeID
NS_SWIFT_NAME(recursiveAddShareItem(_:forUserID:nodeID:));

/**
 * Modifies the permissons for a treesystem branch rooted at the specified node.
 *
 * This method removes the permissions for the user from the specified node,
 * and all of the node's children, grand-children, etc (recursively).
 *
 * This is a convenience method for modifying a branch of the treesystem.
 * You can accomplish the same thing manually by:
 * - using the NodeManager to recursively enumerate the node
 * - modifying each node.shareList
 * - invoking cloudTransaction.modifyNode to save the changes, and queue the upload
 */
- (NSArray<ZDCCloudOperation*> *)recursiveRemoveShareItemForUserID:(NSString *)userID
                                                            nodeID:(NSString *)nodeID;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Linking
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Call this method to link an object in the database to an existing node.
 *
 * Linking allows you to create a one-to-one mapping between a node, and one of your own database objects.
 *
 * @note If you need one-to-many mappings, you can instead use the tagging feature.
 *       See `setTag:forNodeID:withIdentifier:` for more information.
 *
 * The node must already exist in the database.
 * (If you just created the node, use `createNode:error:` to add it to the database first.)
 *
 * You can link a {collection, key} tuple that doesn't yet exist in the database.
 * However, you must add the corresponding object to the database before the
 * transaction completes, or the linkage will be dropped.
 *
 * @param nodeID
 *   The node that you'd like to link. (nodeID == ZDCNode.uuid)
 *
 * @param key
 *   The key component of the {collection, key} tuple of your own object
 *   that you wish to link to the node.
 *
 * @param collection
 *   The collection component of the {collection, key} tuple of your own object
 *   that you wish to link to the node.
 *
 * @param outError
 *   Set to nil on success.
 *   Otherwise returns an error that explains what went wrong.
 *
 * @return Returns YES if successful, NO otherwise (and sets outError parameter if given).
 */
- (BOOL)linkNodeID:(NSString *)nodeID
             toKey:(NSString *)key
      inCollection:(nullable NSString *)collection
             error:(NSError *_Nullable *_Nullable)outError;

/**
 * If an object in the database has been linked to a node,
 * then deleting that object from the database implicitly
 * creates an operation to delete the node from the cloud.
 *
 * However, this may not always be the desired outcome.
 * Sometimes a device wishes to delete an object simply because it's no longer needed locally.
 * For example, if the object was cached, and the system is clearing unneeded items from the cache.
 * In this case, simply unlink the node manually, and pass `shouldUpload` as NO.
 * This effectively removes the link without modifying the cloud.
 *
 * Alternatively, you may wish to delete a node from the cloud, but keep the local copy.
 * In this case, just use `deleteNode:shouldUpload:operations:`,
 *
 * @param key
 *   The key component of the {collection, key} tuple of your own object
 *   that you wish to link to the node.
 *
 * @param collection
 *   The collection component of the {collection, key} tuple of your own object
 *   that you wish to link to the node.
 *
 * @return If the collection/key tuple was linked to a node, returns the nodeID (after unlinking).
 */
- (nullable NSString *)unlinkKey:(NSString *)key inCollection:(nullable NSString *)collection;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Linked Status
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * If the given collection/key tuple is linked to a node, this method returns the linked nodeID.
 * (nodeID == ZDCNode.uuid)
 */
- (nullable NSString *)linkedNodeIDForKey:(NSString *)key inCollection:(nullable NSString *)collection;

/**
 * If the given collection/key tuple is linked to a node, this method returns the linked node.
 *
 * This is the same as `linkedNodeIDForKey:inCollection:`,
 * but it also fetches the corresponding ZDCNode from the database for you.
 */
- (nullable ZDCNode *)linkedNodeForKey:(NSString *)key inCollection:(nullable NSString *)collection;

/**
 * Returns whether or not the node is currently linked to a {collection, key} tuple.
 *
 * @param nodeID
 *   The node for which to look for a link. (nodeID == ZDCNode.uuid)
 */
- (BOOL)isNodeLinked:(NSString *)nodeID;

/**
 * If the given node is linked to a collection/key tuple, this method returns the linked tuple information.
 *
 * @param key
 *   Returns the key component of the collection/key tuple (if found).
 *
 * @param collection
 *   Returns the collection component of the collection/key tuple (if found).
 *
 * @param nodeID
 *   The node for which to look for a link. (nodeID == ZDCNode.uuid)
 *
 * @return YES if the node is linked to an item in the database. No otherwise.
 */
- (BOOL)getLinkedKey:(NSString *_Nullable *_Nullable)key
          collection:(NSString *_Nullable *_Nullable)collection
           forNodeID:(NSString *)nodeID NS_REFINED_FOR_SWIFT;

/**
 * Combines several API's to return the linked object for a given nodeID.
 *
 * In particular, this method invokes `getLinkedKey:collection:forNodeID:` first.
 * And if that method returns a {collection, key} tuple,
 * then the corresponding object is fetched from the database.
 *
 * @param nodeID
 *   The node for which to look for a link. (nodeID == ZDCNode.uuid)
 *
 * @return If the node is linked to a {collection, key} tuple,
 *         then returns the result of querying the database for the object with the matching tuple.
 *         Otherwise returns nil.
 */
- (nullable id)linkedObjectForNodeID:(NSString *)nodeID;

/**
 * Combines several methods to return the linked object for a given treesystem path.
 *
 * In particular, this method invokes `-[ZDCNodeManager findNodeWithPath:localUserID:treeID:transaction:]` first.
 * And if that method returns a node, then the `linkedObjectForNodeID:` method is utilized.
 *
 * @param path
 *   The treesystem path of the node.
 * 
 * @return If the corresponding node is linked to a {collection, key} tuple,
 *         then returns the result of querying the database for the object with the matching tuple.
 *         Otherwise returns nil.
 */
- (nullable id)linkedObjectForPath:(ZDCTreesystemPath *)path;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Tagging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the currently set tag for the given {nodeID, identifier} tuple.
 *
 * @param nodeID
 *   The associated node. (nodeID == ZDCNode.uuid)
 *
 * @param identifier
 *   A unique identifier for the type of tag being stored.
 *
 * @return
 *   The most recently assigned tag.
 */
- (nullable id)tagForNodeID:(NSString *)nodeID withIdentifier:(NSString *)identifier;

/**
 * Allows you to set or update the current tag value for the given {nodeID, identifier} tuple.
 *
 * @param tag
 *   The tag to store.
 *   The following classes are supported:
 *   - NSString
 *   - NSNumber
 *   - NSData
 *
 * @param nodeID
 *   The associated node. (nodeID == ZDCNode.uuid)
 *
 * @param identifier
 *   A unique identifier for the type of tag being stored.
 *
 * If the given tag is nil, the effect is the same as invoking removeTagForKey:withIdentifier:.
 * If the given tag is an unsupported class, throws an exception.
 */
- (void)setTag:(nullable id)tag forNodeID:(NSString *)nodeID withIdentifier:(NSString *)identifier;

/**
 * Allows you to enumerate the current set of <key, tag> tuples associated with the given node.
 *
 * @param nodeID
 *   The associated node. (nodeID == ZDCNode.uuid)
 */
- (void)enumerateTagsForNodeID:(NSString *)nodeID
                     withBlock:(void (^NS_NOESCAPE)(NSString *identifier, id tag, BOOL *stop))block;

/**
 * Removes the tag for the given {nodeID, key} tuple.
 *
 * Note that this method only removes the specific nodeID+key value.
 * If there are other tags for the same node, but different keys, then those values will remain set.
 * To remove all such values, use removeAllTagsForNode.
 *
 * @param nodeID
 *   The associated node. (nodeID == ZDCNode.uuid)
 *
 * @param identifier
 *   A unique identifier for the type of tag being stored.
 *
 * @see `removeAllTagsForNodeID:`
 */
- (void)removeTagForNodeID:(NSString *)nodeID withIdentifier:(NSString *)identifier;

/**
 * Removes all tags with the given nodeID (matching any identifier).
 */
- (void)removeAllTagsForNodeID:(NSString *)nodeID;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Download Status
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * When the ZeroDarkCloudDelegate is informed of a new/modified node, it may need to download the node's data.
 * However, the download may or may not succeed. And if the download fails,
 * then the delegate will likely want to retry the download later (i.e. when Internet connectivity is restored).
 *
 * This means the delegate will need to keep track of which nodes need to be downloaded.
 * This method is designed to assist in keeping track of that list.
 *
 * @param nodeID
 *   The node needing to be downloaded. (nodeID == ZDCNode.uuid)
 *
 * @param components
 *   Typically you pass ZDCNodeComponents_All to specify that all components of a node are out-of-date.
 *   However, you can customize this in advanced situations.
 */
- (void)markNodeAsNeedsDownload:(NSString *)nodeID components:(ZDCNodeComponents)components
 NS_SWIFT_NAME(markNodeAsNeedsDownload(_:components:));

/**
 * After a download succeeds, invoke this method to remove the flag.
 *
 * @param nodeID
 *   The node you successfully downloaded. (nodeID == ZDCNode.uuid)
 *
 * @param components
 *   Pass ZDCNodeComponents_All to specify that all components are now up-to-date.
 *   However, if you only downloaded one component, such as the thumbnail, then just specify that component.
 *
 * @param eTag
 *   If you pass a non-nil eTag, then the flag will only be removed if ZDCNode.eTag_data matches the given eTag.
 *   You can get the eTag from the DownloadManager's completion block parameter, via `[ZDCCloudDataInfo eTag]`.
 */
- (void)unmarkNodeAsNeedsDownload:(NSString *)nodeID
                       components:(ZDCNodeComponents)components
                    ifETagMatches:(nullable NSString *)eTag
 NS_SWIFT_NAME(unmarkNodeAsNeedsDownload(_:components:ifETagMatches:));

/**
 * Returns YES/true if you've marked the node as needing to be downloaded.
 *
 * A bitwise comparison is performed between the currently marked components, and the passed components parameter.
 * YES is returned if ANY of the components (flags, bits) are currented marked as needing download.
 *
 * @param nodeID
 *   The node in question. (nodeID == ZDCNode.uuid)
 *
 * @param components
 *   The component(s) in question.
 */
- (BOOL)nodeIsMarkedAsNeedsDownload:(NSString *)nodeID components:(ZDCNodeComponents)components
 NS_SWIFT_NAME(nodeIsMarkedAsNeedsDownload(_:components:));

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Operations
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the operations that were added to the push queue in THIS transaction.
 *
 * When you create, modify or delete a node, the system creates and queues operations
 * to push these changes to the cloud. The operations are stored safely in the database,
 * and are executed by the PushManager.
 *
 * Occassionally you may want to tweak an operation's dependencies or priority.
 * You can do that at any time using the underlying functions exposed by YapDatabaseCloudCore.
 *
 * @note ZDCCloudTransaction extends YapDatabaseCloudCoreTransaction.
 *       So you have full access to the public API of YapDatabaseCloudCoreTransaction too.
 */
- (NSArray<ZDCCloudOperation*> *)addedOperations;

/**
 * Returns the operations that were added to the push queue in THIS transaction (for the given nodeID).
 *
 * When you create, modify or delete a node, the system creates and queues operations
 * to push these changes to the cloud. The operations are stored safely in the database,
 * and are executed by the PushManager.
 *
 * Occassionally you may want to tweak an operation's dependencies or priority.
 * You can do that at any time using the underlying functions exposed by YapDatabaseCloudCore.
 *
 * @note ZDCCloudTransaction extends YapDatabaseCloudCoreTransaction.
 *       So you have full access to the public API of YapDatabaseCloudCoreTransaction too.
 *
 * @param nodeID
 *   The node whose operations you're looking for. (nodeID == ZDCNode.uuid)
 */
- (NSArray<ZDCCloudOperation*> *)addedOperationsForNodeID:(NSString *)nodeID;

/**
 * Returns YES if there pending uploads for the given nodeID.
 * This information may be useful in determining why your data is out-of-sync with the cloud.
 */
- (BOOL)hasPendingDataUploadsForNodeID:(NSString *)nodeID;

/**
 * Returns a list of pending ZDCCloudOperations for which:
 * - op.type == ZDCCloudOperationType_Put
 * - op.nodeID matches the list of childNodeIDs for the given parent node.
 *
 * Occassionally you may want to tweak an operation's dependencies or priority.
 * You can do that at any time using the underlying functions exposed by YapDatabaseCloudCore.
 *
 * @note ZDCCloudTransaction extends YapDatabaseCloudCoreTransaction.
 *       So you have full access to the public API of YapDatabaseCloudCoreTransaction too.
 *
 * If this method doesn't do exactly what you want, you can easily create your own version of it.
 * Since ZDCCloudTransaction extends YapDatabaseCloudCoreTransaction,
 * you can use methods such as `[YapDatabaseCloudCoreTransaction enumerateOperationsUsingBlock:]` to perform
 * your own enumeration with your own filters.
 */
- (NSArray<ZDCCloudOperation*> *)pendingPutOperationsWithParentID:(NSString *)parentNodeID;

/**
 * Returns a list of pending ZDCCloudOperations for which:
 * - op.type == ZDCCloudOperationType_CopyLeaf
 * - op.dstCloudLocator matches the given recipients inbox
 *
 * Occassionally you may want to tweak an operation's dependencies or priority.
 * You can do that at any time using the underlying functions exposed by YapDatabaseCloudCore.
 *
 * @note ZDCCloudTransaction extends YapDatabaseCloudCoreTransaction.
 *       So you have full access to the public API of YapDatabaseCloudCoreTransaction too.
 *
 * If this method doesn't do exactly what you want, you can easily create your own version of it.
 * Since ZDCCloudTransaction extends YapDatabaseCloudCoreTransaction,
 * you can use methods such as `[YapDatabaseCloudCoreTransaction enumerateOperationsUsingBlock:]` to perform
 * your own enumeration with your own filters.
 */
- (NSArray<ZDCCloudOperation*> *)pendingCopyOperationsWithRecipientInbox:(ZDCUser *)recipient;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Conflict Resolution
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Enumerates all the operations in the queue,
 * and returns an array of values extracted from ZDCCloudOperation.changeset.
 *
 * If you're using the ZDCSyncable protocol, this is what you'll need to perform a merge.
 *
 * @param nodeID
 *   The node whose operations you're looking for. (nodeID == ZDCNode.uuid)
 */
- (NSArray<NSDictionary*> *)pendingChangesetsForNodeID:(NSString *)nodeID;

/**
 * Invoke this method after you've downloaded and processed the latest version of a node's data.
 *
 * This informs the system that your data is now up-to-date with the given version/eTag.
 * In particular, this tells the system to update all queued ZDCCloudOperation.eTag values.
 *
 * This method is one of the ways in which you can resolve a conflict.
 *
 * @see [ZeroDarkCloudDelegate didDiscoverConflict:forNode:atPath:transaction:]
 */
- (void)didMergeDataWithETag:(NSString *)eTag forNodeID:(NSString *)nodeID;

/**
 * Invoke this method if you've been notified of a conflict, and you've decided to let the cloud version "win".
 * In other words, you've decided not to overwrite the cloud version with the local version.
 *
 * This method is one of the ways in which you can resolve a conflict.
 *
 * @see [ZeroDarkCloudDelegate didDiscoverConflict:forNode:atPath:transaction:]
 */
- (void)skipDataUploadsForNodeID:(NSString *)nodeID;

@end

NS_ASSUME_NONNULL_END
