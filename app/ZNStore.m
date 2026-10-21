#import <UIKit/UIKit.h>
#import "ZNStore.h"
#import "ZNRequest.h"

NSString * const ZNStoreDidUpdateNotification = @"ZNStoreDidUpdateNotification";
NSString * const ZNStoreDidFailNotification   = @"ZNStoreDidFailNotification";
NSString * const ZNStoreLoadingNotification   = @"ZNStoreLoadingNotification";
NSString * const ZNStoreListChangedNotification = @"ZNStoreListChangedNotification";

static NSString * const kDefaultServer = @"https://menstryo.github.io/znyzhky";

@interface ZNStore () {
    NSInteger _pending;
    BOOL _failed;
}
@property (nonatomic, retain, readwrite) NSArray *items;
@property (nonatomic, retain, readwrite) NSArray *allItems;
@property (nonatomic, retain, readwrite) NSArray *stores;
@property (nonatomic, retain, readwrite) NSArray *categories;
@property (nonatomic, retain, readwrite) NSArray *cities;
@property (nonatomic, retain, readwrite) NSArray *leaflets;
@property (nonatomic, retain, readwrite) NSDate *updatedAt;
@property (nonatomic, retain, readwrite) NSDate *fetchedAt;
@property (nonatomic, assign, readwrite) BOOL loading;
@property (nonatomic, retain) NSDictionary *itemsByKey;
@end

@implementation ZNStore

@synthesize items = _items, allItems = _allItems, stores = _stores, categories = _categories;
@synthesize cities = _cities, leaflets = _leaflets;
@synthesize updatedAt = _updatedAt, fetchedAt = _fetchedAt, loading = _loading, itemsByKey = _itemsByKey;

+ (ZNStore *)shared {
    static ZNStore *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[ZNStore alloc] init]; });
    return s;
}

- (id)init {
    if ((self = [super init])) {
        [[self d] registerDefaults:@{ @"serverURL": kDefaultServer,
                                      @"minDiscount": @0,
                                      @"fStores": @[],
                                      @"fGroup": @0,
                                      @"fCats": @[],
                                      @"fSort": @0,
                                      @"shopList": @[],
                                      @"watchWords": @[] }];
        _items = [[NSArray alloc] init];
        _allItems = [[NSArray alloc] init];
        _stores = [[NSArray alloc] init];
        _categories = [[NSArray alloc] init];
        _cities = [[NSArray alloc] init];
        _leaflets = [[NSArray alloc] init];
        id f = [[self d] objectForKey:@"fetchedAt"];
        if ([f isKindOfClass:[NSDate class]]) _fetchedAt = [f retain];
        [self rebuildFromCache:nil];
    }
    return self;
}

- (void)dealloc {
    [_items release]; [_allItems release]; [_stores release]; [_categories release]; [_cities release]; [_leaflets release];
    [_updatedAt release]; [_fetchedAt release]; [_itemsByKey release];
    [super dealloc];
}

- (NSUserDefaults *)d { return [NSUserDefaults standardUserDefaults]; }

#pragma mark - settings

- (NSString *)serverURL {
    NSString *s = [[[self d] stringForKey:@"serverURL"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!s.length) s = kDefaultServer;
    while ([s hasSuffix:@"/"]) s = [s substringToIndex:s.length - 1];
    if ([s rangeOfString:@"://"].location == NSNotFound) s = [@"https://" stringByAppendingString:s];
    return s;
}
- (void)setServerURL:(NSString *)url {
    [[self d] setObject:(url ?: @"") forKey:@"serverURL"];
    [[self d] synchronize];
}

#pragma mark - filters

static NSArray *ZNFoodCats(void) {
    return @[@"fruits", @"meat", @"dairy", @"bread", @"grocery", @"frozen", @"sweets", @"snacks", @"drinks", @"alcohol"];
}

- (NSArray *)categoryIdsForGroup:(ZNGroup)g {
    NSArray *food = ZNFoodCats();
    NSMutableArray *out = [NSMutableArray array];
    NSArray *all = self.categories.count ? [self.categories valueForKey:@"id"]
        : [food arrayByAddingObjectsFromArray:@[@"chem", @"beauty", @"kids", @"pets", @"home", @"other"]];
    for (NSString *c in all) {
        BOOL isFood = [food containsObject:c];
        if (g == ZNGroupAll || (g == ZNGroupFood && isFood) || (g == ZNGroupHome && !isFood)) [out addObject:c];
    }
    return out;
}

- (NSArray *)filterStores { return [[self d] arrayForKey:@"fStores"] ?: @[]; }
- (void)setFilterStores:(NSArray *)ids { [[self d] setObject:ids ?: @[] forKey:@"fStores"]; [self saveAndApply]; }
- (ZNGroup)filterGroup { return (ZNGroup)[[self d] integerForKey:@"fGroup"]; }
- (void)setFilterGroup:(ZNGroup)g {
    [[self d] setInteger:g forKey:@"fGroup"];
    [[self d] setObject:@[] forKey:@"fCats"]; // категорії іншої групи вже не мають сенсу
    [self saveAndApply];
}
- (NSArray *)filterCategories { return [[self d] arrayForKey:@"fCats"] ?: @[]; }
- (void)setFilterCategories:(NSArray *)ids { [[self d] setObject:ids ?: @[] forKey:@"fCats"]; [self saveAndApply]; }
- (NSInteger)minDiscount { return [[self d] integerForKey:@"minDiscount"]; }
- (void)setMinDiscount:(NSInteger)v { [[self d] setInteger:v forKey:@"minDiscount"]; [self saveAndApply]; }
- (ZNSort)sortMode { return (ZNSort)[[self d] integerForKey:@"fSort"]; }
- (void)setSortMode:(ZNSort)m { [[self d] setInteger:m forKey:@"fSort"]; [self saveAndApply]; }

- (void)resetFilters {
    NSUserDefaults *d = [self d];
    [d setObject:@[] forKey:@"fStores"];
    [d setInteger:ZNGroupFood forKey:@"fGroup"];
    [d setObject:@[] forKey:@"fCats"];
    [d setInteger:0 forKey:@"minDiscount"];
    [d setInteger:ZNSortSmart forKey:@"fSort"];
    [self saveAndApply];
}

- (NSUInteger)activeFilterCount {
    NSUInteger n = 0;
    if (self.filterStores.count) n++;
    if (self.filterGroup != ZNGroupFood) n++;
    if (self.filterCategories.count) n++;
    if (self.minDiscount > 0) n++;
    return n;
}

- (void)saveAndApply {
    [[self d] synchronize];
    [self applyFilters];
}

#pragma mark - lookups

- (NSString *)storeName:(NSString *)storeId {
    for (NSDictionary *s in self.stores) if ([[s objectForKey:@"id"] isEqual:storeId]) return [s objectForKey:@"name"];
    NSDictionary *fallback = @{ @"silpo": @"Сільпо", @"atb": @"АТБ", @"varus": @"Varus", @"avrora": @"Аврора" };
    return [fallback objectForKey:storeId] ?: storeId;
}

- (NSString *)categoryName:(NSString *)catId {
    for (NSDictionary *c in self.categories) if ([[c objectForKey:@"id"] isEqual:catId]) return [c objectForKey:@"name"];
    return catId;
}

- (NSString *)categoryEmoji:(NSString *)catId {
    // лише емодзі з Unicode 6.0 — інакше на iOS 6 будуть квадратики
    static NSDictionary *m = nil;
    if (!m) m = [@{ @"fruits": @"🍎", @"meat": @"🍖", @"dairy": @"🐄", @"bread": @"🍞", @"grocery": @"🍚",
                    @"frozen": @"❄️", @"sweets": @"🍫", @"snacks": @"🍟", @"drinks": @"☕", @"alcohol": @"🍷",
                    @"chem": @"💧", @"beauty": @"💄", @"kids": @"🎈", @"pets": @"🐱", @"home": @"🏠",
                    @"other": @"📦" } retain];
    return [m objectForKey:catId] ?: @"📦";
}

- (NSURL *)imageURLForItem:(NSDictionary *)item {
    NSString *i = [item objectForKey:@"i"];
    if (![i isKindOfClass:[NSString class]] || !i.length) return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.serverURL, i]];
}

#pragma mark - cache files

- (NSString *)cacheDir {
    NSString *dir = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]
                     stringByAppendingPathComponent:@"data"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    return dir;
}
- (NSString *)indexPath { return [[self cacheDir] stringByAppendingPathComponent:@"index.json"]; }
- (NSString *)pathForLeaflets:(NSString *)city {
    return [[self cacheDir] stringByAppendingPathComponent:[NSString stringWithFormat:@"leaflets-%@.json", city]];
}

#pragma mark - city

- (NSString *)cityId {
    NSString *c = [[self d] stringForKey:@"cityId"];
    return c.length ? c : nil;
}

- (NSString *)cityName {
    NSString *cid = self.cityId;
    if (!cid) return nil;
    for (NSDictionary *c in self.cities) if ([[c objectForKey:@"id"] isEqual:cid]) return [c objectForKey:@"name"];
    return cid;
}

- (void)setCityId:(NSString *)cityId {
    if ([cityId isEqualToString:self.cityId]) return;
    [[self d] setObject:cityId ?: @"" forKey:@"cityId"];
    [[self d] setObject:@[] forKey:@"fStores"]; // магазини іншого міста у фільтрі вже не мають сенсу
    [[self d] synchronize];
    [self rebuildFromCache:^{ [self refresh]; }];
}

- (NSURL *)urlForPath:(NSString *)relPath {
    if (![relPath isKindOfClass:[NSString class]] || !relPath.length) return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.serverURL, relPath]];
}

// магазин показуємо, якщо він загальнонаціональний або з вибраного міста
- (BOOL)storeVisible:(NSDictionary *)s {
    NSString *city = [s objectForKey:@"city"];
    if (![city isKindOfClass:[NSString class]]) return YES;
    return [city isEqualToString:self.cityId];
}

- (NSString *)pathForStore:(NSString *)sid {
    return [[self cacheDir] stringByAppendingPathComponent:[NSString stringWithFormat:@"store-%@.json", sid]];
}

// «Вигідні»: відсоток знижки, зважений на реальну економію в гривнях —
// щоб декор за 2 грн «−99%» не витісняв сир за 19,90 замість 99,90.
static double ZNSmartScore(NSDictionary *it) {
    double p = [[it objectForKey:@"p"] doubleValue], o = [[it objectForKey:@"o"] doubleValue];
    double d = [[it objectForKey:@"d"] doubleValue];
    double saving = MAX(0, o - p);
    double w = MIN(1.0, sqrt(saving / 60.0));
    if (p < 10) w *= 0.35;
    return d * w;
}

static NSString *ZNTodayISO(void) {
    NSDateComponents *c = [[NSCalendar currentCalendar] components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:[NSDate date]];
    return [NSString stringWithFormat:@"%04ld-%02ld-%02ld", (long)c.year, (long)c.month, (long)c.day];
}

static id ZNParse(NSData *data) {
    if (!data.length) return nil;
    id j = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [j isKindOfClass:[NSDictionary class]] ? j : nil;
}

static NSDate *ZNParseISODate(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || s.length < 19) return nil;
    static NSDateFormatter *f = nil;
    if (!f) {
        f = [[NSDateFormatter alloc] init];
        f.locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
        f.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        f.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
    }
    return [f dateFromString:[s substringToIndex:19]];
}

#pragma mark - network

- (void)refreshIfStale {
    if (!self.fetchedAt || [[NSDate date] timeIntervalSinceDate:self.fetchedAt] > 30 * 60 || !self.allItems.count) [self refresh];
}

- (void)setLoadingState:(BOOL)v {
    self.loading = v;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:v];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZNStoreLoadingNotification object:self];
}

- (NSMutableURLRequest *)requestForPath:(NSString *)path {
    NSString *u = [NSString stringWithFormat:@"%@/%@?t=%.0f", self.serverURL, path, [[NSDate date] timeIntervalSince1970]];
    return ZNMakeRequest([NSURL URLWithString:u], NSURLRequestReloadIgnoringLocalCacheData, 30);
}

- (void)fail:(NSError *)err {
    if (_failed) return;
    _failed = YES;
    NSError *e = err ?: [NSError errorWithDomain:@"Znyzhky" code:1
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Не вдалося завантажити дані" }];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZNStoreDidFailNotification object:self
                                                      userInfo:@{ @"error": e }];
}

- (void)refresh {
    if (self.loading) return;
    _failed = NO;
    [self setLoadingState:YES];
    [ZNRequest start:[self requestForPath:@"index.json"] done:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSInteger code = ZNStatusCode(resp);
        NSDictionary *index = (code == 200) ? ZNParse(data) : nil;
        if (!index) {
            [self fail:err];
            [self setLoadingState:NO];
            return;
        }
        // старий index — щоб не тягнути магазини, які не змінились
        NSDictionary *old = ZNParse([NSData dataWithContentsOfFile:[self indexPath]]);
        NSMutableDictionary *oldUpdated = [NSMutableDictionary dictionary];
        for (NSDictionary *s in [old objectForKey:@"stores"]) {
            id u = [s objectForKey:@"updated"];
            if ([u isKindOfClass:[NSString class]]) [oldUpdated setObject:u forKey:[s objectForKey:@"id"]];
        }
        [data writeToFile:[self indexPath] atomically:YES];

        _pending = 0;
        for (NSDictionary *s in [index objectForKey:@"stores"]) {
            NSString *sid = [s objectForKey:@"id"];
            id upd = [s objectForKey:@"updated"];
            if (![sid isKindOfClass:[NSString class]] || [[s objectForKey:@"count"] integerValue] == 0) continue;
            if (![self storeVisible:s]) continue;
            BOOL have = [[NSFileManager defaultManager] fileExistsAtPath:[self pathForStore:sid]];
            if (have && [upd isKindOfClass:[NSString class]] && [upd isEqualToString:[oldUpdated objectForKey:sid]]) continue;
            _pending++;
            NSString *p = [NSString stringWithFormat:@"store/%@.json", sid];
            [ZNRequest start:[self requestForPath:p] done:^(NSURLResponse *r2, NSData *d2, NSError *e2) {
                NSInteger c2 = ZNStatusCode(r2);
                if (c2 == 200 && ZNParse(d2)) [d2 writeToFile:[self pathForStore:sid] atomically:YES];
                else [self fail:e2];
                if (--_pending == 0) [self finishRefresh];
            }];
        }
        // газетки міста — файл невеликий, тягнемо щоразу
        NSString *city = self.cityId;
        if (city) {
            _pending++;
            NSString *p = [NSString stringWithFormat:@"leaflets/%@.json", city];
            [ZNRequest start:[self requestForPath:p] done:^(NSURLResponse *r2, NSData *d2, NSError *e2) {
                if (ZNStatusCode(r2) == 200 && ZNParse(d2)) [d2 writeToFile:[self pathForLeaflets:city] atomically:YES];
                if (--_pending == 0) [self finishRefresh];
            }];
        }
        if (_pending == 0) [self finishRefresh];
    }];
}

- (void)finishRefresh {
    if (!_failed) {
        self.fetchedAt = [NSDate date];
        [[self d] setObject:self.fetchedAt forKey:@"fetchedAt"];
        [[self d] synchronize];
    }
    [self rebuildFromCache:^{ [self setLoadingState:NO]; }];
}

#pragma mark - rebuild

- (void)rebuildFromCache:(void (^)(void))done {
    void (^doneCopy)(void) = [done copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSDictionary *index = ZNParse([NSData dataWithContentsOfFile:[self indexPath]]);
        NSMutableArray *all = [NSMutableArray arrayWithCapacity:8000];
        NSMutableDictionary *byKey = [NSMutableDictionary dictionaryWithCapacity:8000];
        NSMutableArray *visible = [NSMutableArray array];
        for (NSDictionary *s in [index objectForKey:@"stores"]) {
            NSString *sid = [s objectForKey:@"id"];
            if (![sid isKindOfClass:[NSString class]]) continue;
            if (![self storeVisible:s]) continue;
            [visible addObject:s];
            NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
            NSDictionary *j = ZNParse([NSData dataWithContentsOfFile:[self pathForStore:sid]]);
            for (NSDictionary *it in [j objectForKey:@"items"]) {
                if (![it isKindOfClass:[NSDictionary class]]) continue;
                NSMutableDictionary *m = [it mutableCopy];
                NSString *key = [NSString stringWithFormat:@"%@:%@", sid, [it objectForKey:@"id"]];
                [m setObject:sid forKey:@"s"];
                [m setObject:key forKey:@"k"];
                [m setObject:[[it objectForKey:@"t"] lowercaseString] ?: @"" forKey:@"tl"];
                [m setObject:@(ZNSmartScore(it)) forKey:@"sc"];
                [all addObject:m];
                [byKey setObject:m forKey:key];
                [m release];
            }
            [inner release];
        }
        [all sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            NSInteger da = [[a objectForKey:@"d"] integerValue], db = [[b objectForKey:@"d"] integerValue];
            if (da != db) return da > db ? NSOrderedAscending : NSOrderedDescending;
            return [[a objectForKey:@"p"] compare:[b objectForKey:@"p"]];
        }];
        NSArray *stores = visible;
        NSArray *cats = [index objectForKey:@"cats"] ?: @[];
        NSArray *cities = [index objectForKey:@"cities"] ?: @[];
        NSString *city = self.cityId;
        NSArray *lfs = city ? [ZNParse([NSData dataWithContentsOfFile:[self pathForLeaflets:city]]) objectForKey:@"leaflets"] : nil;
        if (![lfs isKindOfClass:[NSArray class]]) lfs = @[];
        // прострочені газетки не показуємо
        NSMutableArray *fresh = [NSMutableArray array];
        NSString *today = ZNTodayISO();
        for (NSDictionary *l in lfs) {
            NSString *to = [l objectForKey:@"to"];
            if ([to isKindOfClass:[NSString class]] && [to compare:today] == NSOrderedAscending) continue;
            [fresh addObject:l];
        }
        lfs = fresh;
        [cities retain]; [lfs retain];
        NSDate *upd = ZNParseISODate([index objectForKey:@"updated"]);
        [all retain]; [byKey retain]; [stores retain]; [cats retain]; [upd retain];
        [pool release];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allItems = all;
            self.itemsByKey = byKey;
            self.stores = stores;
            self.categories = cats;
            self.cities = cities;
            self.leaflets = lfs;
            [cities release]; [lfs release];
            if (upd) self.updatedAt = upd;
            [all release]; [byKey release]; [stores release]; [cats release]; [upd release];
            [self applyFilters];
            if (doneCopy) doneCopy();
            [doneCopy release];
        });
    });
}

static BOOL ZNPasses(NSDictionary *it, NSArray *stores, NSArray *cats, NSInteger minD) {
    if ([[it objectForKey:@"d"] integerValue] < minD) return NO;
    if (stores.count && ![stores containsObject:[it objectForKey:@"s"]]) return NO;
    if (cats && ![cats containsObject:[it objectForKey:@"c"]]) return NO;
    return YES;
}

- (NSArray *)catsFor:(ZNGroup)g selected:(NSArray *)sel {
    if (sel.count) return sel;
    return g == ZNGroupAll ? nil : [self categoryIdsForGroup:g];
}

- (NSUInteger)countForStores:(NSArray *)stores group:(ZNGroup)g categories:(NSArray *)cats minDiscount:(NSInteger)minD {
    NSArray *c = [self catsFor:g selected:cats];
    NSUInteger n = 0;
    for (NSDictionary *it in self.allItems) if (ZNPasses(it, stores, c, minD)) n++;
    return n;
}

- (void)applyFilters {
    NSArray *stores = self.filterStores;
    NSArray *cats = [self catsFor:self.filterGroup selected:self.filterCategories];
    NSInteger minD = self.minDiscount;
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:self.allItems.count];
    for (NSDictionary *it in self.allItems) if (ZNPasses(it, stores, cats, minD)) [out addObject:it];

    ZNSort mode = self.sortMode;
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        if (mode == ZNSortPrice) return [[a objectForKey:@"p"] compare:[b objectForKey:@"p"]];
        if (mode == ZNSortDiscount) {
            NSComparisonResult r = [[b objectForKey:@"d"] compare:[a objectForKey:@"d"]];
            return r != NSOrderedSame ? r : [[a objectForKey:@"p"] compare:[b objectForKey:@"p"]];
        }
        if (mode == ZNSortEnding) {
            // з датою — першими, найближчі зверху
            NSString *ea = [a objectForKey:@"e"], *eb = [b objectForKey:@"e"];
            if (ea && !eb) return NSOrderedAscending;
            if (!ea && eb) return NSOrderedDescending;
            if (ea && eb) { NSComparisonResult r = [ea compare:eb]; if (r != NSOrderedSame) return r; }
        }
        return [[b objectForKey:@"sc"] compare:[a objectForKey:@"sc"]];
    }];
    if (mode == ZNSortEnding) {
        // минулі дати (прострочені в кеші) прибираємо
        NSMutableArray *fresh = [NSMutableArray arrayWithCapacity:out.count];
        for (NSDictionary *it in out) {
            NSInteger left = ZNDaysLeft([it objectForKey:@"e"]);
            if (left == NSNotFound || left >= 0) [fresh addObject:it];
        }
        out = fresh;
    }
    self.items = out;
    [[NSNotificationCenter defaultCenter] postNotificationName:ZNStoreDidUpdateNotification object:self];
}

#pragma mark - shopping list

- (NSArray *)listRaw { return [[self d] arrayForKey:@"shopList"] ?: @[]; }

- (void)saveList:(NSArray *)a {
    [[self d] setObject:a forKey:@"shopList"];
    [[self d] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZNStoreListChangedNotification object:self];
}

- (BOOL)isInList:(NSDictionary *)item {
    NSString *k = [item objectForKey:@"k"];
    for (NSDictionary *f in [self listRaw]) if ([[f objectForKey:@"k"] isEqual:k]) return YES;
    return NO;
}

- (void)toggleInList:(NSDictionary *)item {
    NSString *k = [item objectForKey:@"k"];
    if (!k) return;
    NSMutableArray *a = [[[self listRaw] mutableCopy] autorelease];
    for (NSUInteger i = 0; i < a.count; i++) {
        if ([[[a objectAtIndex:i] objectForKey:@"k"] isEqual:k]) {
            [a removeObjectAtIndex:i];
            [self saveList:a];
            return;
        }
    }
    // копія без службових полів (лише plist-сумісні значення)
    NSMutableDictionary *snap = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"id", @"t", @"p", @"o", @"d", @"u", @"c", @"e", @"i", @"l", @"s", @"k"]) {
        id v = [item objectForKey:key];
        if ([v isKindOfClass:[NSString class]] || [v isKindOfClass:[NSNumber class]]) [snap setObject:v forKey:key];
    }
    [snap setObject:@NO forKey:@"done"];
    [a addObject:snap];
    [self saveList:a];
}

- (NSArray *)listEntries {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *f in [self listRaw]) {
        NSDictionary *live = [self.itemsByKey objectForKey:[f objectForKey:@"k"]];
        NSMutableDictionary *m = [[(live ?: f) mutableCopy] autorelease];
        [m setObject:[f objectForKey:@"done"] ?: @NO forKey:@"done"];
        if (!live && self.allItems.count) [m setObject:@YES forKey:@"gone"];
        [out addObject:m];
    }
    return out;
}

- (void)setDone:(BOOL)done forKey:(NSString *)key {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *f in [self listRaw]) {
        if ([[f objectForKey:@"k"] isEqual:key]) {
            NSMutableDictionary *m = [[f mutableCopy] autorelease];
            [m setObject:@(done) forKey:@"done"];
            [a addObject:m];
        } else [a addObject:f];
    }
    [self saveList:a];
}

- (void)removeFromListKey:(NSString *)key {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *f in [self listRaw]) if (![[f objectForKey:@"k"] isEqual:key]) [a addObject:f];
    [self saveList:a];
}

- (void)clearListOnlyDone:(BOOL)onlyDone {
    NSMutableArray *a = [NSMutableArray array];
    if (onlyDone) for (NSDictionary *f in [self listRaw]) if (![[f objectForKey:@"done"] boolValue]) [a addObject:f];
    [self saveList:a];
}

- (NSUInteger)listOpenCount {
    NSUInteger n = 0;
    for (NSDictionary *f in [self listRaw]) if (![[f objectForKey:@"done"] boolValue]) n++;
    return n;
}

#pragma mark - watch words

- (NSArray *)watchWords { return [[self d] arrayForKey:@"watchWords"] ?: @[]; }

- (void)addWatchWord:(NSString *)w {
    w = [[w stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (!w.length) return;
    NSMutableArray *a = [[[self watchWords] mutableCopy] autorelease];
    if ([a containsObject:w]) return;
    [a addObject:w];
    [[self d] setObject:a forKey:@"watchWords"];
    [[self d] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZNStoreDidUpdateNotification object:self];
}

- (void)removeWatchWordAtIndex:(NSUInteger)idx {
    NSMutableArray *a = [[[self watchWords] mutableCopy] autorelease];
    if (idx < a.count) [a removeObjectAtIndex:idx];
    [[self d] setObject:a forKey:@"watchWords"];
    [[self d] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZNStoreDidUpdateNotification object:self];
}

// Усі слова запиту мають бути в назві (у будь-якому порядку).
- (NSArray *)itemsMatchingText:(NSString *)text inItems:(NSArray *)items {
    NSArray *parts = [[[text lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
                      componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray *words = [NSMutableArray array];
    for (NSString *p in parts) if (p.length) [words addObject:p];
    if (!words.count) return items;
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *it in items) {
        NSString *tl = [it objectForKey:@"tl"];
        if (!tl) tl = [[it objectForKey:@"t"] lowercaseString];
        BOOL ok = YES;
        for (NSString *w in words) {
            if ([tl rangeOfString:w].location == NSNotFound) { ok = NO; break; }
        }
        if (ok) [out addObject:it];
    }
    return out;
}

- (NSUInteger)watchMatchCount {
    NSMutableSet *keys = [NSMutableSet set];
    for (NSString *w in self.watchWords)
        for (NSDictionary *it in [self itemsMatchingText:w inItems:self.allItems]) [keys addObject:[it objectForKey:@"k"]];
    return keys.count;
}

@end

#pragma mark - formatting

NSString *ZNPrice(id number) {
    double v = [number doubleValue];
    NSString *s = (fabs(v - round(v)) < 0.005) ? [NSString stringWithFormat:@"%.0f", v] : [NSString stringWithFormat:@"%.2f", v];
    return [[s stringByReplacingOccurrencesOfString:@"." withString:@","] stringByAppendingString:@" грн"];
}

NSString *ZNPriceShort(id number) {
    double v = [number doubleValue];
    NSString *s = (fabs(v - round(v)) < 0.005) ? [NSString stringWithFormat:@"%.0f", v] : [NSString stringWithFormat:@"%.2f", v];
    return [s stringByReplacingOccurrencesOfString:@"." withString:@","];
}

NSString *ZNDateShort(NSString *iso) {
    if (![iso isKindOfClass:[NSString class]] || iso.length < 10) return nil;
    return [NSString stringWithFormat:@"%@.%@", [iso substringWithRange:NSMakeRange(8, 2)], [iso substringWithRange:NSMakeRange(5, 2)]];
}

NSInteger ZNDaysLeft(NSString *iso) {
    if (![iso isKindOfClass:[NSString class]] || iso.length < 10) return NSNotFound;
    NSDateComponents *c = [[[NSDateComponents alloc] init] autorelease];
    c.year = [[iso substringWithRange:NSMakeRange(0, 4)] integerValue];
    c.month = [[iso substringWithRange:NSMakeRange(5, 2)] integerValue];
    c.day = [[iso substringWithRange:NSMakeRange(8, 2)] integerValue];
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *end = [cal dateFromComponents:c];
    NSDateComponents *t = [cal components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:[NSDate date]];
    NSDate *today = [cal dateFromComponents:t];
    return [[cal components:NSDayCalendarUnit fromDate:today toDate:end options:0] day];
}
