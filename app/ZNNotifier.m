#import "ZNNotifier.h"
#import "ZNStore.h"

NSString * const ZNNotifyList  = @"list";
NSString * const ZNNotifyWords = @"words";
NSString * const ZNNotifyCheap = @"cheap";
NSString * const ZNNotifyNews  = @"news";

static const NSInteger ZNMaxPerDay = 2;        // не більше двох «нових» сповіщень на день
static const NSTimeInterval ZNBgInterval = 2 * 3600;

@interface ZNNotifier () {
    NSMutableArray *_waiters;   // блоки, що чекають кінця оновлення
}
@end

@implementation ZNNotifier

+ (ZNNotifier *)shared {
    static ZNNotifier *s = nil;
    if (!s) s = [[ZNNotifier alloc] init];
    return s;
}

- (NSUserDefaults *)d { return [NSUserDefaults standardUserDefaults]; }

- (BOOL)isOn:(NSString *)kind {
    id v = [[self d] objectForKey:[@"notify." stringByAppendingString:kind]];
    return v ? [v boolValue] : YES;   // за замовчуванням усе ввімкнено
}

- (void)setOn:(BOOL)on kind:(NSString *)kind {
    [[self d] setBool:on forKey:[@"notify." stringByAppendingString:kind]];
    [[self d] synchronize];
    if (on) [self askPermissionIfNeeded];
    [self rescheduleList];
}

- (void)askPermissionIfNeeded {
    UIApplication *app = [UIApplication sharedApplication];
    Class settings = NSClassFromString(@"UIUserNotificationSettings");
    if (settings && [app respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        // UIUserNotificationTypeBadge | Sound | Alert = 7
        id s = [settings performSelector:@selector(settingsForTypes:categories:) withObject:(id)(NSUInteger)7 withObject:nil];
        [app performSelector:@selector(registerUserNotificationSettings:) withObject:s];
    }
}

- (void)start {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(listChanged) name:ZNStoreListChangedNotification object:nil];
    [nc addObserver:self selector:@selector(dataUpdated) name:ZNStoreDidUpdateNotification object:nil];
    [nc addObserver:self selector:@selector(loadingChanged) name:ZNStoreLoadingNotification object:nil];
    [self rescheduleList];
}

#pragma mark - тихі години й ліміт

// 22:00–9:00 не турбуємо: переносимо на 9:00
- (NSDate *)deliverDateFrom:(NSDate *)date {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *c = [cal components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit fromDate:date];
    if (c.hour >= 9 && c.hour < 22) return date;
    if (c.hour >= 22) c.day += 1;
    c.hour = 9; c.minute = 0;
    return [cal dateFromComponents:c];
}

- (BOOL)takeDailySlot {
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    f.dateFormat = @"yyyy-MM-dd";
    NSString *day = [f stringFromDate:[NSDate date]];
    NSInteger n = [[[self d] stringForKey:@"notify.day"] isEqualToString:day] ? [[self d] integerForKey:@"notify.count"] : 0;
    if (n >= ZNMaxPerDay) return NO;
    [[self d] setObject:day forKey:@"notify.day"];
    [[self d] setInteger:n + 1 forKey:@"notify.count"];
    return YES;
}

- (void)post:(NSString *)body kind:(NSString *)kind {
    if (!body.length) return;
    UILocalNotification *n = [[[UILocalNotification alloc] init] autorelease];
    n.alertBody = body;
    n.soundName = UILocalNotificationDefaultSoundName;
    n.userInfo = @{ @"kind": kind };
    NSDate *when = [self deliverDateFrom:[NSDate date]];
    if ([when timeIntervalSinceNow] > 60) {
        n.fireDate = when;
        [[UIApplication sharedApplication] scheduleLocalNotification:n];
    } else {
        [[UIApplication sharedApplication] presentLocalNotificationNow:n];
    }
}

static NSString *ZNShort(NSString *t, NSUInteger max) {
    if (t.length <= max) return t;
    return [[t substringToIndex:max - 1] stringByAppendingString:@"…"];
}

#pragma mark - кінець акцій зі списку (заплановані)

- (void)listChanged { [self rescheduleList]; }

- (void)rescheduleList {
    UIApplication *app = [UIApplication sharedApplication];
    for (UILocalNotification *n in [app scheduledLocalNotifications])
        if ([[n.userInfo objectForKey:@"kind"] isEqual:ZNNotifyList]) [app cancelLocalNotification:n];
    if (![self isOn:ZNNotifyList]) return;

    ZNStore *st = [ZNStore shared];
    // дата закінчення → товари
    NSMutableDictionary *byEnd = [NSMutableDictionary dictionary];
    for (NSDictionary *e in [st listEntries]) {
        if ([[e objectForKey:@"done"] boolValue] || [[e objectForKey:@"gone"] boolValue]) continue;
        NSString *end = [e objectForKey:@"e"];
        if (![end isKindOfClass:[NSString class]] || end.length < 10) continue;
        NSMutableArray *a = [byEnd objectForKey:end];
        if (!a) { a = [NSMutableArray array]; [byEnd setObject:a forKey:end]; }
        [a addObject:e];
    }
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    f.dateFormat = @"yyyy-MM-dd HH:mm";
    for (NSString *end in byEnd) {
        NSArray *items = [byEnd objectForKey:end];
        NSDictionary *first = [items objectAtIndex:0];
        NSString *what = [NSString stringWithFormat:@"%@ (%@, %@)", ZNShort([first objectForKey:@"t"], 40),
                          [st storeName:[first objectForKey:@"s"]], ZNPrice([first objectForKey:@"p"])];
        if (items.count > 1) what = [what stringByAppendingFormat:@" і ще %lu", (unsigned long)items.count - 1];
        // напередодні о 10:00, а якщо вже пізно — в останній день о 9:00
        NSDate *endDay = [f dateFromString:[end stringByAppendingString:@" 10:00"]];
        NSDate *eve = [endDay dateByAddingTimeInterval:-24 * 3600];
        NSString *body = nil; NSDate *fire = nil;
        if ([eve timeIntervalSinceNow] > 60) { fire = eve; body = [@"Завтра закінчується акція: " stringByAppendingString:what]; }
        else {
            NSDate *morning = [f dateFromString:[end stringByAppendingString:@" 09:00"]];
            if ([morning timeIntervalSinceNow] > 60) { fire = morning; body = [@"Сьогодні останній день акції: " stringByAppendingString:what]; }
        }
        if (!fire) continue;
        UILocalNotification *n = [[[UILocalNotification alloc] init] autorelease];
        n.fireDate = fire;
        n.alertBody = body;
        n.soundName = UILocalNotificationDefaultSoundName;
        n.userInfo = @{ @"kind": ZNNotifyList };
        [app scheduleLocalNotification:n];
    }
}

#pragma mark - нове після оновлення

- (void)dataUpdated {
    [self rescheduleList];   // дати могли змінитись
    ZNStore *st = [ZNStore shared];
    if (!st.allItems.count || st.loading) return;
    [self checkWords];
    [self checkCheaper];
    [self checkLeaflets];
}

// «seen»-набори зберігаємо, щоб не повторюватись; перший прогін лише запам'ятовує
- (NSMutableSet *)seen:(NSString *)name first:(BOOL *)first {
    NSArray *a = [[self d] arrayForKey:[@"notify.seen." stringByAppendingString:name]];
    if (first) *first = (a == nil);
    return [NSMutableSet setWithArray:a ?: @[]];
}
- (void)saveSeen:(NSSet *)s name:(NSString *)name {
    NSArray *a = [s allObjects];
    if (a.count > 3000) a = [a subarrayWithRange:NSMakeRange(a.count - 3000, 3000)];
    [[self d] setObject:a forKey:[@"notify.seen." stringByAppendingString:name]];
}

- (void)checkWords {
    ZNStore *st = [ZNStore shared];
    NSArray *words = st.watchWords;
    if (!words.count) return;
    BOOL first;
    NSMutableSet *seen = [self seen:ZNNotifyWords first:&first];
    NSMutableArray *fresh = [NSMutableArray array];
    NSString *freshWord = nil;
    for (NSString *w in words) {
        for (NSDictionary *it in [st itemsMatchingText:w inItems:st.allItems]) {
            NSString *k = [NSString stringWithFormat:@"%@@%@", [it objectForKey:@"k"], [it objectForKey:@"p"]];
            if ([seen containsObject:k]) continue;
            [seen addObject:k];
            [fresh addObject:it];
            if (!freshWord) freshWord = w;
        }
    }
    [self saveSeen:seen name:ZNNotifyWords];
    if (first || !fresh.count || ![self isOn:ZNNotifyWords] || ![self takeDailySlot]) return;
    [fresh sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [[b objectForKey:@"d"] compare:[a objectForKey:@"d"]];
    }];
    NSDictionary *top = [fresh objectAtIndex:0];
    NSString *body = [NSString stringWithFormat:@"Нові акції «%@»: %@ — %@ в %@ (−%@%%)", freshWord,
                      ZNShort([top objectForKey:@"t"], 40), ZNPrice([top objectForKey:@"p"]),
                      [st storeName:[top objectForKey:@"s"]], [top objectForKey:@"d"]];
    if (fresh.count > 1) body = [body stringByAppendingFormat:@" і ще %lu", (unsigned long)fresh.count - 1];
    [self post:body kind:ZNNotifyWords];
}

- (void)checkCheaper {
    ZNStore *st = [ZNStore shared];
    BOOL first;
    NSMutableSet *seen = [self seen:ZNNotifyCheap first:&first];
    NSString *body = nil;
    NSUInteger count = 0;
    for (NSDictionary *e in [st listEntries]) {
        if ([[e objectForKey:@"done"] boolValue] || [[e objectForKey:@"gone"] boolValue]) continue;
        NSArray *cmp = [st comparisonsForItem:e];
        if (!cmp.count) continue;
        NSDictionary *best = [cmp objectAtIndex:0];
        double mine = [[e objectForKey:@"p"] doubleValue], other = [[best objectForKey:@"p"] doubleValue];
        if (other >= mine - 0.5) continue;
        NSString *k = [NSString stringWithFormat:@"%@>%@@%@", [e objectForKey:@"k"], [best objectForKey:@"k"], [best objectForKey:@"p"]];
        if ([seen containsObject:k]) continue;
        [seen addObject:k];
        count++;
        if (!body) body = [NSString stringWithFormat:@"Дешевше в %@: %@ — %@ замість %@", [st storeName:[best objectForKey:@"s"]],
                           ZNShort([e objectForKey:@"t"], 40), ZNPrice([best objectForKey:@"p"]), ZNPrice([e objectForKey:@"p"])];
    }
    [self saveSeen:seen name:ZNNotifyCheap];
    if (first || !body || ![self isOn:ZNNotifyCheap] || ![self takeDailySlot]) return;
    if (count > 1) body = [body stringByAppendingFormat:@" (і ще %lu зі списку)", (unsigned long)count - 1];
    [self post:body kind:ZNNotifyCheap];
}

- (void)checkLeaflets {
    ZNStore *st = [ZNStore shared];
    if (!st.cityId) return;
    BOOL first;
    NSMutableSet *seen = [self seen:[@"news." stringByAppendingString:st.cityId] first:&first];
    NSDictionary *fresh = nil;
    for (NSDictionary *l in st.leaflets) {
        NSString *k = [NSString stringWithFormat:@"%@|%@|%@", [l objectForKey:@"chain"], [l objectForKey:@"from"], [l objectForKey:@"title"]];
        if ([seen containsObject:k]) continue;
        [seen addObject:k];
        if (!fresh) fresh = l;
    }
    [self saveSeen:seen name:[@"news." stringByAppendingString:st.cityId]];
    if (first || !fresh || ![self isOn:ZNNotifyNews] || ![self takeDailySlot]) return;
    NSString *to = ZNDateShort([fresh objectForKey:@"to"]);
    [self post:[NSString stringWithFormat:@"Нова газетка %@: «%@»%@", [fresh objectForKey:@"name"], [fresh objectForKey:@"title"] ?: @"",
                to ? [NSString stringWithFormat:@" до %@", to] : @""] kind:ZNNotifyNews];
}

#pragma mark - фон

- (BOOL)shouldRefreshInBackground {
    NSDate *last = [[self d] objectForKey:@"notify.bgLast"];
    return !last || [[NSDate date] timeIntervalSinceDate:last] >= ZNBgInterval;
}

- (void)loadingChanged {
    if ([ZNStore shared].loading || !_waiters.count) return;
    NSArray *w = [[_waiters copy] autorelease];
    [_waiters removeAllObjects];
    // DidUpdate вже надіслано в rebuild — перевірки пройшли
    for (void (^b)(BOOL) in w) b(YES);
}

- (void)backgroundRefresh:(void (^)(BOOL newData))done {
    if (![self shouldRefreshInBackground]) { if (done) done(NO); return; }
    [[self d] setObject:[NSDate date] forKey:@"notify.bgLast"];
    [[self d] synchronize];
    if (!_waiters) _waiters = [[NSMutableArray alloc] init];
    if (done) [_waiters addObject:[[done copy] autorelease]];
    ZNStore *st = [ZNStore shared];
    if (!st.loading) [st refresh];
}

@end
