#import <Foundation/Foundation.h>

extern NSString * const ZNStoreDidUpdateNotification;   // змінились дані або фільтри
extern NSString * const ZNStoreDidFailNotification;     // userInfo[@"error"] — NSError
extern NSString * const ZNStoreLoadingNotification;     // почалось/закінчилось завантаження
extern NSString * const ZNStoreListChangedNotification; // змінився список покупок

typedef enum { ZNGroupFood = 0, ZNGroupHome, ZNGroupAll } ZNGroup;
typedef enum { ZNSortSmart = 0, ZNSortDiscount, ZNSortPrice, ZNSortEnding } ZNSort;

// Товар — NSDictionary з JSON:
//   id t p o d u c e i l  (+ додані тут: s — id магазину, k — "s:id", tl — назва в нижньому регістрі, sc — «вигідність»)
@interface ZNStore : NSObject

+ (ZNStore *)shared;

@property (nonatomic, readonly) NSArray *items;        // за поточними фільтрами й сортуванням
@property (nonatomic, readonly) NSArray *allItems;     // усі товари без фільтрів
@property (nonatomic, readonly) NSArray *stores;       // магазини для поточного міста: [{id,name,count,avg,max,ok,updated,city?}]
@property (nonatomic, readonly) NSArray *cities;       // [{id,name,leaflets}]
@property (nonatomic, readonly) NSArray *leaflets;     // газетки поточного міста: [{chain,name,title,from,to,pages:[{i,w,h}]}]
@property (nonatomic, readonly) NSArray *categories;   // [{id,name,count}]
@property (nonatomic, readonly) NSDate *updatedAt;     // коли дані зібрано на сервері
@property (nonatomic, readonly) NSDate *fetchedAt;     // коли востаннє успішно завантажено
@property (nonatomic, readonly) BOOL loading;

- (void)refresh;
- (void)refreshIfStale;   // якщо дані старші за 30 хв

// сервер
- (NSString *)serverURL;
- (void)setServerURL:(NSString *)url;

// місто (міські мережі й газетки)
- (NSString *)cityId;          // nil — ще не вибрано
- (NSString *)cityName;
- (void)setCityId:(NSString *)cityId;
- (NSURL *)urlForPath:(NSString *)relPath;   // картинка газетки тощо

// фільтри (зберігаються між запусками)
- (NSArray *)filterStores;                 // порожньо = усі магазини
- (void)setFilterStores:(NSArray *)ids;
- (ZNGroup)filterGroup;
- (void)setFilterGroup:(ZNGroup)g;
- (NSArray *)filterCategories;             // порожньо = усі категорії групи
- (void)setFilterCategories:(NSArray *)ids;
- (NSInteger)minDiscount;
- (void)setMinDiscount:(NSInteger)v;
- (ZNSort)sortMode;
- (void)setSortMode:(ZNSort)m;
- (void)resetFilters;
- (NSUInteger)activeFilterCount;           // скільки фільтрів відрізняється від стандартних
- (NSArray *)categoryIdsForGroup:(ZNGroup)g;
- (NSUInteger)countForStores:(NSArray *)stores group:(ZNGroup)g categories:(NSArray *)cats minDiscount:(NSInteger)minD;

// довідники
- (NSString *)storeName:(NSString *)storeId;
- (NSString *)categoryName:(NSString *)catId;
- (NSString *)categoryEmoji:(NSString *)catId;
- (NSURL *)imageURLForItem:(NSDictionary *)item;

// список покупок
- (BOOL)isInList:(NSDictionary *)item;
- (void)toggleInList:(NSDictionary *)item;
- (NSArray *)listEntries;                  // актуальні дані + "done"; якщо акція зникла — копія з "gone"
- (void)setDone:(BOOL)done forKey:(NSString *)key;
- (void)removeFromListKey:(NSString *)key;
- (void)clearListOnlyDone:(BOOL)onlyDone;
- (NSUInteger)listOpenCount;               // ще не куплено

// слова для відстеження
- (NSArray *)watchWords;
- (void)addWatchWord:(NSString *)w;
- (void)removeWatchWordAtIndex:(NSUInteger)idx;
- (NSArray *)itemsMatchingText:(NSString *)text inItems:(NSArray *)items;
- (NSUInteger)watchMatchCount;

@end

// форматування
NSString *ZNPrice(id number);          // 45,99 грн
NSString *ZNPriceShort(id number);     // 45,99
NSString *ZNDateShort(NSString *iso);  // 2026-10-27 → 27.10
NSInteger ZNDaysLeft(NSString *iso);   // днів до кінця (0 — сьогодні), NSNotFound якщо немає дати
