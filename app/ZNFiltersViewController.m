#import "ZNFiltersViewController.h"
#import "ZNTheme.h"
#import "ZNStore.h"
#import <QuartzCore/QuartzCore.h>

enum { ZNFStores = 0, ZNFGroup, ZNFCats, ZNFDiscount, ZNFSort, ZNFCount };
static NSString * const kSorts[] = { @"Вигідні спершу", @"Найбільша знижка", @"Дешевші спершу", @"Скоро закінчуються" };
static const NSInteger kDiscounts[] = { 0, 20, 30, 40, 50 };

@interface ZNFiltersViewController () {
    UIButton *_apply;
}
@end

@implementation ZNFiltersViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Фільтри";
    }
    return self;
}

- (void)dealloc {
    [_apply release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [ZNTheme styleGroupedTable:self.tableView];
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Скинути" style:UIBarButtonItemStyleBordered
                                                                             target:self action:@selector(reset)] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                            target:self action:@selector(done)] autorelease];
    UIView *foot = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 70)] autorelease];
    _apply = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    _apply.frame = CGRectMake(10, 8, foot.bounds.size.width - 20, 44);
    _apply.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _apply.backgroundColor = ZN_ACCENT;
    _apply.layer.cornerRadius = 8;
    _apply.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [_apply addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside];
    [foot addSubview:_apply];
    self.tableView.tableFooterView = foot;
    [self refresh];
}

- (void)refresh {
    ZNStore *st = [ZNStore shared];
    NSUInteger n = st.items.count;
    [_apply setTitle:[NSString stringWithFormat:@"Показати %lu %@", (unsigned long)n, [self plural:n]] forState:UIControlStateNormal];
    [self.tableView reloadData];
}

- (NSString *)plural:(NSUInteger)n {
    NSUInteger m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return @"акцію";
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return @"акції";
    return @"акцій";
}

- (void)reset { [[ZNStore shared] resetFilters]; [self refresh]; }
- (void)done { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSArray *)cats { return [[ZNStore shared] categoryIdsForGroup:[ZNStore shared].filterGroup]; }

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return ZNFCount; }

- (NSString *)titleFor:(NSInteger)s {
    switch (s) {
        case ZNFStores:   return @"Магазини";
        case ZNFGroup:    return @"Що показувати";
        case ZNFCats:     return @"Категорії";
        case ZNFDiscount: return @"Знижка від";
        default:          return @"Сортування";
    }
}
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    return [ZNTheme sectionHeaderWithTitle:[self titleFor:s] width:tv.bounds.size.width];
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return 40; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case ZNFStores:   return [ZNStore shared].stores.count;
        case ZNFGroup:    return 1;
        case ZNFCats:     return [self cats].count + 1;
        case ZNFDiscount: return 1;
        default:          return 4;
    }
}

- (UISegmentedControl *)segment:(NSArray *)titles selected:(NSInteger)sel action:(SEL)a width:(CGFloat)w {
    UISegmentedControl *sc = [[[UISegmentedControl alloc] initWithItems:titles] autorelease];
    if (![ZNTheme isFlat]) sc.segmentedControlStyle = UISegmentedControlStyleBar;
    sc.frame = CGRectMake(0, 0, w, 32);
    sc.selectedSegmentIndex = sel;
    [sc addTarget:self action:a forControlEvents:UIControlEventValueChanged];
    return sc;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    ZNStore *st = [ZNStore shared];
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease];
    c.detailTextLabel.textColor = ZN_TEXT_MUTED;
    BOOL check = NO;
    switch (ip.section) {
        case ZNFStores: {
            NSDictionary *s = [st.stores objectAtIndex:ip.row];
            NSString *sid = [s objectForKey:@"id"];
            c.textLabel.text = [s objectForKey:@"name"];
            NSInteger cnt = [[s objectForKey:@"count"] integerValue];
            c.detailTextLabel.text = cnt ? [NSString stringWithFormat:@"%ld", (long)cnt] : @"недоступно";
            NSArray *fs = st.filterStores;
            check = !fs.count || [fs containsObject:sid];
            break;
        }
        case ZNFGroup: {
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            CGFloat w = tv.bounds.size.width - ([ZNTheme isFlat] ? 30 : 40);
            UISegmentedControl *sc = [self segment:@[@"Продукти", @"Для дому", @"Усе"] selected:st.filterGroup
                                            action:@selector(groupChanged:) width:w];
            sc.frame = CGRectMake(([ZNTheme isFlat] ? 15 : 10), 6, w - ([ZNTheme isFlat] ? 0 : 0), 32);
            sc.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [c.contentView addSubview:sc];
            break;
        }
        case ZNFCats: {
            NSArray *sel = st.filterCategories;
            if (ip.row == 0) {
                c.textLabel.text = @"Усі категорії";
                check = sel.count == 0;
            } else {
                NSString *cid = [[self cats] objectAtIndex:ip.row - 1];
                c.textLabel.text = [NSString stringWithFormat:@"%@  %@", [st categoryEmoji:cid], [st categoryName:cid]];
                check = [sel containsObject:cid];
            }
            break;
        }
        case ZNFDiscount: {
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            NSInteger cur = 0;
            for (int i = 0; i < 5; i++) if (kDiscounts[i] == st.minDiscount) cur = i;
            CGFloat w = tv.bounds.size.width - ([ZNTheme isFlat] ? 30 : 40);
            UISegmentedControl *sc = [self segment:@[@"будь-яка", @"20%", @"30%", @"40%", @"50%"] selected:cur
                                            action:@selector(discountChanged:) width:w];
            sc.frame = CGRectMake(([ZNTheme isFlat] ? 15 : 10), 6, w, 32);
            sc.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [c.contentView addSubview:sc];
            break;
        }
        default: {
            c.textLabel.text = kSorts[ip.row];
            check = st.sortMode == ip.row;
            if (ip.row == 0) c.detailTextLabel.text = @"знижка × економія";
        }
    }
    if (check) {
        c.accessoryType = UITableViewCellAccessoryCheckmark;
        c.textLabel.textColor = ZN_ACCENT_DARK;
    }
    if ([c respondsToSelector:@selector(setTintColor:)]) c.tintColor = ZN_ACCENT;
    return c;
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    return (ip.section == ZNFGroup || ip.section == ZNFDiscount) ? 44 : 44;
}

- (void)groupChanged:(UISegmentedControl *)sc {
    [[ZNStore shared] setFilterGroup:(ZNGroup)sc.selectedSegmentIndex];
    [self refresh];
}

- (void)discountChanged:(UISegmentedControl *)sc {
    [[ZNStore shared] setMinDiscount:kDiscounts[MAX(0, MIN(4, sc.selectedSegmentIndex))]];
    [self refresh];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    ZNStore *st = [ZNStore shared];
    if (ip.section == ZNFStores) {
        NSArray *ids = [st.stores valueForKey:@"id"];
        NSString *sid = [ids objectAtIndex:ip.row];
        NSMutableArray *fs = [[st.filterStores mutableCopy] autorelease];
        if (!fs.count) { [fs addObjectsFromArray:ids]; }          // «усі» → прибираємо один
        if ([fs containsObject:sid]) [fs removeObject:sid]; else [fs addObject:sid];
        if (fs.count == ids.count || fs.count == 0) fs = [NSMutableArray array]; // усі / жодного = усі
        [st setFilterStores:fs];
    } else if (ip.section == ZNFCats) {
        if (ip.row == 0) [st setFilterCategories:@[]];
        else {
            NSString *cid = [[self cats] objectAtIndex:ip.row - 1];
            NSMutableArray *sel = [[st.filterCategories mutableCopy] autorelease];
            if ([sel containsObject:cid]) [sel removeObject:cid]; else [sel addObject:cid];
            [st setFilterCategories:sel];
        }
    } else if (ip.section == ZNFSort) {
        [st setSortMode:(ZNSort)ip.row];
    }
    [self refresh];
}

@end
