#import <Foundation/Foundation.h>

extern NSString * const ZNStoreDidUpdateNotification;   // дані змінились (успішне оновлення або зміна налаштувань)
extern NSString * const ZNStoreDidFailNotification;     // userInfo[@"error"] — NSError
extern NSString * const ZNStoreLoadingNotification;     // почалось/закінчилось завантаження

// Товар — NSDictionary з JSON:
//   id t p o d u c e i l  (+ додані тут: s — id магазину, k — "s:id", tl — назва в нижньому регістрі)
@interface ZNStore : NSObject

+ (ZNStore *)shared;

@property (nonatomic, readonly) NSArray *items;        // товари увімкнених магазинів зі знижкою ≥ minDiscount, за знижкою
@property (nonatomic, readonly) NSArray *allItems;     // усі товари без фільтрів
@property (nonatomic, readonly) NSArray *stores;       // [{id,name,count,avg,max,ok,updated}]
@property (nonatomic, readonly) NSArray *categories;   // [{id,name,count}]
@property (nonatomic, readonly) NSDate *updatedAt;     // коли дані зібрано на сервері
@property (nonatomic, readonly) NSDate *fetchedAt;     // коли востаннє успішно завантажено
@property (nonatomic, readonly) BOOL loading;

- (void)refresh;
- (void)refreshIfStale;   // якщо дані старші за 30 хв

// налаштування
- (NSString *)serverURL;
- (void)setServerURL:(NSString *)url;
- (BOOL)isStoreEnabled:(NSString *)storeId;
- (void)setStore:(NSString *)storeId enabled:(BOOL)on;
- (NSInteger)minDiscount;
- (void)setMinDiscount:(NSInteger)v;

// довідники
- (NSString *)storeName:(NSString *)storeId;
- (NSString *)categoryName:(NSString *)catId;
- (NSString *)categoryEmoji:(NSString *)catId;
- (NSURL *)imageURLForItem:(NSDictionary *)item;

// обране
- (BOOL)isFavorite:(NSDictionary *)item;
- (void)toggleFavorite:(NSDictionary *)item;
- (NSArray *)favorites;           // актуальні дані, якщо товар ще в акції; інакше збережена копія з ключем "gone"
- (void)removeFavoriteAtIndex:(NSUInteger)idx;

// слова для відстеження
- (NSArray *)watchWords;
- (void)addWatchWord:(NSString *)w;
- (void)removeWatchWordAtIndex:(NSUInteger)idx;
- (NSArray *)itemsMatchingText:(NSString *)text inItems:(NSArray *)items;
- (NSUInteger)watchMatchCount;

@end

// форматування
NSString *ZNPrice(id number);          // 45,99 грн
NSString *ZNDateShort(NSString *iso);  // 2026-10-27 → 27.10
NSInteger ZNDaysLeft(NSString *iso);   // днів до кінця (0 — сьогодні), NSNotFound якщо немає дати
