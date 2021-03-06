/**
 * ZeroDark.cloud
 * 
 * Homepage      : https://www.zerodark.cloud
 * GitHub        : https://github.com/4th-ATechnologies/ZeroDark.cloud
 * Documentation : https://zerodarkcloud.readthedocs.io/en/latest/
 * API Reference : https://apis.zerodark.cloud
**/

#import "ZDCCloudFileHeader.h"
#import <ZDCSyncableObjC/ZDCObject.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The CloudDataInfo class contains information about the DATA file in the cloud.
 *
 * Recall that the DATA file stores the node's content in the cloud.
 * That is, the data generated by your app via ZeroDarkCloudDelegate.
 * The data is stored in the cloud in an encrypted format.
 */
@interface ZDCCloudDataInfo : ZDCObject <NSCoding, NSCopying>

/**
 * Creates an instance from a decrypted header,
 * along with the corresponding HTTP header values that were returned with the DATA download.
 */
- (instancetype)initWithCloudFileHeader:(ZDCCloudFileHeader)header
                                   eTag:(NSString *)eTag
                           lastModified:(NSDate *)lastModified;

/**
 * The size (in bytes) of the metadata section within the cloud's data file.
 * This corresponds to `[ZeroDarkCloudDelegate metadataForNode:atPath:transaction:]`.
 */
@property (nonatomic, assign, readonly) uint64_t metadataSize;

/**
 * The size (in bytes) of the thumbnail section within the cloud's data file.
 * This corresponds to `[ZeroDarkCloudDelegate thumbnailForNode:atPath:transaction:]`.
 */
@property (nonatomic, assign, readonly) uint64_t thumbnailSize;

/**
 * The size (in bytes) of the main data section within the cloud's data file.
 * This corresponds to `[ZeroDarkCloudDelegate dataForNode:atPath:transaction:]`.
 */
@property (nonatomic, assign, readonly) uint64_t dataSize;

/**
 * It is often the case that a node's data will be updated in the cloud,
 * however the underlying thumbanil isn't changed.
 * For example, the thumbnail for text documents & PDF's is generated from the fist page.
 * So if the first page isn't changed, then the thumbnail hasn't changed.
 *
 * This value allows you to determine if the cloud's thumbnail actually differs
 * from the thumbnail you already have locally.
 */
@property (nonatomic, assign, readonly) uint64_t thumbnailxxHash64;

/** The server's eTag value for the DATA file. */
@property (nonatomic, copy, readonly) NSString *eTag;

/** The server's lastModified value for the DATA file. */
@property (nonatomic, copy, readonly) NSDate *lastModified;

/**
 * Returns a raw struct version, which is used when storing the data in the cloudFile header.
 */
- (ZDCCloudFileHeader)rawHeader;

@end

NS_ASSUME_NONNULL_END
