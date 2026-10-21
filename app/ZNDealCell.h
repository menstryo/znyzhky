#import <UIKit/UIKit.h>

#import "ZNTheme.h"

// Підпис із перекресленням (на iOS 6 attributedText погано дружить із підсвіткою клітинки)
@interface ZNStrikeLabel : UILabel
@end

@interface ZNDealCell : UITableViewCell
@property (nonatomic, retain) NSDictionary *item;
@property (nonatomic, assign) BOOL showsStore;   // за замовчуванням YES
+ (CGFloat)height;
@end
