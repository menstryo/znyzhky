#import "ZNShoppingListViewController.h"
#import "ZNDealViewController.h"
#import "ZNDealCell.h"
#import "ZNTheme.h"
#import "ZNStore.h"
#import <QuartzCore/QuartzCore.h>

#define ZN_PAPER [UIColor colorWithRed:1.0 green:0.99 blue:0.95 alpha:1]
#define ZN_ROW   ZN_PAPER   // один фон для всієї сторінки
#define ZN_RULE  [UIColor colorWithRed:0.80 green:0.87 blue:0.92 alpha:1]
#define ZN_MARGIN_LINE [UIColor colorWithRed:0.93 green:0.65 blue:0.60 alpha:1]

// рукописний шрифт (за замовчуванням на iOS 6), як в оригінальних «Нотатках» (Marker Felt); iOS 7+ — системний
static UIFont *ZNNoteFont(CGFloat size, BOOL bold) {
    if ([ZNTheme handwriting]) {
        UIFont *f = [UIFont fontWithName:bold ? @"MarkerFelt-Wide" : @"MarkerFelt-Thin" size:size + 3];
        if (f) return f;
    }
    return bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
}

#define ZN_LIST_ACCESSORY 33   // ширина стрілки праворуч

#pragma mark - зошитовий аркуш

// Порожня частина сторінки — «зошит»: блакитні лінії через 52 pt і червона лінія поля.
@interface ZNPaperView : UIView
@end
@implementation ZNPaperView
- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { self.backgroundColor = ZN_PAPER; self.contentMode = UIViewContentModeRedraw; }
    return self;
}
- (void)drawRect:(CGRect)r {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1);
    CGContextSetStrokeColorWithColor(ctx, ZN_RULE.CGColor);
    for (CGFloat y = 51.5f; y < self.bounds.size.height; y += 52) {
        CGContextMoveToPoint(ctx, 0, y); CGContextAddLineToPoint(ctx, self.bounds.size.width, y);
    }
    CGContextStrokePath(ctx);
    CGContextSetStrokeColorWithColor(ctx, ZN_MARGIN_LINE.CGColor);
    CGContextMoveToPoint(ctx, 44.5f, 0); CGContextAddLineToPoint(ctx, 44.5f, self.bounds.size.height);
    CGContextStrokePath(ctx);
}
@end

#pragma mark - checkbox

@interface ZNCheckButton : UIButton
@property (nonatomic, assign) BOOL checked;
@end

@implementation ZNCheckButton
@synthesize checked = _checked;
- (void)setChecked:(BOOL)c { _checked = c; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)r {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect box = CGRectMake(roundf((r.size.width - 20) / 2) + 0.5f, roundf((r.size.height - 20) / 2) + 0.5f, 19, 19);
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:box cornerRadius:4];
    if (_checked) { [ZN_ACCENT setFill]; [p fill]; }
    else { [[UIColor whiteColor] setFill]; [p fill]; }
    [(_checked ? ZN_ACCENT_DARK : [UIColor colorWithRed:0.75 green:0.68 blue:0.62 alpha:1]) setStroke];
    p.lineWidth = 1.5;
    [p stroke];
    if (_checked) {
        CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(ctx, 2.5);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineJoin(ctx, kCGLineJoinRound);
        CGContextMoveToPoint(ctx, box.origin.x + 4.5, box.origin.y + 10);
        CGContextAddLineToPoint(ctx, box.origin.x + 8, box.origin.y + 14);
        CGContextAddLineToPoint(ctx, box.origin.x + 15, box.origin.y + 5);
        CGContextStrokePath(ctx);
    }
}
@end

#pragma mark - cell

@interface ZNListCell : UITableViewCell {
@public
    ZNCheckButton *check;
    ZNStrikeLabel *title;
    UILabel *meta;
    UILabel *price;
}
@end

@implementation ZNListCell
- (id)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid])) {
        self.backgroundColor = ZN_ROW;
        self.contentView.backgroundColor = ZN_ROW;
        UIView *sel = [[[UIView alloc] init] autorelease];
        sel.backgroundColor = [UIColor colorWithRed:0.98 green:0.92 blue:0.88 alpha:1];
        self.selectedBackgroundView = sel;
        check = [[ZNCheckButton alloc] initWithFrame:CGRectZero];
        check.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:check];
        title = [[ZNStrikeLabel alloc] init];
        title.font = ZNNoteFont(15, NO);
        title.numberOfLines = 0;
        title.lineBreakMode = NSLineBreakByWordWrapping;
        title.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:title];
        meta = [[UILabel alloc] init];
        meta.font = ZNNoteFont(11, NO);
        meta.textColor = ZN_TEXT_MUTED;
        meta.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:meta];
        price = [[UILabel alloc] init];
        price.font = ZNNoteFont(15, YES);
        price.textAlignment = NSTextAlignmentRight;
        price.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:price];
        // червона лінія поля, як у зошиті
        UIView *margin = [[[UIView alloc] initWithFrame:CGRectMake(44, 0, 1, 52)] autorelease];
        margin.backgroundColor = ZN_MARGIN_LINE;
        margin.tag = 901;
        [self.contentView addSubview:margin];
        // власна лінія знизу: на iOS 7+ системний роздільник під останнім рядком не малюється
        UIView *rule = [[[UIView alloc] initWithFrame:CGRectMake(0, 51, 4000, 1)] autorelease];
        rule.backgroundColor = ZN_RULE;
        rule.tag = 902;
        [self addSubview:rule];
    }
    return self;
}
- (void)dealloc { [check release]; [title release]; [meta release]; [price release]; [super dealloc]; }
// висота рядка під повну назву: щонайменше одна «клітинка» зошита (52)
+ (CGFloat)heightForTitle:(NSString *)t price:(NSString *)p width:(CGFloat)tableW {
    CGFloat w = tableW - ZN_LIST_ACCESSORY;
    CGSize ps = [p sizeWithFont:ZNNoteFont(15, YES)];
    CGFloat tw = w - 54 - ps.width - 18;
    CGSize ts = [t sizeWithFont:ZNNoteFont(15, NO) constrainedToSize:CGSizeMake(tw, 400) lineBreakMode:NSLineBreakByWordWrapping];
    CGFloat mh = ceilf(ZNNoteFont(11, NO).lineHeight);
    return MAX(52, ceilf(7 + ts.height + 2 + mh + 8));
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width, h = self.contentView.bounds.size.height;
    check.frame = CGRectMake(0, 0, 44, h);
    [self.contentView viewWithTag:901].frame = CGRectMake(44, 0, 1, h);
    UIView *rule = [self viewWithTag:902];
    rule.frame = CGRectMake(0, self.bounds.size.height - 1, self.bounds.size.width, 1);
    [self bringSubviewToFront:rule];
    CGSize ps = [price.text sizeWithFont:price.font];
    price.frame = CGRectMake(w - ps.width - 10, 7, ps.width, ceilf(price.font.lineHeight));
    CGFloat tw = w - 54 - ps.width - 18;
    CGSize ts = [title.text sizeWithFont:title.font constrainedToSize:CGSizeMake(tw, 400) lineBreakMode:NSLineBreakByWordWrapping];
    title.frame = CGRectMake(54, 7, tw, ceilf(ts.height));
    CGFloat mh = ceilf(meta.font.lineHeight);
    meta.frame = CGRectMake(54, CGRectGetMaxY(title.frame) + 2, w - 64, mh);
}
@end

#pragma mark - controller

@interface ZNShoppingListViewController () {
    UITableView *_table;
    UIView *_bar;
    UILabel *_total;
    UILabel *_saved;
    UILabel *_empty;
    NSArray *_sections;   // [{title, rows}]
}
@end

@implementation ZNShoppingListViewController

- (id)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        self.title = @"Мій список";
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _table.dataSource = nil; _table.delegate = nil;
    [_table release]; [_bar release]; [_total release]; [_saved release]; [_empty release]; [_sections release];
    [super dealloc];
}

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = ZN_PAPER;
    self.view = v;
    CGFloat barH = 48;
    _table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, v.bounds.size.width, v.bounds.size.height - barH)
                                          style:UITableViewStylePlain];
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _table.backgroundColor = ZN_PAPER;
    _table.separatorStyle = UITableViewCellSeparatorStyleNone;   // лінії малюють самі рядки
    _table.rowHeight = 52;
    _table.dataSource = self;
    _table.delegate = self;
    // аркуш під списком — сторінка «намальована» до низу, навіть коли товарів мало
    _table.tableFooterView = [[[ZNPaperView alloc] initWithFrame:CGRectMake(0, 0, v.bounds.size.width, 0)] autorelease];
    [v addSubview:_table];

    _bar = [[UIView alloc] initWithFrame:CGRectMake(0, v.bounds.size.height - barH, v.bounds.size.width, barH)];
    _bar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _bar.backgroundColor = ZN_BG_HEADER;
    UIView *line = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 4000, 1)] autorelease];
    line.backgroundColor = [UIColor colorWithRed:0.86 green:0.80 blue:0.75 alpha:1];
    [_bar addSubview:line];
    _total = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, v.bounds.size.width - 24, 20)];
    _total.font = ZNNoteFont(15, YES);
    _total.backgroundColor = [UIColor clearColor];
    _total.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_bar addSubview:_total];
    _saved = [[UILabel alloc] initWithFrame:CGRectMake(12, 25, v.bounds.size.width - 24, 17)];
    _saved.font = ZNNoteFont(13, NO);
    _saved.textColor = [UIColor colorWithRed:0.22 green:0.50 blue:0.27 alpha:1];
    _saved.backgroundColor = [UIColor clearColor];
    _saved.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_bar addSubview:_saved];
    [v addSubview:_bar];

    _empty = [[UILabel alloc] initWithFrame:CGRectMake(56, 60, v.bounds.size.width - 76, 160)];
    _empty.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _empty.numberOfLines = 0;
    _empty.textAlignment = NSTextAlignmentLeft;
    _empty.textColor = ZN_TEXT_MUTED;
    _empty.font = ZNNoteFont(15, NO);
    _empty.backgroundColor = [UIColor clearColor];
    _empty.text = @"Список порожній.\n\nНатисніть «+ У список» на картці акції — товар з'явиться тут, згрупований за магазинами.";
    [_table addSubview:_empty];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) self.edgesForExtendedLayout = UIRectEdgeNone;
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Очистити" style:UIBarButtonItemStyleBordered
                                                                              target:self action:@selector(clearTapped)] autorelease];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reload) name:ZNStoreListChangedNotification object:nil];
    [nc addObserver:self selector:@selector(reload) name:ZNStoreDidUpdateNotification object:nil];
    [self reload];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [_table setEditing:editing animated:animated];
}

- (void)reload {
    ZNStore *st = [ZNStore shared];
    NSArray *entries = [st listEntries];
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *order = [NSMutableArray arrayWithArray:[st.stores valueForKey:@"id"]];
    for (NSDictionary *e in entries) if ([e objectForKey:@"s"] && ![order containsObject:[e objectForKey:@"s"]]) [order addObject:[e objectForKey:@"s"]];
    NSMutableArray *gone = [NSMutableArray array];
    double total = 0, saved = 0;
    NSUInteger open = 0;
    for (NSString *sid in order) {
        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *e in entries) {
            if (![[e objectForKey:@"s"] isEqual:sid]) continue;
            if ([[e objectForKey:@"gone"] boolValue]) { [gone addObject:e]; continue; }
            [rows addObject:e];
        }
        // некуплені зверху
        [rows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [[a objectForKey:@"done"] compare:[b objectForKey:@"done"]];
        }];
        if (rows.count) [sections addObject:@{ @"title": [st storeName:sid], @"rows": rows }];
    }
    if (gone.count) [sections addObject:@{ @"title": @"Акція вже завершилась", @"rows": gone }];
    for (NSDictionary *e in entries) {
        double p = [[e objectForKey:@"p"] doubleValue], o = [[e objectForKey:@"o"] doubleValue];
        total += p; saved += MAX(0, o - p);
        if (![[e objectForKey:@"done"] boolValue]) open++;
    }
    [_sections release];
    _sections = [sections retain];
    _total.font = ZNNoteFont(15, YES); _saved.font = ZNNoteFont(13, NO); _empty.font = ZNNoteFont(15, NO);
    [_table reloadData];

    BOOL empty = entries.count == 0;
    _empty.hidden = !empty;
    _bar.hidden = empty;
    // без смуги «Разом» аркуш тягнеться до самого низу
    CGRect f = _table.frame;
    f.size.height = self.view.bounds.size.height - (empty ? 0 : _bar.bounds.size.height);
    _table.frame = f;
    [_table layoutIfNeeded];
    [self fitPaper];
    self.navigationItem.rightBarButtonItem.enabled = !empty;
    _total.text = [NSString stringWithFormat:@"Разом: %@   ·   залишилось %lu з %lu", ZNPrice(@(total)),
                   (unsigned long)open, (unsigned long)entries.count];
    _saved.text = [NSString stringWithFormat:@"Економія завдяки акціям: %@", ZNPrice(@(saved))];
}

- (void)clearTapped {
    UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil
                                      destructiveButtonTitle:@"Очистити весь список"
                                           otherButtonTitles:@"Прибрати куплені", nil] autorelease];
    s.cancelButtonIndex = [s addButtonWithTitle:@"Скасувати"];
    [s showFromTabBar:self.tabBarController.tabBar];
}

- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {
    if (i == s.destructiveButtonIndex) [[ZNStore shared] clearListOnlyDone:NO];
    else if (i == s.firstOtherButtonIndex) [[ZNStore shared] clearListOnlyDone:YES];
}

#pragma mark - table

- (NSDictionary *)entryAt:(NSIndexPath *)ip {
    return [[[_sections objectAtIndex:ip.section] objectForKey:@"rows"] objectAtIndex:ip.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _sections.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return [[[_sections objectAtIndex:s] objectForKey:@"rows"] count];
}

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, tv.bounds.size.width, 30)] autorelease];
    v.backgroundColor = ZN_PAPER;
    UIView *rule = [[[UIView alloc] initWithFrame:CGRectMake(0, 29, tv.bounds.size.width, 1)] autorelease];
    rule.backgroundColor = ZN_RULE;
    rule.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [v addSubview:rule];
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(54, 6, tv.bounds.size.width - 64, 20)] autorelease];
    l.text = [[_sections objectAtIndex:s] objectForKey:@"title"];
    l.font = ZNNoteFont(15, YES);
    l.textColor = ZN_ACCENT_DARK;
    l.backgroundColor = [UIColor clearColor];
    [v addSubview:l];
    UIView *margin = [[[UIView alloc] initWithFrame:CGRectMake(44, 0, 1, 30)] autorelease];
    margin.backgroundColor = ZN_MARGIN_LINE;
    [v addSubview:margin];
    return v;
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return 30; }

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *e = [self entryAt:ip];
    return [ZNListCell heightForTitle:[e objectForKey:@"t"] price:ZNPrice([e objectForKey:@"p"]) width:tv.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    ZNListCell *c = (ZNListCell *)[tv dequeueReusableCellWithIdentifier:@"l"];
    if (!c) {
        c = [[[ZNListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"l"] autorelease];
        [c->check addTarget:self action:@selector(checkTapped:event:) forControlEvents:UIControlEventTouchUpInside];
    }
    // шрифт можна перемкнути в «Ще» — задаємо щоразу
    c->title.font = ZNNoteFont(15, NO); c->meta.font = ZNNoteFont(11, NO); c->price.font = ZNNoteFont(15, YES);
    NSDictionary *e = [self entryAt:ip];
    BOOL done = [[e objectForKey:@"done"] boolValue];
    BOOL gone = [[e objectForKey:@"gone"] boolValue];
    c->check.checked = done;
    c->title.text = [e objectForKey:@"t"];
    c->title.noStrike = !done;
    c->title.textColor = (done || gone) ? ZN_TEXT_MUTED : [UIColor colorWithRed:0.17 green:0.13 blue:0.11 alpha:1];
    c->price.text = ZNPrice([e objectForKey:@"p"]);
    c->price.textColor = done ? ZN_TEXT_MUTED : ZN_ACCENT_DARK;
    double p = [[e objectForKey:@"p"] doubleValue], o = [[e objectForKey:@"o"] doubleValue];
    NSMutableArray *meta = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"−%@%%, економія %@", [e objectForKey:@"d"], ZNPrice(@(o - p))]];
    NSInteger left = ZNDaysLeft([e objectForKey:@"e"]);
    if (!gone && left != NSNotFound && left >= 0) [meta addObject:left == 0 ? @"останній день" : [NSString stringWithFormat:@"до %@", ZNDateShort([e objectForKey:@"e"])]];
    c->meta.text = [meta componentsJoinedByString:@" · "];
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)c forRowAtIndexPath:(NSIndexPath *)ip {
    c.backgroundColor = ZN_PAPER;
}

// Аркуш під рядками — рівно до низу екрана, щоб при кількох товарах не було прокрутки.
- (void)fitPaper {
    UIView *foot = _table.tableFooterView;
    CGFloat content = _table.contentSize.height - foot.bounds.size.height;
    CGFloat need = MAX(0, floorf(_table.bounds.size.height - content));
    if (fabsf(foot.bounds.size.height - need) < 1) return;
    CGRect f = foot.frame; f.size.height = need; foot.frame = f;
    _table.tableFooterView = foot; // перепризначення змушує таблицю перерахувати contentSize
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self fitPaper];
}

- (void)checkTapped:(UIButton *)b event:(UIEvent *)ev {
    CGPoint pt = [[[ev allTouches] anyObject] locationInView:_table];
    NSIndexPath *ip = [_table indexPathForRowAtPoint:pt];
    if (!ip) return;
    NSDictionary *e = [self entryAt:ip];
    [[ZNStore shared] setDone:![[e objectForKey:@"done"] boolValue] forKey:[e objectForKey:@"k"]];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    ZNDealViewController *d = [[[ZNDealViewController alloc] initWithItem:[self entryAt:ip]] autorelease];
    [self.navigationController pushViewController:d animated:YES];
}

- (NSString *)tableView:(UITableView *)tv titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)ip { return @"Прибрати"; }

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip {
    if (style == UITableViewCellEditingStyleDelete) [[ZNStore shared] removeFromListKey:[[self entryAt:ip] objectForKey:@"k"]];
}

@end
