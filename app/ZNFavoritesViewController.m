#import "ZNFavoritesViewController.h"
#import "ZNDealListViewController.h"
#import "ZNDealViewController.h"
#import "ZNDealCell.h"
#import "ZNStore.h"

enum { ZNFavItems = 0, ZNFavWords };

@interface ZNFavoritesViewController () {
    UISegmentedControl *_seg;
    NSArray *_favs;
    NSArray *_wordCounts;
}
@end

@implementation ZNFavoritesViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.title = @"Обране";
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_seg release]; [_favs release]; [_wordCounts release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _seg = [[UISegmentedControl alloc] initWithItems:@[@"Товари", @"Слова"]];
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7) _seg.segmentedControlStyle = UISegmentedControlStyleBar;
    _seg.frame = CGRectMake(0, 0, 200, 30);
    _seg.selectedSegmentIndex = ZNFavItems;
    [_seg addTarget:self action:@selector(segChanged) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = _seg;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:ZNStoreDidUpdateNotification object:nil];
    [self segChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (BOOL)wordsMode { return _seg.selectedSegmentIndex == ZNFavWords; }

- (void)segChanged {
    [self setEditing:NO animated:NO];
    if ([self wordsMode]) {
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                                target:self action:@selector(addWord)] autorelease];
    } else {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    }
    self.navigationItem.leftBarButtonItem = [self wordsMode] ? self.editButtonItem : nil;
    [self reload];
}

- (void)reload {
    ZNStore *st = [ZNStore shared];
    [_favs release];
    _favs = [[st favorites] retain];
    NSMutableArray *wc = [NSMutableArray array];
    for (NSString *w in st.watchWords) [wc addObject:@([st itemsMatchingText:w inItems:st.items].count)];
    [_wordCounts release];
    _wordCounts = [wc retain];
    self.tableView.rowHeight = [self wordsMode] ? 50 : [ZNDealCell height];
    [self.tableView reloadData];
    [self updateFooter];
}

- (void)updateFooter {
    NSString *t = nil;
    if (![self wordsMode] && !_favs.count)
        t = @"Тут з'являться товари, які ви позначите зірочкою на сторінці товару.";
    else if ([self wordsMode] && ![ZNStore shared].watchWords.count)
        t = @"Додайте слова, які вас цікавлять — наприклад «кава», «Nivea» чи «підгузки». "
            @"Тут буде видно, скільки таких товарів зараз в акції.";
    if (!t) { self.tableView.tableFooterView = [[[UIView alloc] init] autorelease]; return; }
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 100)] autorelease];
    l.text = t;
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = ZN_TEXT_MUTED;
    l.font = [UIFont systemFontOfSize:14];
    l.backgroundColor = [UIColor clearColor];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIView *wrap = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 120)] autorelease];
    l.frame = CGRectInset(wrap.bounds, 24, 10);
    [wrap addSubview:l];
    self.tableView.tableFooterView = wrap;
}

- (void)addWord {
    UIAlertView *a = [[[UIAlertView alloc] initWithTitle:@"Відстежувати слово"
                                                 message:@"Покажемо всі акційні товари, в назві яких воно є"
                                                delegate:self cancelButtonTitle:@"Скасувати" otherButtonTitles:@"Додати", nil] autorelease];
    a.alertViewStyle = UIAlertViewStylePlainTextInput;
    [a textFieldAtIndex:0].placeholder = @"наприклад: кава";
    [a textFieldAtIndex:0].autocorrectionType = UITextAutocorrectionTypeNo;
    [a show];
}

- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (i == a.cancelButtonIndex) return;
    [[ZNStore shared] addWatchWord:[a textFieldAtIndex:0].text];
    [self reload];
}

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return [self wordsMode] ? [ZNStore shared].watchWords.count : _favs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if ([self wordsMode]) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"w"];
        if (!c) c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"w"] autorelease];
        NSInteger n = [[_wordCounts objectAtIndex:ip.row] integerValue];
        c.textLabel.text = [[ZNStore shared].watchWords objectAtIndex:ip.row];
        c.detailTextLabel.text = n ? [NSString stringWithFormat:@"%ld в акції", (long)n] : @"немає";
        c.detailTextLabel.textColor = n ? ZN_ACCENT_DARK : ZN_TEXT_MUTED;
        c.accessoryType = n ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
        return c;
    }
    ZNDealCell *c = (ZNDealCell *)[tv dequeueReusableCellWithIdentifier:@"deal"];
    if (!c) c = [[[ZNDealCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"deal"] autorelease];
    c.item = [_favs objectAtIndex:ip.row];
    return c;
}

- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip { return YES; }

- (NSString *)tableView:(UITableView *)tv titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)ip { return @"Видалити"; }

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip {
    if (style != UITableViewCellEditingStyleDelete) return;
    if ([self wordsMode]) [[ZNStore shared] removeWatchWordAtIndex:ip.row];
    else [[ZNStore shared] removeFavoriteAtIndex:ip.row];
    // reload вже викликано сповіщенням для слів; для товарів — тут
    [_favs release]; _favs = [[[ZNStore shared] favorites] retain];
    NSMutableArray *wc = [NSMutableArray array];
    for (NSString *w in [ZNStore shared].watchWords)
        [wc addObject:@([[ZNStore shared] itemsMatchingText:w inItems:[ZNStore shared].items].count)];
    [_wordCounts release]; _wordCounts = [wc retain];
    [tv reloadData];
    [self updateFooter];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if ([self wordsMode]) {
        if ([[_wordCounts objectAtIndex:ip.row] integerValue] == 0) return;
        NSString *w = [[ZNStore shared].watchWords objectAtIndex:ip.row];
        ZNDealListViewController *l = [[[ZNDealListViewController alloc] initWithTitle:w filter:nil] autorelease];
        l.searchText = w;
        [self.navigationController pushViewController:l animated:YES];
    } else {
        ZNDealViewController *d = [[[ZNDealViewController alloc] initWithItem:[_favs objectAtIndex:ip.row]] autorelease];
        [self.navigationController pushViewController:d animated:YES];
    }
}

@end
