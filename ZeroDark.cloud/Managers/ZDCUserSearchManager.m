/**
 * ZeroDark.cloud
 * 
 * Homepage      : https://www.zerodark.cloud
 * GitHub        : https://github.com/4th-ATechnologies/ZeroDark.cloud
 * Documentation : https://zerodarkcloud.readthedocs.io/en/latest/
 * API Reference : https://apis.zerodark.cloud
**/

#import "ZDCUserSearchManagerPrivate.h"

#import "Auth0Utilities.h"
#import "AWSRegions.h"
#import "ZDCConstantsPrivate.h"
#import "ZDCLocalUserManagerPrivate.h"
#import "ZDCLogging.h"
#import "ZeroDarkCloud.h"
#import "ZeroDarkCloudPrivate.h"

// Categories
#import "NSDate+ZeroDark.h"
#import "NSError+ZeroDark.h"
#import "NSString+ZeroDark.h"

// Libraries
#import <YapDatabase/YapCache.h>

// Log Levels: off, error, warning, info, verbose
// Log Flags : trace
#if DEBUG
  static const int zdcLogLevel = ZDCLogLevelWarning;
#else
  static const int zdcLogLevel = ZDCLogLevelWarning;
#endif

#define RESULTS_CACHE_LIMIT 256

@implementation ZDCSearchOptions

@synthesize providerToSearch = providerToSearch;
@synthesize searchLocalDatabase = searchLocalDatabase;
@synthesize searchLocalCache = searchLocalCache;
@synthesize searchRemoteServer = searchRemoteServer;

- (instancetype)init
{
	if ((self = [super init]))
	{
		providerToSearch = @"*";
		searchLocalDatabase = YES;
		searchLocalCache = YES;
		searchRemoteServer = YES;
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ZDCSearchOptions *copy = [[[self class] alloc] init];
	
	copy->providerToSearch    = providerToSearch;
	copy->searchLocalDatabase = searchLocalDatabase;
	copy->searchLocalCache    = searchLocalCache;
	copy->searchRemoteServer  = searchRemoteServer;
	
	return copy;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface ZDCSearchMatch ()

- (instancetype)initWithIdentityID:(NSString *)identityID
                    matchingString:(NSString *)matchingString
                    matchingRanges:(NSArray<NSValue*> *)matchingRanges;

@end

@implementation ZDCSearchMatch

@synthesize identityID = _identityID;
@synthesize matchingString = _matchingString;
@synthesize matchingRanges = _matchingRanges;

- (instancetype)initWithIdentityID:(NSString *)identityID
                    matchingString:(NSString *)matchingString
                    matchingRanges:(NSArray<NSValue*> *)matchingRanges
{
	if ((self = [super init]))
	{
		_identityID = [identityID copy];
		_matchingString = [matchingString copy];
		_matchingRanges = [matchingRanges copy];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ZDCSearchMatch *copy = [[[self class] alloc] init];
	
	copy->_identityID     = _identityID;
	copy->_matchingString = _matchingString;
	copy->_matchingRanges = _matchingRanges;
	
	return copy;
}

- (NSString *)description
{
	return [NSString stringWithFormat:
		@"<%@: %p, identityID: %@, matchingString: %@, rangesFound: %lu>",
		NSStringFromClass([self class]),
		self,
		_identityID,
		_matchingString,
		(unsigned long)_matchingRanges.count];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface ZDCSearchResult  ()

- (instancetype)initWithUser:(ZDCUser *)user;

@property (nonatomic, copy, readwrite) NSString *userID;
@property (nonatomic, assign, readwrite) AWSRegion aws_region;
@property (nonatomic, copy, readwrite) NSString *aws_bucket;
@property (nonatomic, copy, readwrite) NSArray<ZDCUserIdentity*> *identities;
@property (nonatomic, copy, readwrite) NSArray<ZDCSearchMatch*> *matches;

@end

@implementation ZDCSearchResult

@synthesize userID = _userID;
@synthesize aws_region = _aws_region;
@synthesize aws_bucket = _aws_bucket;
@synthesize identities = _identities;
@synthesize matches = _matches;

@synthesize preferredIdentityID = _preferredIdentityID;

@dynamic displayIdentity;


- (instancetype)initWithUser:(ZDCUser *)user
{
	if ((self = [super init]))
	{
		_userID = user.uuid;
		_aws_region = user.aws_region;
		_aws_bucket = user.aws_bucket;
		_identities = user.identities;
		_preferredIdentityID = user.preferredIdentityID;
		
		_matches = [[NSArray alloc] init];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ZDCSearchResult *copy = [[[self class] alloc] init];
	
	copy->_userID = _userID;
	copy->_aws_region = _aws_region;
	copy->_aws_bucket = _aws_bucket;
	copy->_identities = _identities;
	copy->_matches = _matches;
	copy->_preferredIdentityID = _preferredIdentityID;
	
	return copy;
}

- (ZDCUserIdentity *)displayIdentity
{
	if (_preferredIdentityID)
	{
		ZDCUserIdentity *result = [self identityWithID:_preferredIdentityID];
		if (result) {
			return result;
		}
	}
	
	// Prefer a non-recovery-account identity
	//
	for (ZDCUserIdentity *identity in _identities)
	{
		if (identity.isRecoveryAccount){
			continue;
		}
	
		return identity;
	}
		
	return _identities[0];
}

- (nullable ZDCUserIdentity *)identityWithID:(NSString *)identityID
{
	ZDCUserIdentity *match = nil;
	if (identityID)
	{
		for (ZDCUserIdentity *identity in _identities)
		{
			if ([identity.identityID isEqualToString:identityID])
			{
				match = identity;
				break;
			}
		}
	}
	
	return match;
}

- (NSString *)description
{
	return [NSString stringWithFormat:
		@"<%@: %p, userID: %@, region: %@, bucket: %@, identities.count <%lu>",
		NSStringFromClass([self class]), self,
		_userID,
		[AWSRegions shortNameForRegion:_aws_region],
		_aws_bucket,
		(unsigned long)_identities.count
	];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation ZDCUserSearchManager {
	
	__weak ZeroDarkCloud *zdc;
    
	dispatch_queue_t cacheQueue;
	void *IsOnCacheQueueKey;
	
	NSMutableDictionary<NSString*, YapCache*> *cacheDict; // must be accessed from within cacheQueue
}

- (instancetype)init
{
    return nil; // To access this class use: ZeroDarkCloud.directoryManager (or use class methods)
}

- (instancetype)initWithOwner:(ZeroDarkCloud *)inOwner
{
	if ((self = [super init]))
	{
		zdc = inOwner;
		
		cacheQueue = dispatch_queue_create("SearchUserManager.cacheQueue", DISPATCH_QUEUE_SERIAL);
		
		IsOnCacheQueueKey = &IsOnCacheQueueKey;
		dispatch_queue_set_specific(cacheQueue, IsOnCacheQueueKey, IsOnCacheQueueKey, NULL);
		
		cacheDict = [[NSMutableDictionary alloc] init];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * See header file for description.
 */
- (void)flushCache
{
	__weak typeof(self) weakSelf = self;
	dispatch_async(cacheQueue, ^{
		
		__strong typeof(self) strongSelf = weakSelf;
		if (strongSelf)
		{
			[strongSelf->cacheDict removeAllObjects];
		}
	});
}

/**
 * See header file for description.
 */
- (void)searchForUsersWithQuery:(NSString *)inQueryString
                         treeID:(NSString *)inTreeID
                    requesterID:(NSString *)localUserID
                        options:(nullable ZDCSearchOptions *)inOptions
                completionQueue:(nullable dispatch_queue_t)completionQueue
                   resultsBlock:(void (^)(ZDCSearchResultStage stage,
                                          NSArray<ZDCSearchResult*> *_Nullable results,
                                          NSError *_Nullable error))resultsBlock
{
    ZDCLogAutoTrace();
    
	if (!resultsBlock) {
		return;
	}
	
	NSString *queryString = [inQueryString copy]; // mutable string protection
	NSString *treeID      = [inTreeID copy];      // mutable string protection
	
	ZDCSearchOptions *options = inOptions ? [inOptions copy] : [[ZDCSearchOptions alloc] init];
	
	void (^InvokeResultsBlock)(ZDCSearchResultStage, NSArray<ZDCSearchResult*>*, NSError*) =
		^(ZDCSearchResultStage stage, NSArray<ZDCSearchResult*> *results, NSError *error) {
        
		dispatch_async(completionQueue ?: dispatch_get_main_queue(), ^{ @autoreleasepool {
			resultsBlock(stage, results, error);
		}});
	};
    
	if (options.searchLocalDatabase)
	{
		YapDatabaseConnection *roConnection = zdc.databaseManager.roDatabaseConnection;
		[roConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			NSArray<ZDCSearchResult*> *results =
			  [self searchLocalDatabase: queryString
			                withOptions: options
			                transaction: transaction];
			
			InvokeResultsBlock(ZDCSearchResultStage_Database, results, nil);
		}];
	}
	
	if (options.searchLocalCache)
	{
		dispatch_async(cacheQueue, ^{ @autoreleasepool {
			
			NSArray<ZDCSearchResult*> *results =
			  [self searchLocalCache: queryString
				               treeID: treeID
				          withOptions: options];
			
			InvokeResultsBlock(ZDCSearchResultStage_Cache, results, nil);
		}});
	}
	
	if (options.searchRemoteServer)
	{
	/*
        [self searchServerForQuery:queryString
                         forUserID:userID
                   providerFilters:providers
                   completionQueue:inCompletionQueue
                   completionBlock:^(NSArray<ZDCSearchUserResult*> *serverResults, NSError *error) {
                       
                       if(error)
                       {
                           foundResultsBlock(ZDCSearchUserManagerResultStage_Server, nil, error);
                       }
                       else if(serverResults.count)
                       {
                           [serverResults enumerateObjectsUsingBlock:^(ZDCSearchUserResult* result, NSUInteger idx, BOOL * _Nonnull stop) {
                               
                               NSString*  userID = result.uuid;
                               NSDate*   auth0_lastUpdated = result.auth0_lastUpdated;
                               NSDate*   lastDate = [updatedUserIDs objectForKey:userID];
                               
                               if(!lastDate || [lastDate isBefore:auth0_lastUpdated])
                               {
                                  [searchResults addObject:result];
                                   
                                   [updatedUserIDs setObject:auth0_lastUpdated?auth0_lastUpdated:NSDate.distantPast
                                                      forKey:userID];
                               }
                               
                           }];
                           
                           foundResultsBlock(ZDCSearchUserManagerResultStage_Server, searchResults.copy, nil);
                       }
                       
                       // call this when server search is done
                       
                       foundResultsBlock(ZDCSearchUserManagerResultStage_Done, nil, nil);
                       
                   }];
	*/
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Search: Local Database
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray<ZDCSearchResult*> *)searchLocalDatabase:(NSString *)query
                                       withOptions:(ZDCSearchOptions *)options
                                       transaction:(YapDatabaseReadTransaction *)transaction
{
	NSMutableArray<ZDCSearchResult*> *results = [NSMutableArray array];
	
	[transaction enumerateKeysAndObjectsInCollection:kZDCCollection_Users
	                                      usingBlock:^(NSString *uuid, ZDCUser *user, BOOL *stop)
	{
		if (!user.hasRegionAndBucket) {
			return; // from block; continue;
		}
		
		NSArray<ZDCSearchMatch*> *matches =
		  [self matches:query fromIdentities:user.identities withOptions:options];
			
		if (matches.count > 0)
		{
			ZDCSearchResult *result = [[ZDCSearchResult alloc] init];
			result.userID = user.uuid;
			result.aws_bucket = user.aws_bucket;
			result.aws_region = user.aws_region;
			result.identities = user.identities;  // Do we need to filter the recovery account ???
			result.preferredIdentityID = user.preferredIdentityID;
			result.matches = matches;
			
			[results addObject:result];
		}
	}];
	
	return [results copy];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Search: Local Cache
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray<ZDCSearchResult*> *)searchLocalCache:(NSString *)queryString
                                         treeID:(NSString *)treeID
                                    withOptions:(ZDCSearchOptions *)options
{
	NSAssert(dispatch_get_specific(IsOnCacheQueueKey), @"MUST be invoked within the cacheQueue");
	
	NSMutableArray<ZDCSearchResult*> *results = [NSMutableArray array];
	
//	YapCache *cache = cacheDict[treeID];
/*
	[cache enumerateKeysAndObjectsWithBlock:^(NSString *key, ZDCSearchResult *result, BOOL *stop) {
		
		__block BOOL hasMatch = NO;
		
             [auth0_profiles enumerateKeysAndObjectsUsingBlock:^(NSString* profileID, NSDictionary* profile, BOOL * _Nonnull stop2)
              {
                  NSString* email          = [profile objectForKey:@"email"];
                  NSString* name              = [profile objectForKey:@"name"];
                  NSString* username          = [profile objectForKey:@"username"];
                  NSString* nickname       = [profile objectForKey:@"nickname"];
                  BOOL isRecoveryId =  [Auth0Utilities isRecoveryProfile:profile];
                  
                  // process nsdictionary issues
                  if([username isKindOfClass:[NSNull class]])
                      username = nil;
                  if([email isKindOfClass:[NSNull class]])
                      email = nil;
                  if([name isKindOfClass:[NSNull class]])
                      name = nil;
                  if([nickname isKindOfClass:[NSNull class]])
                      nickname = nil;
                  
                  if(!isRecoveryId)
                  {
                      NSArray* comps = [profileID componentsSeparatedByString:@"|"];
                      NSString* provider = comps[0];
                      
                      if(!providers.count || [providers containsObject:provider])
                      {
                          NSString* displayName = nil;
                          
                          if([provider isEqualToString:A0StrategyNameAuth0])
                          {
                              if([Auth0Utilities is4thAEmail:email])
                              {
                                  displayName = [Auth0Utilities usernameFrom4thAEmail:email];
                                  email = nil;
                              }
                          }
                          
                          if(email.length)
                          {
                              email = [email substringToIndex:[email rangeOfString:@"@"].location];
                          }
                          
                          if(!displayName && name.length)
                              displayName =  name;
                          
                          if(!displayName && username.length)
                              displayName =  username;
                          
                          if(!displayName && email.length)
                              displayName =  email;
                          
                          if(!displayName && nickname.length)
                              displayName =  nickname;
                          
                          NSArray *words = [queryString componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
                          
                          if(!hasMatch)
                          {
                              if([self matchesFromString:displayName query:queryString].count == words.count)
                                  hasMatch = YES;
                              else if([self matchesFromString:name query:queryString].count == words.count)
                                  hasMatch = YES;
                              else if([self matchesFromString:username query:queryString].count == words.count)
                                  hasMatch = YES;
                              else if([self matchesFromString:nickname query:queryString].count == words.count)
                                  hasMatch = YES;
                              else if([self matchesFromString:email query:queryString].count == words.count)
                                  hasMatch = YES;
                          }
                          
                          if(hasMatch)
                          {
                              NSArray<ZDCSearchUserMatching*>* matches = [self createMatchingFromProfiles:auth0_profiles
                                                                                              queryString:queryString];
                              if(matches.count)
                              {
                                  result.matches = matches;
                                  [searchResults addObject:result];
                                  *stop2 = YES;
                              }
                          }
                          
                      }
                  };
              }];
             
         }]
        
    });
*/
	return [results copy];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Search: Remote Server
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)searchRemoteServer:(NSString *)queryString
                    treeID:(NSString *)treeID
               requesterID:(NSString *)localUserID
                   options:(ZDCSearchOptions *)options
           completionQueue:(dispatch_queue_t)completionQueue
           completionBlock:(void (^)(NSArray<ZDCSearchResult*> *results, NSError *error))completionBlock
{
	NSParameterAssert(completionQueue != nil);
	NSParameterAssert(completionBlock != nil);
	
	void (^InvokeCompletionBlock)(NSArray<ZDCSearchResult*> *, NSError*) =
		^(NSArray<ZDCSearchResult*> *results, NSError *error)
	{
		dispatch_async(completionQueue, ^{ @autoreleasepool {
			completionBlock(results, error);
		}});
	};
	
  	[zdc.restManager searchUserMatch: queryString
	                        provider: options.providerToSearch
	                          treeID: treeID
	                     requesterID: localUserID
	                 completionQueue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
	                 completionBlock:^(NSURLResponse *response, id responseObject, NSError *error)
	{
		if (error)
		{
			InvokeCompletionBlock(nil, error);
			return;
		}
		
		NSDictionary *responseDict = nil;
		if ([responseObject isKindOfClass:[NSDictionary class]])
		{
			responseDict = (NSDictionary *)responseObject;
		}
		else if ([responseObject isKindOfClass:[NSData class]])
		{
			NSData *data = (NSData *)responseObject;
			
			id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
			if ([value isKindOfClass:[NSDictionary class]]) {
				responseDict = (NSDictionary *)value;
			}
		}
		
		NSArray<ZDCSearchResult*> *results = nil;
		if (responseDict)
		{
			results = [self parseSearchResults:responseDict];
		}
		
		if (results == nil)
		{
			NSString *msg = @"Server returned unexpected response";
			error = [NSError errorWithClass:[self class] code:0 description:msg];
			
			InvokeCompletionBlock(nil, error);
			return;
		}
		
		[self cacheServerResults:results forTreeID:treeID];
		
		// Todo: Finish refactoring
		NSAssert(NO, @"not finished refactoring");
		
	//	InvokeCompletionBlock(results, serverError);
	}];
}

- (nullable NSArray<ZDCSearchResult *> *)parseSearchResults:(NSDictionary *)responseDict
{
	NSMutableArray<ZDCSearchResult*> *parsedResults = nil;
	
	id value = responseDict[@"results"];
	if ([value isKindOfClass:[NSArray class]])
	{
		NSArray *results = (NSArray *)value;
		parsedResults = [NSMutableArray arrayWithCapacity:results.count];
		
		for (id value in results)
		{
			if (![value isKindOfClass:[NSDictionary class]])
			{
				parsedResults = nil;
				break;
			}
			
			ZDCSearchResult *parsed = [self parseSearchResult:(NSDictionary *)value];
			if (!parsed)
			{
				parsedResults = nil;
				break;
			}
			
			[parsedResults addObject:parsed];
		}
	}
	
	return parsedResults;
}

- (nullable ZDCSearchResult *)parseSearchResult:(NSDictionary *)item
{
	id value;
	
	NSString *userID = nil;
	AWSRegion region = AWSRegion_Invalid;
	NSString *bucket = nil;
	
	value = item[@"s4"];
	if ([value isKindOfClass:[NSDictionary class]])
	{
		NSDictionary *s4 = (NSDictionary *)value;
		
		value = s4[@"user_id"];
		if ([value isKindOfClass:[NSString class]])
		{
			userID = (NSString *)value;
		}
		
		value = s4[@"region"];
		if ([value isKindOfClass:[NSString class]])
		{
			region = [AWSRegions regionForName:(NSString *)value];
		}
		
		value = s4[@"bucket"];
		if ([value isKindOfClass:[NSString class]])
		{
			bucket = (NSString *)value;
		}
	}
	
	NSMutableArray<ZDCUserIdentity*> *identities = [NSMutableArray array];
	NSString *preferredIdentityID = nil;
	
	value = item[@"auth0"];
	if ([value isKindOfClass:[NSDictionary class]])
	{
		NSDictionary *auth0 = (NSDictionary *)value;
		
		value = auth0[@"identities"];
		if ([value isKindOfClass:[NSArray class]])
		{
			NSArray<id> *identityDicts = (NSArray *)value;
			
			for (id identityDict in identityDicts)
			{
				if ([identityDict isKindOfClass:[NSDictionary class]])
				{
					ZDCUserIdentity *parsed = [[ZDCUserIdentity alloc] initWithDictionary:identityDict];
					if (parsed)
					{
						[identities addObject:parsed];
					}
				}
			}
		}
		
		value = auth0[@"user_metadata"];
		if ([value isKindOfClass:[NSDictionary class]])
		{
			NSDictionary *userMetadata = (NSDictionary *)value;
			
			value = userMetadata[@"preferredAuth0ID"];
			if ([value isKindOfClass:[NSString class]])
			{
				preferredIdentityID = (NSString *)value;
			}
		}
	}
	
	ZDCSearchResult *result = nil;
	
	if (userID != nil
	 && region != AWSRegion_Invalid
	 && bucket != nil
	 && identities.count > 0)
	{
		result = [[ZDCSearchResult alloc] init];
		
		result.userID = userID;
		result.aws_region = region;
		result.aws_bucket = bucket;
		result.identities = identities;
		result.preferredIdentityID = preferredIdentityID;
		
		result.matches = [NSArray array];
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)cacheServerResults:(NSArray<ZDCSearchResult*> *)results forTreeID:(NSString *)treeID
{
	dispatch_async(cacheQueue, ^{
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wimplicit-retain-self"
		
		YapCache *cache = cacheDict[treeID];
		if (cache == nil)
		{
			cache = [[YapCache alloc] initWithCountLimit:RESULTS_CACHE_LIMIT];
			
		#ifndef NS_BLOCK_ASSERTIONS
			cache.allowedKeyClasses = [NSSet setWithObject:[NSString class]];
			cache.allowedObjectClasses = [NSSet setWithObject:[ZDCSearchResult class]];
		#endif
			
			cacheDict[treeID] = cache;
		}
		
		for (ZDCSearchResult *result in results)
		{
			[cache setObject:result forKey:result.userID];
		}
		
	#pragma clang diagnostic pop
	});
}

- (NSArray<ZDCSearchMatch*> *)matches:(NSString *)query
                       fromIdentities:(NSArray<ZDCUserIdentity*> *)identities
                          withOptions:(ZDCSearchOptions *)options
{
	NSMutableArray<ZDCSearchMatch*> *matches = [NSMutableArray array];
	
	for (ZDCUserIdentity *identity in identities)
	{
		if (identity.isRecoveryAccount) {
			continue;
		}
		
		if (![options.providerToSearch isEqualToString:@"*"] &&
			 [options.providerToSearch caseInsensitiveCompare:identity.provider] != NSOrderedSame) {
			continue;
		}
		
		NSMutableArray *stringsToSearch = [NSMutableArray arrayWithCapacity:5];
		
		[stringsToSearch addObject:identity.displayName];
		
		NSDictionary *profileData = identity.profileData;
		id value;
		
		value = profileData[@"email"];
		if ([value isKindOfClass:[NSString class]])
		{
			NSString *email = (NSString *)value;
			if ([identity.provider isEqualToString:A0StrategyNameAuth0])
			{
				email = [Auth0Utilities usernameFrom4thAEmail:email];
			}
			[stringsToSearch addObject:email];
		}
		
		value = profileData[@"name"];
		if ([value isKindOfClass:[NSString class]])
		{
			NSString *name = (NSString *)value;
			[stringsToSearch addObject:name];
		}
		
		value = profileData[@"username"];
		if ([value isKindOfClass:[NSString class]])
		{
			NSString *username = (NSString *)value;
			[stringsToSearch addObject:username];
		}
		
		value = profileData[@"nickname"];
		if ([value isKindOfClass:[NSString class]])
		{
			NSString *nickname = (NSString *)value;
			[stringsToSearch addObject:nickname];
		}
		
		NSArray *words = [query componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		for (NSString *string in stringsToSearch)
		{
			NSArray<NSValue*> *ranges = [self matchingRanges:query fromString:string];
			if (ranges.count == words.count)
			{
				ZDCSearchMatch *match =
				  [[ZDCSearchMatch alloc] initWithIdentityID: identity.identityID
				                              matchingString: string
				                              matchingRanges: ranges];
		
				[matches addObject:match];
			}
		}
	}
	
	return matches;
}

- (NSArray<NSValue*> *)matchingRanges:(NSString *)query fromString:(NSString *)input
{
	NSArray<NSString*> *possibleWords =
	  [query componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	
	NSMutableArray *words = [NSMutableArray arrayWithCapacity:possibleWords.count];
	for (NSString *word in possibleWords)
	{
		if (word.length > 0) {
			[words addObject:word];
		}
	}
	
	NSMutableArray<NSValue*> *results = nil;
	
	for (NSString *word in words)
	{
		NSRange range = [word rangeOfString: word
		                            options: NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch
		                              range: NSMakeRange(0, word.length)];
        
		if (range.location != NSNotFound)
		{
			if (results == nil) {
				results = [NSMutableArray arrayWithCapacity:words.count];
			}
			[results addObject: [NSValue valueWithRange:range]];
		}
	}
	
	if (results) {
		return [results copy];
	} else {
		return [NSArray array];
	}
}

@end
