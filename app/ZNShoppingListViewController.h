#import <UIKit/UIKit.h>

// «Список»: товари, додані з карток, згруповані за магазинами; галочки «куплено»,
// внизу — разом і скільки зекономлено.
@interface ZNShoppingListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>
@end
