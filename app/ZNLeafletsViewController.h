#import <UIKit/UIKit.h>

// «Газетки»: акційні каталоги регіональних мереж для вибраного міста.
@interface ZNLeafletsViewController : UITableViewController
@end

// Перегляд однієї газетки: сторінки одна під одною, тап — збільшити.
@interface ZNLeafletViewController : UITableViewController
- (id)initWithLeaflet:(NSDictionary *)leaflet;
@end

// Вибір міста.
@interface ZNCityPickerViewController : UITableViewController
@property (nonatomic, assign) BOOL modal;   // показано модально (перший запуск)
@end
