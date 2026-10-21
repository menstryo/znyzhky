#import "ZNGridViewController.h"
#import "ZNGridCell.h"
#import "ZNDealViewController.h"
#import "ZNFiltersViewController.h"
#import "ZNTheme.h"
#import "ZNStore.h"
#import <QuartzCore/QuartzCore.h>

static NSString * const kSortTitles[] = { @"Вигідні", @"Найбільша знижка", @"Дешевші", @"Закінчуються" };

@interface ZNGridViewController () {
    NSString *_fixedQuery;
    UICollectionView *_grid;
    UIScrollView *_strip;
    UISearchBar *_search;
    UILabel *_empty;
    UIRefreshControl *_refresh;
    NSArray *_rows;
}
@end

@implementation ZNGridViewController

- (id)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        self.title = @"Акції";
        _rows = [[NSArray alloc] init];
    }
    return self;
}

- (id)initWithFixedQuery:(NSString *)query {
    if ((self = [self init])) {
        _fixedQuery = [query copy];
        self.title = query;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _search.delegate = nil;
    _grid.dataSource = nil; _grid.delegate = nil;
    [_fixedQuery release]; [_grid release]; [_strip release]; [_search release]; [_empty release];
    [_refresh release]; [_rows release];
    [super dealloc];
}

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = ZN_BG;
    self.view = v;

    CGFloat top = 0;
    if (!_fixedQuery) {
        // рядок фільтрів
        _strip = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, v.bounds.size.width, 44)];
        _strip.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _strip.showsHorizontalScrollIndicator = NO;
        _strip.backgroundColor = ZN_BG_HEADER;
        UIView *line = [[[UIView alloc] initWithFrame:CGRectMake(0, 43, 4000, 1)] autorelease];
        line.backgroundColor = [UIColor colorWithRed:0.86 green:0.80 blue:0.75 alpha:1];
        [_strip addSubview:line];
        [v addSubview:_strip];
        top = 44;
    }

    UICollectionViewFlowLayout *layout = [[[UICollectionViewFlowLayout alloc] init] autorelease];
    layout.minimumInteritemSpacing = 8;
    layout.minimumLineSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(10, 8, 14, 8);
    _grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, top, v.bounds.size.width, v.bounds.size.height - top)
                               collectionViewLayout:layout];
    _grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _grid.backgroundColor = ZN_BG;
    _grid.alwaysBounceVertical = YES;
    _grid.dataSource = self;
    _grid.delegate = self;
    [_grid registerClass:[ZNGridCell class] forCellWithReuseIdentifier:@"g"];
    [v addSubview:_grid];

    _refresh = [[UIRefreshControl alloc] init];
    [_refresh addTarget:self action:@selector(pulled) forControlEvents:UIControlEventValueChanged];
    [_grid addSubview:_refresh];

    _empty = [[UILabel alloc] initWithFrame:CGRectMake(30, top + 60, v.bounds.size.width - 60, 80)];
    _empty.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _empty.numberOfLines = 0;
    _empty.textAlignment = NSTextAlignmentCenter;
    _empty.textColor = ZN_TEXT_MUTED;
    _empty.font = [UIFont systemFontOfSize:15];
    _empty.backgroundColor = [UIColor clearColor];
    _empty.hidden = YES;
    [v addSubview:_empty];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // iOS 7+: не залазити під навбар, інакше рядок фільтрів сховається
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) self.edgesForExtendedLayout = UIRectEdgeNone;
    if (!_fixedQuery) {
        _search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 300, 44)];
        _search.placeholder = @"Пошук акцій";
        _search.delegate = self;
        _search.autocorrectionType = UITextAutocorrectionTypeNo;
        if (![ZNTheme isFlat]) _search.tintColor = ZN_ACCENT; // зливається з навбаром
        self.navigationItem.titleView = _search;
    }
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reload) name:ZNStoreDidUpdateNotification object:nil];
    [nc addObserver:self selector:@selector(loadingChanged) name:ZNStoreLoadingNotification object:nil];
    [nc addObserver:self selector:@selector(failed:) name:ZNStoreDidFailNotification object:nil];
    [self reload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_grid.collectionViewLayout invalidateLayout];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)o duration:(NSTimeInterval)d {
    [_grid.collectionViewLayout invalidateLayout];
}

#pragma mark - filter strip

- (UIButton *)chip:(NSString *)title primary:(BOOL)primary action:(SEL)sel x:(CGFloat)x {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.titleLabel.font = primary ? [UIFont boldSystemFontOfSize:13] : [UIFont systemFontOfSize:13];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:(primary ? [UIColor whiteColor] : [UIColor colorWithRed:0.17 green:0.13 blue:0.11 alpha:1]) forState:UIControlStateNormal];
    [b setTitleColor:[UIColor colorWithWhite:0.5 alpha:1] forState:UIControlStateHighlighted];
    b.backgroundColor = primary ? ZN_ACCENT : [UIColor whiteColor];
    b.layer.cornerRadius = 6;
    b.layer.borderWidth = primary ? 0 : 1;
    b.layer.borderColor = [UIColor colorWithRed:0.83 green:0.78 blue:0.72 alpha:1].CGColor;
    CGSize s = [title sizeWithFont:b.titleLabel.font];
    b.frame = CGRectMake(x, 8, s.width + 22, 28);
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)rebuildStrip {
    if (!_strip) return;
    for (UIView *sv in [[_strip.subviews copy] autorelease]) if ([sv isKindOfClass:[UIButton class]]) [sv removeFromSuperview];
    ZNStore *st = [ZNStore shared];

    NSUInteger n = st.activeFilterCount;
    NSString *f = n ? [NSString stringWithFormat:@"Фільтри · %lu", (unsigned long)n] : @"Фільтри";

    NSArray *fs = st.filterStores;
    NSString *stores;
    if (!fs.count) stores = @"Усі магазини";
    else if (fs.count == 1) stores = [st storeName:[fs objectAtIndex:0]];
    else stores = [NSString stringWithFormat:@"%@ +%lu", [st storeName:[fs objectAtIndex:0]], (unsigned long)fs.count - 1];

    NSString *group;
    NSArray *fc = st.filterCategories;
    if (fc.count == 1) group = [st categoryName:[fc objectAtIndex:0]];
    else if (fc.count > 1) group = [NSString stringWithFormat:@"Категорій: %lu", (unsigned long)fc.count];
    else group = st.filterGroup == ZNGroupFood ? @"Продукти" : (st.filterGroup == ZNGroupHome ? @"Для дому" : @"Усі товари");

    NSString *sort = kSortTitles[MIN(3, MAX(0, (int)st.sortMode))];

    CGFloat x = 8;
    UIButton *b;
    b = [self chip:f primary:YES action:@selector(openFilters) x:x];                         [_strip addSubview:b]; x = CGRectGetMaxX(b.frame) + 6;
    b = [self chip:[stores stringByAppendingString:@" ▾"] primary:NO action:@selector(openFilters) x:x]; [_strip addSubview:b]; x = CGRectGetMaxX(b.frame) + 6;
    b = [self chip:[group stringByAppendingString:@" ▾"] primary:NO action:@selector(openFilters) x:x];  [_strip addSubview:b]; x = CGRectGetMaxX(b.frame) + 6;
    b = [self chip:[sort stringByAppendingString:@" ▾"] primary:NO action:@selector(pickSort) x:x];      [_strip addSubview:b]; x = CGRectGetMaxX(b.frame) + 8;
    _strip.contentSize = CGSizeMake(x, 44);
}

- (void)openFilters {
    [_search resignFirstResponder];
    ZNFiltersViewController *f = [[[ZNFiltersViewController alloc] init] autorelease];
    UINavigationController *n = [[[UINavigationController alloc] initWithRootViewController:f] autorelease];
    [self presentViewController:n animated:YES completion:nil];
}

- (void)pickSort {
    [_search resignFirstResponder];
    UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:@"Сортування" delegate:self cancelButtonTitle:nil
                                      destructiveButtonTitle:nil otherButtonTitles:nil] autorelease];
    for (int i = 0; i < 4; i++) [s addButtonWithTitle:kSortTitles[i]];
    s.cancelButtonIndex = [s addButtonWithTitle:@"Скасувати"];
    if (self.tabBarController) [s showFromTabBar:self.tabBarController.tabBar];
    else [s showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {
    if (i < 0 || i == s.cancelButtonIndex || i > 3) return;
    [[ZNStore shared] setSortMode:(ZNSort)i];
    if (_rows.count) [_grid scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
}

#pragma mark - data

- (void)reload {
    ZNStore *st = [ZNStore shared];
    NSArray *rows;
    if (_fixedQuery) {
        rows = [[st itemsMatchingText:_fixedQuery inItems:st.allItems] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [[b objectForKey:@"sc"] compare:[a objectForKey:@"sc"]];
        }];
    } else {
        rows = _search.text.length ? [st itemsMatchingText:_search.text inItems:st.items] : st.items;
    }
    [_rows release];
    _rows = [rows retain];
    [self rebuildStrip];
    [_grid reloadData];

    if (_rows.count) _empty.hidden = YES;
    else {
        _empty.hidden = NO;
        if (st.loading && !st.allItems.count) _empty.text = @"Завантаження акцій…";
        else if (!st.allItems.count) _empty.text = @"Немає даних.\nПотягніть униз, щоб оновити.";
        else if (_search.text.length) _empty.text = [NSString stringWithFormat:@"Нічого не знайдено за «%@»", _search.text];
        else _empty.text = @"За цими фільтрами акцій немає.\nСпробуйте змінити фільтри.";
    }
}

- (void)pulled { [[ZNStore shared] refresh]; }

- (void)loadingChanged {
    if (![ZNStore shared].loading) [_refresh endRefreshing];
    if (!_rows.count) [self reload];
}

- (void)failed:(NSNotification *)n {
    [_refresh endRefreshing];
    if (!self.isViewLoaded || !self.view.window || self.navigationController.topViewController != self) return;
    NSError *e = [n.userInfo objectForKey:@"error"];
    NSString *msg = [ZNStore shared].allItems.count
        ? [NSString stringWithFormat:@"%@\nПоказано збережені дані.", e.localizedDescription] : e.localizedDescription;
    [[[[UIAlertView alloc] initWithTitle:@"Немає з'єднання" message:msg delegate:nil
                       cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];
}

#pragma mark - search

- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reload) object:nil];
    [self performSelector:@selector(reload) withObject:nil afterDelay:0.3];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)sb { [sb resignFirstResponder]; }
- (void)searchBarTextDidBeginEditing:(UISearchBar *)sb { [sb setShowsCancelButton:YES animated:YES]; }
- (void)searchBarTextDidEndEditing:(UISearchBar *)sb { [sb setShowsCancelButton:NO animated:YES]; }
- (void)searchBarCancelButtonClicked:(UISearchBar *)sb { sb.text = @""; [sb resignFirstResponder]; [self reload]; }
- (void)scrollViewWillBeginDragging:(UIScrollView *)sv { [_search resignFirstResponder]; }

#pragma mark - grid

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s { return _rows.count; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    ZNGridCell *c = [cv dequeueReusableCellWithReuseIdentifier:@"g" forIndexPath:ip];
    c.item = [_rows objectAtIndex:ip.item];
    return c;
}

- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewLayout *)l sizeForItemAtIndexPath:(NSIndexPath *)ip {
    return [ZNGridCell sizeForWidth:cv.bounds.size.width columns:NULL];
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    [cv deselectItemAtIndexPath:ip animated:YES];
    ZNDealViewController *d = [[[ZNDealViewController alloc] initWithItem:[_rows objectAtIndex:ip.item]] autorelease];
    [self.navigationController pushViewController:d animated:YES];
}

@end
