#import <UIKit/UIKit.h>
#import "ZNStore.h"
#import "ZNRequest.h"

NSString * const ZNStoreDidUpdateNotification = @"ZNStoreDidUpdateNotification";
NSString * const ZNStoreDidFailNotification   = @"ZNStoreDidFailNotification";
NSString * const ZNStoreLoadingNotification   = @"ZNStoreLoadingNotification";

static NSString * const kDefaultServer = @"https://menstryo.github.io/znyzhky";

@interface ZNStore () {
    NSInteger _pending;
    BOOL _failed;
}
@property (nonatomic, retain, readwrite) NSArray *items;
@property (nonatomic, retain, readwrite) NSArray *allItems;
@property (nonatomic, retain, readwrite) NSArray *stores;
@property (nonatomic, retain, readwrite) NSArray *categories;
@property (nonatomic, retain, readwrite) NSDate *updatedAt;
@property (nonatomic, retain, readwrite) NSDate *fetchedAt;
@property (nonatomic, assign, readwrite) BOOL loading;
@property (nonatomic, retain) NSDictionary *itemsByKey;
@end

@implementation ZNStore

@synthesize items = _items, allItems = _allItems, stores = _stores, categories = _categories;
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
                                      @"disabledStores": @[],
                                      @"favorites": @[],
                                      @"watchWords": @[] }];
        _items = [[NSArray alloc] init];
        _allItems = [[NSArray alloc] init];
        _stores = [[NSArray alloc] init];
        _categories = [[NSArray alloc] init];
        id f = [[self d] objectForKey:@"fetchedAt"];
        if ([f isKindOfClass:[NSDate class]]) _fetchedAt = [f retain];
        [self rebuildFromCache:nil];
    }
    return self;
}

- (void)dealloc {
    [_items release]; [_allItems release]; [_stores release]; [_categories release];
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

- (BOOL)isStoreEnabled:(NSString *)storeId {
    return ![[[self d] arrayForKey:@"disabledStores"] containsObject:storeId];
}
- (void)setStore:(NSString *)storeId enabled:(BOOL)on {
    NSMutableArray *a = [[[[self d] arrayForKey:@"disabledStores"] mutableCopy] autorelease];
    [a removeObject:storeId];
    if (!on) [a addObject:storeId];
    [[self d] setObject:a forKey:@"disabledStores"];
    [[self d] synchronize];
    [self applyFilters];
}

- (NSInteger)minDiscount { return [[self d] integerForKey:@"minDiscount"]; }
- (void)setMinDiscount:(NSInteger)v {
    [[self d] setInteger:v forKey:@"minDiscount"];
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
- (NSString *)pathForStore:(NSString *)sid {
    return [[self cacheDir] stringByAppendingPathComponent:[NSString stringWithFormat:@"store-%@.json", sid]];
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
        for (NSDictionary *s in [index objectForKey:@"stores"]) {
            NSString *sid = [s objectForKey:@"id"];
            if (![sid isKindOfClass:[NSString class]]) continue;
            NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
            NSDictionary *j = ZNParse([NSData dataWithContentsOfFile:[self pathForStore:sid]]);
            for (NSDictionary *it in [j objectForKey:@"items"]) {
                if (![it isKindOfClass:[NSDictionary class]]) continue;
                NSMutableDictionary *m = [it mutableCopy];
                NSString *key = [NSString stringWithFormat:@"%@:%@", sid, [it objectForKey:@"id"]];
                [m setObject:sid forKey:@"s"];
                [m setObject:key forKey:@"k"];
                [m setObject:[[it objectForKey:@"t"] lowercaseString] ?: @"" forKey:@"tl"];
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
        NSArray *stores = [index objectForKey:@"stores"] ?: @[];
        NSArray *cats = [index objectForKey:@"cats"] ?: @[];
        NSDate *upd = ZNParseISODate([index objectForKey:@"updated"]);
        [all retain]; [byKey retain]; [stores retain]; [cats retain]; [upd retain];
        [pool release];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allItems = all;
            self.itemsByKey = byKey;
            self.stores = stores;
            self.categories = cats;
            if (upd) self.updatedAt = upd;
            [all release]; [byKey release]; [stores release]; [cats release]; [upd release];
            [self applyFilters];
            if (doneCopy) doneCopy();
            [doneCopy release];
        });
    });
}

- (void)applyFilters {
    NSInteger minD = self.minDiscount;
    NSArray *disabled = [[self d] arrayForKey:@"disabledStores"];
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:self.allItems.count];
    for (NSDictionary *it in self.allItems) {
        if ([[it objectForKey:@"d"] integerValue] < minD) continue;
        if (disabled.count && [disabled containsObject:[it objectForKey:@"s"]]) continue;
        [out addObject:it];
    }
    self.items = out;
    [[NSNotificationCenter defaultCenter] postNotificationName:ZNStoreDidUpdateNotification object:self];
}

#pragma mark - favorites

- (NSArray *)favoriteSnapshots { return [[self d] arrayForKey:@"favorites"] ?: @[]; }

- (BOOL)isFavorite:(NSDictionary *)item {
    NSString *k = [item objectForKey:@"k"];
    for (NSDictionary *f in [self favoriteSnapshots]) if ([[f objectForKey:@"k"] isEqual:k]) return YES;
    return NO;
}

- (void)toggleFavorite:(NSDictionary *)item {
    NSString *k = [item objectForKey:@"k"];
    if (!k) return;
    NSMutableArray *a = [[[self favoriteSnapshots] mutableCopy] autorelease];
    for (NSUInteger i = 0; i < a.count; i++) {
        if ([[[a objectAtIndex:i] objectForKey:@"k"] isEqual:k]) {
            [a removeObjectAtIndex:i];
            [[self d] setObject:a forKey:@"favorites"];
            [[self d] synchronize];
            return;
        }
    }
    // зберігаємо копію без службових полів (лише plist-сумісні значення)
    NSMutableDictionary *snap = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"id", @"t", @"p", @"o", @"d", @"u", @"c", @"e", @"i", @"l", @"s", @"k"]) {
        id v = [item objectForKey:key];
        if ([v isKindOfClass:[NSString class]] || [v isKindOfClass:[NSNumber class]]) [snap setObject:v forKey:key];
    }
    [a insertObject:snap atIndex:0];
    [[self d] setObject:a forKey:@"favorites"];
    [[self d] synchronize];
}

- (NSArray *)favorites {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *f in [self favoriteSnapshots]) {
        NSDictionary *live = [self.itemsByKey objectForKey:[f objectForKey:@"k"]];
        if (live) [out addObject:live];
        else {
            NSMutableDictionary *m = [[f mutableCopy] autorelease];
            [m setObject:@YES forKey:@"gone"];
            [out addObject:m];
        }
    }
    return out;
}

- (void)removeFavoriteAtIndex:(NSUInteger)idx {
    NSMutableArray *a = [[[self favoriteSnapshots] mutableCopy] autorelease];
    if (idx < a.count) [a removeObjectAtIndex:idx];
    [[self d] setObject:a forKey:@"favorites"];
    [[self d] synchronize];
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
        for (NSDictionary *it in [self itemsMatchingText:w inItems:self.items]) [keys addObject:[it objectForKey:@"k"]];
    return keys.count;
}

@end

#pragma mark - formatting

NSString *ZNPrice(id number) {
    double v = [number doubleValue];
    NSString *s = (fabs(v - round(v)) < 0.005) ? [NSString stringWithFormat:@"%.0f", v] : [NSString stringWithFormat:@"%.2f", v];
    return [[s stringByReplacingOccurrencesOfString:@"." withString:@","] stringByAppendingString:@" грн"];
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
