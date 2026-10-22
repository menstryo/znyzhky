#import <UIKit/UIKit.h>

// Локальні сповіщення:
//  • «list»  — завтра/сьогодні закінчується акція на товар зі списку (плануються заздалегідь, працюють без фону);
//  • «words» — з'явились нові акції за словами, що відстежуються;
//  • «cheap» — товар зі списку зараз дешевше в іншій мережі;
//  • «news»  — нова газетка у вашому місті.
// Останні три перевіряються після кожного оновлення даних, зокрема у фоні
// (iOS 7+ — Background Fetch, iOS 6 — keep-alive VoIP раз на ≥10 хв, але оновлення не частіше ніж раз на 2 год).

extern NSString * const ZNNotifyList;
extern NSString * const ZNNotifyWords;
extern NSString * const ZNNotifyCheap;
extern NSString * const ZNNotifyNews;

@interface ZNNotifier : NSObject
+ (ZNNotifier *)shared;
- (void)start;                                   // підписатися на оновлення, перепланувати
- (BOOL)isOn:(NSString *)kind;
- (void)setOn:(BOOL)on kind:(NSString *)kind;
- (void)askPermissionIfNeeded;                    // iOS 8+
- (void)backgroundRefresh:(void (^)(BOOL newData))done;   // оновити дані у фоні й надіслати, що знайшли
- (BOOL)shouldRefreshInBackground;                // минуло ≥ 2 год від останньої перевірки
@end
