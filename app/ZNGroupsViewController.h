#import <UIKit/UIKit.h>

typedef enum { ZNGroupStores = 0, ZNGroupCategories } ZNGroupMode;

// Список магазинів або категорій з кількістю акцій → відкриває відфільтрований список.
@interface ZNGroupsViewController : UITableViewController
- (id)initWithMode:(ZNGroupMode)mode;
@end
