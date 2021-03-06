/**
 * ZeroDark.cloud
 * 
 * Homepage      : https://www.zerodark.cloud
 * GitHub        : https://github.com/4th-ATechnologies/ZeroDark.cloud
 * Documentation : https://zerodarkcloud.readthedocs.io/en/latest/
 * API Reference : https://apis.zerodark.cloud
**/

#import "ZDCCloudOperation.h"

#import "ZDCCloudLocator.h"
#import "ZDCCloudOperationPrivate.h"
#import "ZDCCloudPath.h"

#import <YapDatabase/YapDatabaseCloudCoreOperationPrivate.h>

/**
 * Constants used for NSCoding
**/
static int const kCurrentVersion = 1;

static NSString *const k_version         = @"version(ZDCCloudOperation)"; // this is a subclass
static NSString *const k_localUserID     = @"localUserID";
static NSString *const k_treeID          = @"treeID";
static NSString *const k_type_str        = @"type_str";
static NSString *const k_putType_str     = @"putType_str";
static NSString *const k_nodeID          = @"nodeID";
static NSString *const k_dstNodeID       = @"dstNodeID";
static NSString *const k_cloudNodeID     = @"cloudNodeID";
static NSString *const k_cloudLocator    = @"cloudLocator";
static NSString *const k_dstCloudLocator = @"dstCloudLocator";
static NSString *const k_eTag            = @"eTag";
static NSString *const k_ifOrphan        = @"ifOrphan";
static NSString *const k_deleteNodeJSON  = @"deleteDirJSON";  // historical name
static NSString *const k_deletedCloudIDs = @"deletedFileIDs"; // historical name
static NSString *const k_avatar_auth0ID  = @"avatar_auth0ID";
static NSString *const k_avatar_oldETag  = @"avatar_oldETag";
static NSString *const k_avatar_newETag  = @"avatar_newETag";
static NSString *const k_changeset_perms = @"changeset_perms";
static NSString *const k_changeset_obj   = @"changeset_obj";
static NSString *const k_multipartInfo   = @"multipartInfo";

static NSString *const k_deprecated_dstCloudPath = @"dstCloudPath";

/**
 * Constants used for converting between enum & string.
**/
static NSString *const type_str_put        = @"put";
static NSString *const type_str_move       = @"move";
static NSString *const type_str_deleteLeaf = @"deleteLeaf";
static NSString *const type_str_deleteNode = @"deleteNode";
static NSString *const type_str_copyLeaf   = @"copyLeaf";
static NSString *const type_str_avatar     = @"avatar";

static NSString *const putType_str_node_rcrd    = @"rcrd";
static NSString *const putType_str_node_data    = @"data";


@implementation ZDCCloudOperation

@synthesize localUserID = localUserID;
@synthesize treeID = treeID;
@synthesize type = type;
@synthesize putType = putType;
@synthesize nodeID = nodeID;
@synthesize dstNodeID = dstNodeID;
@synthesize cloudNodeID = cloudNodeID;
@synthesize cloudLocator = cloudLocator;
@synthesize dstCloudLocator = dstCloudLocator;
@synthesize eTag = eTag;
@synthesize ifOrphan = ifOrphan;
@synthesize deleteNodeJSON = deleteNodeJSON;
@synthesize deletedCloudIDs = deletedCloudIDs;
@synthesize avatar_auth0ID = avatar_auth0ID;
@synthesize avatar_oldETag = avatar_oldETag;
@synthesize avatar_newETag = avatar_newETag;
@synthesize changeset_permissions = changeset_permissions;
@synthesize changeset_obj = changeset_obj;
@synthesize multipartInfo = multipartInfo;
@synthesize ephemeralInfo = ephemeralInfo;

- (instancetype)init
{
	if ((self = [super init]))
	{
		type = ZDCCloudOperationType_Invalid;
		ephemeralInfo = [[ZDCCloudOperation_EphemeralInfo alloc] init];
	}
	return self;
}

- (instancetype)initWithLocalUserID:(NSString *)inLocalUserID
                             treeID:(NSString *)inTreeID
                               type:(ZDCCloudOperationType)inType;
{
	if ((self = [super init]))
	{
		localUserID = [inLocalUserID copy];
		treeID = [inTreeID copy];
		type = inType;
		
		ephemeralInfo = [[ZDCCloudOperation_EphemeralInfo alloc] init];
	}
	return self;
}

- (instancetype)initWithLocalUserID:(NSString *)inLocalUserID
                             treeID:(NSString *)inTreeID
                            putType:(ZDCCloudOperationPutType)inPutType
{
	if ((self = [super init]))
	{
		localUserID = [inLocalUserID copy];
		treeID = [inTreeID copy];
		type = ZDCCloudOperationType_Put;
		putType = inPutType;
		
		ephemeralInfo = [[ZDCCloudOperation_EphemeralInfo alloc] init];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Version History:
 * 
 * 1: Changed dstCloudPath to dstCloudLocator
**/

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder])) // YapDatabaseCloudCoreOperation
	{
		int version = [decoder decodeIntForKey:k_version];
		
		localUserID = [decoder decodeObjectForKey:k_localUserID];
		treeID      = [decoder decodeObjectForKey:k_treeID];
		
		// A note on encoding/decoding enums:
		//
		// I've been through this many times, and here's how this story unfolds:
		//
		//   First, you simply encode the enum as an integer, and write it to disk.
		//   Later, you need to make changes to the enum, and suddenly realize you have to be careful
		//   not to change any values, because they're already persisted to disk.
		//   So you write strongly worded comments letting other developers know they can't change the value.
		//   Over time you end up with a big ugly enum, with a bunch of deprecated values.
		//   Ultimately a programmer accidentally changes a value, even though the comments are there, and checks it in.
		//   You lose several hours debugging the problem.
		//
		// Long story short, it's more maintable if you allow the enum to be easily changed in the future.
		// Which means converting to/from a string while encoding/decoding.
		
		NSString *type_str = [decoder decodeObjectForKey:k_type_str];
		type = [[self class] typeForString:type_str];
		
		NSString *putType_str = [decoder decodeObjectForKey:k_putType_str];
		putType = [[self class] putTypeForString:putType_str];
		
		nodeID      = [decoder decodeObjectForKey:k_nodeID];
		dstNodeID   = [decoder decodeObjectForKey:k_dstNodeID];
		cloudNodeID = [decoder decodeObjectForKey:k_cloudNodeID];
		
		cloudLocator = [decoder decodeObjectForKey:k_cloudLocator];
		
		if (version >= 1)
		{
			dstCloudLocator = [decoder decodeObjectForKey:k_dstCloudLocator];
		}
		else
		{
			ZDCCloudPath *dstCloudPath = nil;
			id value = [decoder decodeObjectForKey:k_deprecated_dstCloudPath];
			
			if ([value isKindOfClass:[NSString class]])
			{
				dstCloudPath = [[ZDCCloudPath alloc] initWithPath:(NSString *)value];
			}
			else if ([value isKindOfClass:[ZDCCloudPath class]])
			{
				dstCloudPath = (ZDCCloudPath *)value;
			}
			
			if (dstCloudPath) {
				dstCloudLocator = [[ZDCCloudLocator alloc] initWithRegion: cloudLocator.region
				                                                   bucket: cloudLocator.bucket
				                                                cloudPath: dstCloudPath];
			}
		}
		
		eTag = [decoder decodeObjectForKey:k_eTag];
		
		ifOrphan = [decoder decodeBoolForKey:k_ifOrphan];
		deleteNodeJSON = [decoder decodeObjectForKey:k_deleteNodeJSON];
		deletedCloudIDs = [decoder decodeObjectForKey:k_deletedCloudIDs];
		
		avatar_auth0ID = [decoder decodeObjectForKey:k_avatar_auth0ID];
		avatar_oldETag = [decoder decodeObjectForKey:k_avatar_oldETag];
		avatar_newETag = [decoder decodeObjectForKey:k_avatar_newETag];
		
		changeset_permissions = [decoder decodeObjectForKey:k_changeset_perms];
		changeset_obj = [decoder decodeObjectForKey:k_changeset_obj];
		
		multipartInfo = [decoder decodeObjectForKey:k_multipartInfo];
		ephemeralInfo = [[ZDCCloudOperation_EphemeralInfo alloc] init];
		
		// Sanity checks:
		
		if ([self.dependencies containsObject:self.uuid])
		{
			NSMutableSet *newDependencies = [self.dependencies mutableCopy];
			[newDependencies removeObject:self.uuid];
			
			self.dependencies = newDependencies;
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder]; // YapDatabaseCloudCoreOperation
	
	if (kCurrentVersion != 0) {
		[coder encodeInt:kCurrentVersion forKey:k_version];
	}
	
	[coder encodeObject:localUserID forKey:k_localUserID];
	[coder encodeObject:treeID      forKey:k_treeID];
	
	if (type != ZDCCloudOperationType_Invalid)
	{
		NSString *type_str = [[self class] stringForType:type];
		[coder encodeObject:type_str forKey:k_type_str];
	}
	
	if (putType != ZDCCloudOperationPutType_Invalid)
	{
		NSString *putType_str = [[self class] stringForPutType:putType];
		[coder encodeObject:putType_str forKey:k_putType_str];
	}
	
	[coder encodeObject:nodeID      forKey:k_nodeID];
	[coder encodeObject:dstNodeID   forKey:k_dstNodeID];
	[coder encodeObject:cloudNodeID forKey:k_cloudNodeID];
	
	[coder encodeObject:cloudLocator forKey:k_cloudLocator];
	[coder encodeObject:dstCloudLocator forKey:k_dstCloudLocator];
	
	[coder encodeObject:eTag forKey:k_eTag];
	
	[coder encodeBool:ifOrphan forKey:k_ifOrphan];
	[coder encodeObject:deleteNodeJSON forKey:k_deleteNodeJSON];
	[coder encodeObject:deletedCloudIDs forKey:k_deletedCloudIDs];
	
	[coder encodeObject:avatar_auth0ID forKey:k_avatar_auth0ID];
	[coder encodeObject:avatar_oldETag forKey:k_avatar_oldETag];
	[coder encodeObject:avatar_newETag forKey:k_avatar_newETag];
	
	[coder encodeObject:changeset_permissions forKey:k_changeset_perms];
	[coder encodeObject:changeset_obj forKey:k_changeset_obj];
	
	[coder encodeObject:multipartInfo forKey:k_multipartInfo];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCopying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (instancetype)copyWithZone:(NSZone *)zone
{
	ZDCCloudOperation *copy = [super copyWithZone:zone]; // YapDatabaseCloudCoreOperation
	
	copy->localUserID = localUserID;
	copy->treeID = treeID;
	
	copy->type = type;
	copy->putType = putType;
	
	copy->nodeID = nodeID;
	copy->dstNodeID = dstNodeID;
	copy->cloudNodeID = cloudNodeID;
	
	copy->cloudLocator = cloudLocator;
	copy->dstCloudLocator = dstCloudLocator;
	
	copy->eTag = eTag;
	
	copy->ifOrphan = ifOrphan;
	copy->deleteNodeJSON = deleteNodeJSON;
	copy->deletedCloudIDs = deletedCloudIDs;
	
	copy->avatar_auth0ID = avatar_auth0ID;
	copy->avatar_oldETag = avatar_oldETag;
	copy->avatar_newETag = avatar_newETag;
	
	copy->changeset_permissions = changeset_permissions;
	copy->changeset_obj = changeset_obj;
	
	copy->multipartInfo = [multipartInfo copy];
	copy->ephemeralInfo = ephemeralInfo; // NO copy! All instances share same ephemeralInfo.
	
	return copy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark YapDatabaseCloudCoreOperation Overrides
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didRejectDependency:(id)badDependency
{
	NSAssert(NO, @"This is probably a typo, which is going to lead to a hard-to-reproduce bug");
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Equality
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)hasSameTarget:(ZDCCloudOperation *)op
{
	if (!YDB_IsEqualOrBothNil(localUserID, op->localUserID)) return NO;
	if (!YDB_IsEqualOrBothNil(treeID, op->treeID)) return NO;
	
	if (type != op->type) return NO;
	if (putType != op->putType) return NO;
	
	if (!YDB_IsEqualOrBothNil(nodeID, op->nodeID)) return NO;
	if (!YDB_IsEqualOrBothNil(dstNodeID, op->dstNodeID)) return NO;
	if (!YDB_IsEqualOrBothNil(cloudNodeID, op->cloudNodeID)) return NO;
	
	if (!YDB_IsEqualOrBothNil(cloudLocator, op->cloudLocator)) return NO;
	if (!YDB_IsEqualOrBothNil(dstCloudLocator, op->dstCloudLocator)) return NO;
	
	if (!YDB_IsEqualOrBothNil(avatar_auth0ID, op->avatar_auth0ID)) return NO;
	
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark General
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)description
{
	NSString *typeStr = nil;
	if (type == ZDCCloudOperationType_Put)
	{
		switch(putType)
		{
			case ZDCCloudOperationPutType_Node_Rcrd    : typeStr = @"Put:Node:Rcrd"; break;
			case ZDCCloudOperationPutType_Node_Data    : typeStr = @"Put:Node:Data"; break;
			default                                    : typeStr = @"Put:?";         break;
		}
	}
	else if (type == ZDCCloudOperationType_Move) {
		typeStr = @"Move";
	}
	else if (type == ZDCCloudOperationType_DeleteLeaf)
	{
		if (ifOrphan) {
			typeStr = @"DeleteLeaf:Orphan";
		} else {
			typeStr = @"DeleteLeaf";
		}
	}
	else if (type == ZDCCloudOperationType_DeleteNode)
	{
		if (ifOrphan) {
			typeStr = @"DeleteNode:Orphan";
		} else {
			typeStr = @"DeleteNode";
		}
	}
	else if (type == ZDCCloudOperationType_CopyLeaf) {
		typeStr = @"CopyLeaf";
	}
	else {
		typeStr = @"?";
	}
	
	return [NSString stringWithFormat:@"<ZDCCloudOperation[%p]: uuid=\"%@\", type=\"%@\">",
	                                     self, self.uuid, typeStr];
}

- (NSString *)debugDescription
{
	NSString *typeStr = nil;
	if (type == ZDCCloudOperationType_Put)
	{
		switch(putType)
		{
			case ZDCCloudOperationPutType_Node_Rcrd    : typeStr = @"Put:Rcrd"; break;
			case ZDCCloudOperationPutType_Node_Data    : typeStr = @"Put:Data"; break;
			default                                    : typeStr = @"Put:?";    break;
		}
	}
	else if (type == ZDCCloudOperationType_Move) {
		typeStr = @"Move";
	}
	else if (type == ZDCCloudOperationType_DeleteLeaf)
	{
		if (ifOrphan) {
			typeStr = @"DeleteLeaf:Orphan";
		} else {
			typeStr = @"DeleteLeaf";
		}
	}
	else if (type == ZDCCloudOperationType_DeleteNode)
	{
		if (ifOrphan) {
			typeStr = @"DeleteNode:Orphan";
		} else {
			typeStr = @"DeleteNode";
		}
	}
	else if (type == ZDCCloudOperationType_CopyLeaf) {
		typeStr = @"CopyLeaf";
	}
	else {
		typeStr = @"?";
	}
	
	NSMutableString *flatDeps = [NSMutableString stringWithCapacity:512];
	NSUInteger i = 0;
	for (NSUUID *uuid in self.dependencies)
	{
		if (i == 0)
			[flatDeps appendString:[uuid UUIDString]];
		else
			[flatDeps appendFormat:@", %@", [uuid UUIDString]];
		
		i++;
	}
	
	return [NSString stringWithFormat:
	  @"<ZDCCloudOperation[%p]: type=\"%@\", uuid=\"%@\", deps=\"%@\", priority=%d>",
	                      self, typeStr, self.uuid, flatDeps, self.priority];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isPutNodeRcrdOperation
{
	return (type == ZDCCloudOperationType_Put) && (putType == ZDCCloudOperationPutType_Node_Rcrd);
}

- (BOOL)isPutNodeDataOperation
{
	return (type == ZDCCloudOperationType_Put) && (putType == ZDCCloudOperationPutType_Node_Data);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Class Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)stringForType:(ZDCCloudOperationType)type
{
	switch(type)
	{
		case ZDCCloudOperationType_Put        : return type_str_put;
		case ZDCCloudOperationType_Move       : return type_str_move;
		case ZDCCloudOperationType_DeleteLeaf : return type_str_deleteLeaf;
		case ZDCCloudOperationType_DeleteNode : return type_str_deleteNode;
		case ZDCCloudOperationType_CopyLeaf   : return type_str_copyLeaf;
		case ZDCCloudOperationType_Avatar     : return type_str_avatar;
		default                               : return @"";
	}
}

+ (ZDCCloudOperationType)typeForString:(NSString *)string
{
	if ([string isEqualToString:type_str_put])        return ZDCCloudOperationType_Put;
	if ([string isEqualToString:type_str_move])       return ZDCCloudOperationType_Move;
	if ([string isEqualToString:type_str_deleteLeaf]) return ZDCCloudOperationType_DeleteLeaf;
	if ([string isEqualToString:type_str_deleteNode]) return ZDCCloudOperationType_DeleteNode;
	if ([string isEqualToString:type_str_copyLeaf])   return ZDCCloudOperationType_CopyLeaf;
	if ([string isEqualToString:type_str_avatar])     return ZDCCloudOperationType_Avatar;
	
	return ZDCCloudOperationType_Invalid;
}

+ (NSString *)stringForPutType:(ZDCCloudOperationPutType)putType
{
	switch(putType)
	{
		case ZDCCloudOperationPutType_Node_Rcrd    : return putType_str_node_rcrd;
		case ZDCCloudOperationPutType_Node_Data    : return putType_str_node_data;
		default                                    : return @"";
	}
}

+ (ZDCCloudOperationPutType)putTypeForString:(NSString *)string
{
	if ([string isEqualToString:putType_str_node_rcrd])    return ZDCCloudOperationPutType_Node_Rcrd;
	if ([string isEqualToString:putType_str_node_data])    return ZDCCloudOperationPutType_Node_Data;
	
	if ([string isEqualToString:@"info"]) return ZDCCloudOperationPutType_Node_Rcrd;
	
	return ZDCCloudOperationPutType_Invalid;
}

@end
