#import <UIKit/UIKit.h>

typedef BOOL (^ZNItemFilter)(NSDictionary *item);

// Список акцій: пошук, сортування, фільтр мінімальної знижки, pull-to-refresh.
@interface ZNDealListViewController : UITableViewController <UISearchBarDelegate, UIActionSheetDelegate>
- (id)initWithTitle:(NSString *)title filter:(ZNItemFilter)filter;
@property (nonatomic, assign) BOOL showsStore;      // показувати назву магазину в клітинках (YES)
@property (nonatomic, copy) NSString *searchText;   // початковий запит (для «слів»)
@end
