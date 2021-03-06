/**
 * ZeroDark.cloud
 * 
 * Homepage      : https://www.zerodark.cloud
 * GitHub        : https://github.com/4th-ATechnologies/ZeroDark.cloud
 * Documentation : https://zerodarkcloud.readthedocs.io/en/latest/
 * API Reference : https://apis.zerodark.cloud
 **/

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kBackupSocialCellIdentifier;

@interface BackupSocialUITableViewCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel        *lblSplit;
@property (nonatomic, weak) IBOutlet UILabel        *lblTitle;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint        *lblTitleCenterOffset;
 @property (nonatomic, weak) IBOutlet UILabel 		*lblDetails;
@property (nonatomic, weak) IBOutlet UILabel 		*lblDate;

@property (nonatomic, copy) NSString *uuid;	// optional value

+(void) registerViewsforTable:(UITableView*)tableView bundle:(nullable NSBundle *)bundle;

+ (CGFloat)heightForCell;

@end

NS_ASSUME_NONNULL_END
