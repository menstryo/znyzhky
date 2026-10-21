#import "ZNLeafletsViewController.h"
#import "ZNImageLoader.h"
#import "ZNTheme.h"
#import "ZNStore.h"
#import <QuartzCore/QuartzCore.h>

static NSString *ZNLeafletDates(NSDictionary *l) {
    NSString *from = ZNDateShort([l objectForKey:@"from"]), *to = ZNDateShort([l objectForKey:@"to"]);
    NSInteger left = ZNDaysLeft([l objectForKey:@"to"]);
    NSString *range = (from && to) ? [NSString stringWithFormat:@"%@ – %@", from, to] : (to ? [NSString stringWithFormat:@"до %@", to] : @"");
    if (left == 0) return [range stringByAppendingString:@" · останній день"];
    if (left > 0 && left != NSNotFound && left <= 3) return [range stringByAppendingFormat:@" · ще %ld дн.", (long)left];
    return range;
}

#pragma mark - список газеток

@implementation ZNLeafletsViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.title = @"Газетки";
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = ZN_BG;
    self.tableView.separatorColor = [UIColor colorWithRed:0.88 green:0.83 blue:0.78 alpha:1];
    self.tableView.rowHeight = 96;
    self.tableView.tableFooterView = [[[UIView alloc] init] autorelease];
    if ([self respondsToSelector:@selector(setRefreshControl:)]) {
        UIRefreshControl *rc = [[[UIRefreshControl alloc] init] autorelease];
        [rc addTarget:self action:@selector(pulled) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = rc;
    }
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reload) name:ZNStoreDidUpdateNotification object:nil];
    [nc addObserver:self selector:@selector(loadingChanged) name:ZNStoreLoadingNotification object:nil];
    [self reload];
}

- (void)pulled { [[ZNStore shared] refresh]; }
- (void)loadingChanged { if (![ZNStore shared].loading) [self.refreshControl endRefreshing]; [self reload]; }

- (void)reload {
    ZNStore *st = [ZNStore shared];
    NSString *city = st.cityName;
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:(city ?: @"Місто")
                                                                               style:UIBarButtonItemStyleBordered
                                                                              target:self action:@selector(pickCity)] autorelease];
    [self.tableView reloadData];

    NSString *msg = nil;
    if (!st.cityId) msg = @"Оберіть місто — тут з'являться акційні газетки місцевих мереж (Сім23, Форта, Салют, Фора).";
    else if (!st.leaflets.count) msg = st.loading ? @"Завантаження…" :
        [NSString stringWithFormat:@"Для міста %@ газеток зараз немає.\n\nЗагальнонаціональні акції — на вкладці «Акції».", city];
    if (msg) {
        UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 160)] autorelease];
        l.text = msg;
        l.numberOfLines = 0;
        l.textAlignment = NSTextAlignmentCenter;
        l.textColor = ZN_TEXT_MUTED;
        l.font = [UIFont systemFontOfSize:15];
        l.backgroundColor = [UIColor clearColor];
        UIView *wrap = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 180)] autorelease];
        l.frame = CGRectInset(wrap.bounds, 28, 10);
        l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [wrap addSubview:l];
        self.tableView.tableHeaderView = wrap;
    } else {
        self.tableView.tableHeaderView = nil;
    }
}

- (void)pickCity {
    ZNCityPickerViewController *p = [[[ZNCityPickerViewController alloc] init] autorelease];
    [self.navigationController pushViewController:p animated:YES];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [ZNStore shared].leaflets.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"lf"];
    UIImageView *cover;
    if (!c) {
        c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"lf"] autorelease];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        c.textLabel.font = [UIFont boldSystemFontOfSize:17];
        c.detailTextLabel.numberOfLines = 2;
        c.detailTextLabel.textColor = ZN_TEXT_MUTED;
        cover = [[[UIImageView alloc] initWithFrame:CGRectMake(10, 8, 58, 80)] autorelease];
        cover.tag = 77;
        cover.contentMode = UIViewContentModeScaleAspectFill;
        cover.clipsToBounds = YES;
        cover.backgroundColor = [UIColor whiteColor];
        cover.layer.borderWidth = 1;
        cover.layer.borderColor = [UIColor colorWithRed:0.86 green:0.80 blue:0.75 alpha:1].CGColor;
        [c.contentView addSubview:cover];
        c.indentationLevel = 7; // місце під обкладинку
        c.indentationWidth = 10;
    }
    cover = (UIImageView *)[c.contentView viewWithTag:77];
    NSDictionary *l = [[ZNStore shared].leaflets objectAtIndex:ip.row];
    NSArray *pages = [l objectForKey:@"pages"];
    c.textLabel.text = [l objectForKey:@"name"];
    BOOL cards = pages.count && [[[pages objectAtIndex:0] objectForKey:@"w"] floatValue] < 400;
    c.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@ · %lu %@", [l objectForKey:@"title"] ?: @"",
                              ZNLeafletDates(l), (unsigned long)pages.count, cards ? @"тов." : @"стор."];
    NSURL *u = pages.count ? [[ZNStore shared] urlForPath:[[pages objectAtIndex:0] objectForKey:@"i"]] : nil;
    cover.image = [[ZNImageLoader shared] cachedImageForURL:u];
    if (!cover.image && u) {
        [[ZNImageLoader shared] loadURL:u done:^(UIImage *img) {
            UITableViewCell *now = [tv cellForRowAtIndexPath:ip];
            if (now) [(UIImageView *)[now.contentView viewWithTag:77] setImage:img];
        }];
    }
    return c;
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)c forRowAtIndexPath:(NSIndexPath *)ip {
    c.backgroundColor = ZN_BG;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *l = [[ZNStore shared].leaflets objectAtIndex:ip.row];
    [self.navigationController pushViewController:[[[ZNLeafletViewController alloc] initWithLeaflet:l] autorelease] animated:YES];
}

@end

#pragma mark - збільшена сторінка

@interface ZNPageZoomViewController : UIViewController <UIScrollViewDelegate> {
    UIScrollView *_scroll;
    UIImageView *_iv;
    NSURL *_url;
}
- (id)initWithURL:(NSURL *)url;
@end

@implementation ZNPageZoomViewController
- (id)initWithURL:(NSURL *)url {
    if ((self = [super initWithNibName:nil bundle:nil])) { _url = [url retain]; self.title = @"Сторінка"; }
    return self;
}
- (void)dealloc { _scroll.delegate = nil; [_scroll release]; [_iv release]; [_url release]; [super dealloc]; }
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.view = v;
    _scroll = [[UIScrollView alloc] initWithFrame:v.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.delegate = self;
    _scroll.maximumZoomScale = 3;
    _scroll.minimumZoomScale = 1;
    _iv = [[UIImageView alloc] initWithFrame:_scroll.bounds];
    _iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _iv.contentMode = UIViewContentModeScaleAspectFit;
    [_scroll addSubview:_iv];
    [v addSubview:_scroll];
    UITapGestureRecognizer *dbl = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)] autorelease];
    dbl.numberOfTapsRequired = 2;
    [_scroll addGestureRecognizer:dbl];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) self.edgesForExtendedLayout = UIRectEdgeNone;
    _iv.image = [[ZNImageLoader shared] cachedImageForURL:_url];
    if (!_iv.image) [[ZNImageLoader shared] loadURL:_url done:^(UIImage *img) { _iv.image = img; }];
}
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)sv { return _iv; }
- (void)doubleTap:(UITapGestureRecognizer *)g {
    if (_scroll.zoomScale > 1.01) [_scroll setZoomScale:1 animated:YES];
    else {
        CGPoint p = [g locationInView:_iv];
        [_scroll zoomToRect:CGRectMake(p.x - 60, p.y - 80, 120, 160) animated:YES];
    }
}
@end

#pragma mark - газетка

@interface ZNLeafletViewController () {
    NSDictionary *_leaflet;
}
@end

@implementation ZNLeafletViewController

- (id)initWithLeaflet:(NSDictionary *)leaflet {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _leaflet = [leaflet retain];
        self.title = [leaflet objectForKey:@"name"];
    }
    return self;
}

- (void)dealloc { [_leaflet release]; [super dealloc]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    UILabel *head = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 34)] autorelease];
    head.text = [NSString stringWithFormat:@"%@ · %@", [_leaflet objectForKey:@"title"] ?: @"", ZNLeafletDates(_leaflet)];
    head.textAlignment = NSTextAlignmentCenter;
    head.font = [UIFont systemFontOfSize:13];
    head.textColor = ZN_TEXT_MUTED;
    head.backgroundColor = [UIColor clearColor];
    head.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.tableView.tableHeaderView = head;
}

- (NSArray *)pages { return [_leaflet objectForKey:@"pages"]; }

// газетка з карток товарів (Форта: 300×300) — по 2 в ряд, звичайні сторінки — по одній
- (NSInteger)cols {
    NSArray *p = self.pages;
    if (!p.count) return 1;
    return [[[p objectAtIndex:0] objectForKey:@"w"] floatValue] < 400 ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    NSInteger c = self.cols;
    return (self.pages.count + c - 1) / c;
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    NSInteger cols = self.cols;
    NSDictionary *p = [self.pages objectAtIndex:ip.row * cols];
    CGFloat w = [[p objectForKey:@"w"] floatValue], h = [[p objectForKey:@"h"] floatValue];
    CGFloat width = floorf((tv.bounds.size.width - 6 - 6 * cols) / cols);
    return (w > 0 ? floorf(width * h / w) : width * 1.4f) + 6;
}

- (void)layoutCell:(UITableViewCell *)c {
    NSInteger cols = self.cols;
    CGRect b = c.contentView.bounds;
    CGFloat width = floorf((b.size.width - 6 - 6 * cols) / cols);
    for (NSInteger k = 0; k < 2; k++) {
        UIView *iv = [c.contentView viewWithTag:10 + k];
        iv.frame = CGRectMake(6 + k * (width + 6), 3, width, b.size.height - 6);
    }
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"pg"];
    if (!c) {
        c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"pg"] autorelease];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        for (NSInteger k = 0; k < 2; k++) {
            UIImageView *iv = [[[UIImageView alloc] init] autorelease];
            iv.tag = 10 + k;
            iv.backgroundColor = [UIColor whiteColor];
            iv.contentMode = UIViewContentModeScaleAspectFit;
            iv.userInteractionEnabled = YES;
            [iv addGestureRecognizer:[[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapPage:)] autorelease]];
            [c.contentView addSubview:iv];
        }
    }
    NSInteger cols = self.cols;
    NSArray *pages = self.pages;
    for (NSInteger k = 0; k < 2; k++) {
        UIImageView *iv = (UIImageView *)[c.contentView viewWithTag:10 + k];
        NSInteger idx = ip.row * cols + k;
        if (k >= cols || idx >= (NSInteger)pages.count) { iv.hidden = YES; iv.image = nil; continue; }
        iv.hidden = NO;
        NSURL *u = [[ZNStore shared] urlForPath:[[pages objectAtIndex:idx] objectForKey:@"i"]];
        iv.accessibilityLabel = [NSString stringWithFormat:@"%ld", (long)idx];
        iv.image = [[ZNImageLoader shared] cachedImageForURL:u];
        if (!iv.image && u) {
            [[ZNImageLoader shared] loadURL:u done:^(UIImage *img) {
                UITableViewCell *now = [tv cellForRowAtIndexPath:ip];
                if (now) [(UIImageView *)[now.contentView viewWithTag:10 + k] setImage:img];
            }];
        }
    }
    [self layoutCell:c];
    return c;
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)c forRowAtIndexPath:(NSIndexPath *)ip {
    c.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1];
    NSInteger cols = self.cols, last = (NSInteger)self.pages.count - 1;
    for (NSInteger k = 0; k < 2; k++) {
        UIView *iv = [c.contentView viewWithTag:10 + k];
        CGRect b = c.contentView.bounds;
        CGFloat width = floorf((b.size.width - 6 - 6 * cols) / cols);
        iv.frame = CGRectMake(6 + k * (width + 6), 3, width, b.size.height - 6);
        iv.hidden = k >= cols || ip.row * cols + k > last;
    }
}

- (void)tapPage:(UITapGestureRecognizer *)g {
    NSInteger idx = [g.view.accessibilityLabel integerValue];
    if (idx < 0 || idx >= (NSInteger)self.pages.count) return;
    NSURL *u = [[ZNStore shared] urlForPath:[[self.pages objectAtIndex:idx] objectForKey:@"i"]];
    ZNPageZoomViewController *z = [[[ZNPageZoomViewController alloc] initWithURL:u] autorelease];
    z.title = [NSString stringWithFormat:@"%ld з %lu", (long)idx + 1, (unsigned long)self.pages.count];
    [self.navigationController pushViewController:z animated:YES];
}

@end

#pragma mark - вибір міста

@implementation ZNCityPickerViewController
@synthesize modal = _modal;

- (id)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) self.title = @"Місто";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = ZN_BG;
    if (_modal) {
        UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 64)] autorelease];
        l.text = @"Для місцевих мереж (Metro, Novus, Сім23, Форта…)\nі газеток. Змінити можна в «Ще».";
        l.numberOfLines = 2;
        l.textAlignment = NSTextAlignmentCenter;
        l.font = [UIFont systemFontOfSize:13];
        l.textColor = ZN_TEXT_MUTED;
        l.backgroundColor = [UIColor clearColor];
        l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.tableView.tableHeaderView = l;
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Пізніше" style:UIBarButtonItemStyleBordered
                                                                                  target:self action:@selector(close)] autorelease];
    }
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

// якщо index ще не завантажено — вбудований список
- (NSArray *)cities {
    NSArray *c = [ZNStore shared].cities;
    if (c.count) return c;
    NSArray *names = @[@"Київ", @"Харків", @"Одеса", @"Дніпро", @"Львів", @"Запоріжжя", @"Кривий Ріг", @"Вінниця", @"Полтава",
                       @"Миколаїв", @"Чернігів", @"Черкаси", @"Суми", @"Житомир", @"Хмельницький", @"Чернівці", @"Рівне",
                       @"Івано-Франківськ", @"Тернопіль", @"Луцьк", @"Кропивницький", @"Ужгород"];
    NSArray *ids = @[@"kyiv", @"kharkiv", @"odesa", @"dnipro", @"lviv", @"zaporizh", @"kryvyirih", @"vinnytsia", @"poltava",
                     @"mykolaiv", @"chernihiv", @"cherkasy", @"sumy", @"zhytomyr", @"khmeln", @"chernivtsi", @"rivne",
                     @"ifrank", @"ternopil", @"lutsk", @"kropyv", @"uzhhorod"];
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger i = 0; i < ids.count; i++) [out addObject:@{ @"id": [ids objectAtIndex:i], @"name": [names objectAtIndex:i] }];
    return out;
}

- (NSArray *)sortedCities {
    return [self.cities sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [[a objectForKey:@"name"] localizedCompare:[b objectForKey:@"name"]];
    }];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.cities.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!c) c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"c"] autorelease];
    NSDictionary *city = [self.sortedCities objectAtIndex:ip.row];
    BOOL sel = [[city objectForKey:@"id"] isEqual:[ZNStore shared].cityId];
    c.textLabel.text = [city objectForKey:@"name"];
    c.textLabel.textColor = sel ? ZN_ACCENT_DARK : [UIColor colorWithRed:0.17 green:0.13 blue:0.11 alpha:1];
    NSInteger lf = [[city objectForKey:@"leaflets"] integerValue];
    c.detailTextLabel.text = lf ? [NSString stringWithFormat:@"газеток: %ld", (long)lf] : nil;
    c.detailTextLabel.textColor = ZN_TEXT_MUTED;
    if (sel) {
        UILabel *mark = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 22, 22)] autorelease];
        mark.text = @"✓"; mark.font = [UIFont boldSystemFontOfSize:20]; mark.textColor = ZN_ACCENT;
        mark.backgroundColor = [UIColor clearColor];
        c.accessoryView = mark;
    } else c.accessoryView = nil;
    return c;
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)c forRowAtIndexPath:(NSIndexPath *)ip {
    c.backgroundColor = ZN_BG;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    [[ZNStore shared] setCityId:[[self.sortedCities objectAtIndex:ip.row] objectForKey:@"id"]];
    if (_modal) [self close];
    else [self.navigationController popViewControllerAnimated:YES];
}

@end
