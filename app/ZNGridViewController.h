#import <UIKit/UIKit.h>

// «Акції»: сітка карток + рядок фільтрів + пошук у навбарі.
// З fixedQuery — режим «слово для відстеження»: усі магазини, без фільтрів.
@interface ZNGridViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
                                                    UISearchBarDelegate, UIActionSheetDelegate>
- (id)init;
- (id)initWithFixedQuery:(NSString *)query;
@end
