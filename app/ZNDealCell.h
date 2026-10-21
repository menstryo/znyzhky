#import <UIKit/UIKit.h>

#define ZN_ACCENT [UIColor colorWithRed:0.80 green:0.13 blue:0.11 alpha:1]

// Підпис із перекресленням (на iOS 6 attributedText погано дружить із підсвіткою клітинки)
@interface ZNStrikeLabel : UILabel
@end

@interface ZNDealCell : UITableViewCell
@property (nonatomic, retain) NSDictionary *item;
@property (nonatomic, assign) BOOL showsStore;   // за замовчуванням YES
+ (CGFloat)height;
@end
