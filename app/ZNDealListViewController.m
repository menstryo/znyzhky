#import "ZNDealListViewController.h"
#import "ZNDealViewController.h"
#import "ZNDealCell.h"
#import "ZNStore.h"

enum { ZNSortDiscount = 0, ZNSortPrice, ZNSortEnding };

@interface ZNDealListViewController () {
    ZNItemFilter _filter;
    NSArray *_rows;
    UISearchBar *_search;
    UISegmentedControl *_sort;
    UILabel *_footer;
}
@end

@implementation ZNDealListViewController

@synthesize showsStore = _showsStore, searchText = _searchText;

- (id)initWithTitle:(NSString *)title filter:(ZNItemFilter)filter {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.title = title;
        _filter = [filter copy];
        _showsStore = YES;
        _rows = [[NSArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _search.delegate = nil;
    [_filter release]; [_rows release]; [_search release]; [_sort release]; [_footer release]; [_searchText release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = [ZNDealCell height];

    UIView *header = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44 + 40)] autorelease];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    header.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1];

    _search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, header.bounds.size.width, 44)];
    _search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _search.placeholder = @"Пошук товару";
    _search.delegate = self;
    _search.autocorrectionType = UITextAutocorrectionTypeNo;
    _search.text = self.searchText;
    [header addSubview:_search];

    _sort = [[UISegmentedControl alloc] initWithItems:@[@"Знижка", @"Ціна", @"Закінчуються"]];
    if ([_sort respondsToSelector:@selector(setSegmentedControlStyle:)] && [[[UIDevice currentDevice] systemVersion] floatValue] < 7)
        _sort.segmentedControlStyle = UISegmentedControlStyleBar;
    _sort.frame = CGRectMake(8, 44 + 6, header.bounds.size.width - 16, 28);
    _sort.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _sort.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"sortMode"];
    [_sort addTarget:self action:@selector(sortChanged) forControlEvents:UIControlEventValueChanged];
    [header addSubview:_sort];
    self.tableView.tableHeaderView = header;

    _footer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 60)];
    _footer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _footer.textAlignment = NSTextAlignmentCenter;
    _footer.textColor = [UIColor grayColor];
    _footer.font = [UIFont systemFontOfSize:14];
    _footer.numberOfLines = 2;
    _footer.backgroundColor = [UIColor clearColor];
    self.tableView.tableFooterView = _footer;

    if ([self respondsToSelector:@selector(setRefreshControl:)]) {
        UIRefreshControl *rc = [[[UIRefreshControl alloc] init] autorelease];
        [rc addTarget:self action:@selector(pulled) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = rc;
    }

    [self updateFilterButton];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(storeUpdated) name:ZNStoreDidUpdateNotification object:nil];
    [nc addObserver:self selector:@selector(storeFailed:) name:ZNStoreDidFailNotification object:nil];
    [nc addObserver:self selector:@selector(loadingChanged) name:ZNStoreLoadingNotification object:nil];
    [self reload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSInteger s = [[NSUserDefaults standardUserDefaults] integerForKey:@"sortMode"];
    if (_sort.selectedSegmentIndex != s) { _sort.selectedSegmentIndex = s; [self reload]; }
    [self.tableView reloadRowsAtIndexPaths:[self.tableView indexPathsForVisibleRows] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - data

- (void)reload {
    ZNStore *st = [ZNStore shared];
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *it in st.items) if (!_filter || _filter(it)) [a addObject:it];
    NSArray *rows = _search.text.length ? [st itemsMatchingText:_search.text inItems:a] : a;

    NSInteger mode = _sort.selectedSegmentIndex;
    if (mode == ZNSortPrice) {
        rows = [rows sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *x, NSDictionary *y) {
            return [[x objectForKey:@"p"] compare:[y objectForKey:@"p"]];
        }];
    } else if (mode == ZNSortEnding) {
        // лише ті, що мають дату, найближчі першими
        NSMutableArray *withDate = [NSMutableArray array];
        for (NSDictionary *it in rows) {
            NSInteger left = ZNDaysLeft([it objectForKey:@"e"]);
            if (left != NSNotFound && left >= 0) [withDate addObject:it];
        }
        rows = [withDate sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *x, NSDictionary *y) {
            NSComparisonResult r = [[x objectForKey:@"e"] compare:[y objectForKey:@"e"]];
            if (r != NSOrderedSame) return r;
            return [[y objectForKey:@"d"] compare:[x objectForKey:@"d"]];
        }];
    } // інакше вже відсортовано за знижкою

    [_rows release];
    _rows = [rows retain];
    [self.tableView reloadData];
    [self updateFooter];
}

- (void)updateFooter {
    ZNStore *st = [ZNStore shared];
    if (_rows.count) {
        _footer.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)_rows.count, [self pluralGoods:_rows.count]];
    } else if (st.loading && !st.allItems.count) {
        _footer.text = @"Завантаження…";
    } else if (!st.allItems.count) {
        _footer.text = @"Немає даних.\nПотягніть список униз, щоб оновити.";
    } else if (_sort.selectedSegmentIndex == ZNSortEnding) {
        _footer.text = @"Немає акцій з відомою датою завершення";
    } else {
        _footer.text = @"Нічого не знайдено";
    }
}

- (NSString *)pluralGoods:(NSUInteger)n {
    NSUInteger m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return @"товар";
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return @"товари";
    return @"товарів";
}

- (void)storeUpdated { [self reload]; [self updateFilterButton]; }

- (void)loadingChanged {
    if (![ZNStore shared].loading && [self respondsToSelector:@selector(refreshControl)]) [self.refreshControl endRefreshing];
    [self updateFooter];
}

- (void)storeFailed:(NSNotification *)n {
    if ([self respondsToSelector:@selector(refreshControl)]) [self.refreshControl endRefreshing];
    // показуємо лише на видимому екрані, щоб не було купи алертів
    if (!self.isViewLoaded || !self.view.window || self.navigationController.topViewController != self) return;
    NSError *e = [n.userInfo objectForKey:@"error"];
    NSString *msg = [ZNStore shared].allItems.count
        ? [NSString stringWithFormat:@"%@\nПоказано збережені дані.", e.localizedDescription]
        : e.localizedDescription;
    UIAlertView *a = [[[UIAlertView alloc] initWithTitle:@"Немає з'єднання" message:msg delegate:nil
                                       cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
    [a show];
}

- (void)pulled { [[ZNStore shared] refresh]; }

- (void)sortChanged {
    [[NSUserDefaults standardUserDefaults] setInteger:_sort.selectedSegmentIndex forKey:@"sortMode"];
    [self reload];
    if (_rows.count) [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                           atScrollPosition:UITableViewScrollPositionTop animated:NO];
}

#pragma mark - min discount filter

- (void)updateFilterButton {
    NSInteger m = [ZNStore shared].minDiscount;
    NSString *t = m > 0 ? [NSString stringWithFormat:@"від %ld%%", (long)m] : @"Фільтр";
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:t style:UIBarButtonItemStyleBordered
                                                                              target:self action:@selector(filterTapped)] autorelease];
}

- (void)filterTapped {
    [_search resignFirstResponder];
    UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:@"Мінімальна знижка" delegate:self cancelButtonTitle:nil
                                      destructiveButtonTitle:nil otherButtonTitles:@"Будь-яка", @"від 20%", @"від 30%",
                                                             @"від 40%", @"від 50%", nil] autorelease];
    s.cancelButtonIndex = [s addButtonWithTitle:@"Скасувати"];
    if (self.tabBarController) [s showFromTabBar:self.tabBarController.tabBar];
    else [s showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {
    if (i == s.cancelButtonIndex || i < 0) return;
    static const NSInteger vals[] = { 0, 20, 30, 40, 50 };
    if (i < 5) [[ZNStore shared] setMinDiscount:vals[i]];
}

#pragma mark - search

- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reload) object:nil];
    [self performSelector:@selector(reload) withObject:nil afterDelay:0.25]; // не фільтруємо на кожну літеру
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)sb { [sb resignFirstResponder]; }
- (void)searchBarTextDidBeginEditing:(UISearchBar *)sb { [sb setShowsCancelButton:YES animated:YES]; }
- (void)searchBarTextDidEndEditing:(UISearchBar *)sb { [sb setShowsCancelButton:NO animated:YES]; }
- (void)searchBarCancelButtonClicked:(UISearchBar *)sb {
    sb.text = @"";
    [sb resignFirstResponder];
    [self reload];
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)sv { [_search resignFirstResponder]; }

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _rows.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    ZNDealCell *c = (ZNDealCell *)[tv dequeueReusableCellWithIdentifier:@"deal"];
    if (!c) c = [[[ZNDealCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"deal"] autorelease];
    c.showsStore = _showsStore;
    c.item = [_rows objectAtIndex:ip.row];
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    ZNDealViewController *d = [[[ZNDealViewController alloc] initWithItem:[_rows objectAtIndex:ip.row]] autorelease];
    [self.navigationController pushViewController:d animated:YES];
}

@end
