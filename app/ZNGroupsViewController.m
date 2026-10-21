#import "ZNGroupsViewController.h"
#import "ZNDealListViewController.h"
#import "ZNDealCell.h"
#import "ZNStore.h"

@interface ZNGroupsViewController () {
    ZNGroupMode _mode;
    NSArray *_rows;   // [{id, name, count, avg, max, subtitle, disabled}]
}
@end

@implementation ZNGroupsViewController

- (id)initWithMode:(ZNGroupMode)mode {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _mode = mode;
        self.title = mode == ZNGroupStores ? @"Магазини" : @"Категорії";
        _rows = [[NSArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_rows release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 58;
    if ([self respondsToSelector:@selector(setRefreshControl:)]) {
        UIRefreshControl *rc = [[[UIRefreshControl alloc] init] autorelease];
        [rc addTarget:self action:@selector(pulled) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = rc;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:ZNStoreDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadingChanged) name:ZNStoreLoadingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadingChanged) name:ZNStoreDidFailNotification object:nil];
    [self reload];
}

- (void)pulled { [[ZNStore shared] refresh]; }
- (void)loadingChanged {
    if (![ZNStore shared].loading && [self respondsToSelector:@selector(refreshControl)]) [self.refreshControl endRefreshing];
}

// лічильники рахуємо з видимих товарів (з урахуванням фільтра знижки)
- (void)reload {
    ZNStore *st = [ZNStore shared];
    NSMutableDictionary *count = [NSMutableDictionary dictionary], *sum = [NSMutableDictionary dictionary], *max = [NSMutableDictionary dictionary];
    NSString *key = _mode == ZNGroupStores ? @"s" : @"c";
    for (NSDictionary *it in st.items) {
        NSString *g = [it objectForKey:key];
        if (!g) continue;
        NSInteger d = [[it objectForKey:@"d"] integerValue];
        [count setObject:@([[count objectForKey:g] integerValue] + 1) forKey:g];
        [sum setObject:@([[sum objectForKey:g] integerValue] + d) forKey:g];
        if (d > [[max objectForKey:g] integerValue]) [max setObject:@(d) forKey:g];
    }

    NSMutableArray *rows = [NSMutableArray array];
    NSArray *source = _mode == ZNGroupStores ? st.stores : st.categories;
    for (NSDictionary *g in source) {
        NSString *gid = [g objectForKey:@"id"];
        NSInteger n = [[count objectForKey:gid] integerValue];
        BOOL disabled = _mode == ZNGroupStores && ![st isStoreEnabled:gid];
        if (_mode == ZNGroupCategories && n == 0) continue;
        NSString *sub;
        if (disabled) sub = @"вимкнено в налаштуваннях";
        else if (_mode == ZNGroupStores && ![[g objectForKey:@"ok"] boolValue] && [[g objectForKey:@"count"] integerValue] == 0)
            sub = @"дані тимчасово недоступні";
        else if (n == 0) sub = @"немає акцій за фільтром";
        else sub = [NSString stringWithFormat:@"%ld акцій · у середньому −%ld%% · до −%@%%",
                    (long)n, (long)([[sum objectForKey:gid] integerValue] / n), [max objectForKey:gid]];
        NSString *name = [g objectForKey:@"name"];
        if (_mode == ZNGroupCategories) name = [NSString stringWithFormat:@"%@  %@", [st categoryEmoji:gid], name];
        [rows addObject:@{ @"id": gid, @"name": name ?: gid, @"sub": sub, @"n": @(n), @"disabled": @(disabled) }];
    }
    [_rows release];
    _rows = [rows retain];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _rows.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"g"];
    if (!c) c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"g"] autorelease];
    NSDictionary *r = [_rows objectAtIndex:ip.row];
    BOOL off = [[r objectForKey:@"disabled"] boolValue] || [[r objectForKey:@"n"] integerValue] == 0;
    c.textLabel.text = [r objectForKey:@"name"];
    c.textLabel.textColor = off ? [UIColor grayColor] : [UIColor blackColor];
    c.detailTextLabel.text = [r objectForKey:@"sub"];
    c.detailTextLabel.textColor = [UIColor grayColor];
    c.accessoryType = off ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    c.selectionStyle = off ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *r = [_rows objectAtIndex:ip.row];
    if ([[r objectForKey:@"disabled"] boolValue] || [[r objectForKey:@"n"] integerValue] == 0) return;
    NSString *gid = [r objectForKey:@"id"];
    ZNStore *st = [ZNStore shared];
    ZNDealListViewController *l;
    if (_mode == ZNGroupStores) {
        l = [[[ZNDealListViewController alloc] initWithTitle:[st storeName:gid]
                                                      filter:^BOOL(NSDictionary *it) { return [[it objectForKey:@"s"] isEqualToString:gid]; }] autorelease];
        l.showsStore = NO;
    } else {
        l = [[[ZNDealListViewController alloc] initWithTitle:[st categoryName:gid]
                                                      filter:^BOOL(NSDictionary *it) { return [[it objectForKey:@"c"] isEqualToString:gid]; }] autorelease];
    }
    [self.navigationController pushViewController:l animated:YES];
}

@end
