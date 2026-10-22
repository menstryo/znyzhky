#import "ZNDealViewController.h"
#import "ZNDealCell.h"
#import "ZNGridCell.h"
#import "ZNStore.h"
#import "ZNImageLoader.h"
#import "ZNTheme.h"
#import <QuartzCore/QuartzCore.h>

// Екран товару, варіант «Вітрина»: велике фото на білому, жовтий цінник як у сітці,
// економія, велика коралова кнопка «Додати до списку», нижче — дії.

static UIImage *ZNButtonImage(BOOL pressed, BOOL done) {
    CGSize size = CGSizeMake(30, 44);
    CGFloat scale = [UIScreen mainScreen].scale;
    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectMake(0.5f, 0.5f, size.width - 1, size.height - 2.5f);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:8];
    // тінь
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 1.5f, [UIColor colorWithWhite:0 alpha:0.18].CGColor);
    [[UIColor whiteColor] setFill]; [path fill];
    CGContextRestoreGState(ctx);
    // градієнт
    CGFloat top[3], bot[3];
    if (done) { top[0]=0.36; top[1]=0.66; top[2]=0.36; bot[0]=0.20; bot[1]=0.50; bot[2]=0.22; }
    else      { top[0]=0.89; top[1]=0.42; top[2]=0.36; bot[0]=0.77; bot[1]=0.25; bot[2]=0.19; }
    if (pressed) for (int i = 0; i < 3; i++) { top[i] *= 0.85f; bot[i] *= 0.85f; }
    CGFloat comps[8] = { top[0], top[1], top[2], 1, bot[0], bot[1], bot[2], 1 };
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
    CGContextSaveGState(ctx);
    [path addClip];
    CGContextDrawLinearGradient(ctx, g, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
    // світла лінія зверху
    [[UIColor colorWithWhite:1 alpha:0.28] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 1, size.width, 1));
    CGContextRestoreGState(ctx);
    CGGradientRelease(g); CGColorSpaceRelease(cs);
    // обвідка
    [[UIColor colorWithRed:bot[0] * 0.8f green:bot[1] * 0.8f blue:bot[2] * 0.8f alpha:1] setStroke];
    path.lineWidth = 1; [path stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12)];
}

static UILabel *ZNLbl(UIFont *f, UIColor *c) {
    UILabel *l = [[[UILabel alloc] init] autorelease];
    l.font = f; l.textColor = c; l.backgroundColor = [UIColor clearColor];
    return l;
}

@interface ZNDealViewController () {
    NSDictionary *_item;
    UIButton *_add;
}
@end

@implementation ZNDealViewController

- (id)initWithItem:(NSDictionary *)item {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _item = [item retain];
        self.title = [[ZNStore shared] storeName:[item objectForKey:@"s"]];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_item release]; [_add release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [ZNTheme styleGroupedTable:self.tableView];
    self.tableView.tableHeaderView = [self buildHeader];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateButton)
                                                 name:ZNStoreListChangedNotification object:nil];
}

- (NSString *)metaLine {
    ZNStore *st = [ZNStore shared];
    NSMutableArray *parts = [NSMutableArray array];
    NSString *cat = [st categoryName:[_item objectForKey:@"c"]];
    if (cat.length) [parts addObject:[NSString stringWithFormat:@"%@ %@", [st categoryEmoji:[_item objectForKey:@"c"]], cat]];
    NSString *u = [_item objectForKey:@"u"];
    if ([u isKindOfClass:[NSString class]] && u.length) [parts addObject:[NSString stringWithFormat:@"за %@", u]];
    NSString *e = [_item objectForKey:@"e"];
    if ([[_item objectForKey:@"gone"] boolValue]) [parts addObject:@"акція завершилась"];
    else {
        NSInteger left = ZNDaysLeft(e);
        if (left != NSNotFound) {
            if (left <= 0) [parts addObject:@"останній день"];
            else if (left == 1) [parts addObject:@"до завтра"];
            else [parts addObject:[NSString stringWithFormat:@"до %@ (ще %ld дн.)", ZNDateShort(e), (long)left]];
        }
    }
    return [parts componentsJoinedByString:@" · "];
}

- (UIView *)buildHeader {
    CGFloat w = self.view.bounds.size.width;
    UIView *h = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 10)] autorelease];
    h.backgroundColor = [UIColor clearColor];

    // біла «вітрина» з фото
    CGFloat heroH = 186;
    UIView *hero = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, heroH)] autorelease];
    hero.backgroundColor = [UIColor whiteColor];
    hero.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIView *line = [[[UIView alloc] initWithFrame:CGRectMake(0, heroH - 1, w, 1)] autorelease];
    line.backgroundColor = [UIColor colorWithRed:0.89 green:0.85 blue:0.81 alpha:1];
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [hero addSubview:line];
    [h addSubview:hero];

    UIImageView *iv = [[[UIImageView alloc] initWithFrame:CGRectMake((w - 170) / 2, 8, 170, heroH - 16)] autorelease];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.backgroundColor = [UIColor whiteColor];
    iv.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    NSURL *url = [[ZNStore shared] imageURLForItem:_item];
    iv.image = [[ZNImageLoader shared] cachedImageForURL:url];
    if (!iv.image && url) [[ZNImageLoader shared] loadURL:url done:^(UIImage *img) { iv.image = img; }];
    [hero addSubview:iv];

    // бейдж знижки
    UILabel *disc = ZNLbl([UIFont boldSystemFontOfSize:14], [UIColor whiteColor]);
    disc.text = [NSString stringWithFormat:@"−%@%%", [_item objectForKey:@"d"]];
    disc.textAlignment = NSTextAlignmentCenter;
    disc.backgroundColor = ZN_ACCENT;
    disc.layer.cornerRadius = 4; disc.clipsToBounds = YES;
    CGSize ds = [disc.text sizeWithFont:disc.font];
    disc.frame = CGRectMake(10, 10, ds.width + 12, 22);
    [hero addSubview:disc];

    // магазин
    UILabel *store = ZNLbl([UIFont boldSystemFontOfSize:12], [UIColor whiteColor]);
    store.text = [[ZNStore shared] storeName:[_item objectForKey:@"s"]];
    store.textAlignment = NSTextAlignmentCenter;
    store.backgroundColor = [UIColor colorWithRed:0.35 green:0.29 blue:0.27 alpha:1];
    store.layer.cornerRadius = 4; store.clipsToBounds = YES;
    CGSize ss = [store.text sizeWithFont:store.font];
    store.frame = CGRectMake(10, heroH - 32, ss.width + 12, 20);
    [hero addSubview:store];

    // жовтий цінник, що «звисає» з вітрини
    UIFont *pf = [UIFont boldSystemFontOfSize:30], *of = [UIFont systemFontOfSize:13];
    NSString *ptxt = ZNPriceShort([_item objectForKey:@"p"]), *otxt = ZNPriceShort([_item objectForKey:@"o"]);
    CGFloat pw = [ptxt sizeWithFont:pf].width, ow = [otxt sizeWithFont:of].width;
    CGFloat tw = MAX(pw, ow) + 24, th = 56;
    UIView *tag = [[[UIView alloc] initWithFrame:CGRectMake(w - tw - 12, heroH - th + 18, tw, th)] autorelease];
    tag.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    UIImageView *tbg = [[[UIImageView alloc] initWithImage:ZNTagImage()] autorelease];
    tbg.frame = tag.bounds;
    [tag addSubview:tbg];
    ZNStrikeLabel *old = [[[ZNStrikeLabel alloc] init] autorelease];
    old.text = otxt; old.font = of; old.backgroundColor = [UIColor clearColor];
    old.textColor = [UIColor colorWithRed:0.48 green:0.42 blue:0.25 alpha:1];
    old.frame = CGRectMake(tw - ow - 12, 5, ow, 15);
    [tag addSubview:old];
    UILabel *pr = ZNLbl(pf, [UIColor colorWithRed:0.16 green:0.11 blue:0.06 alpha:1]);
    pr.text = ptxt; pr.textAlignment = NSTextAlignmentRight;
    pr.frame = CGRectMake(6, 18, tw - 18, 32);
    [tag addSubview:pr];
    tag.transform = CGAffineTransformMakeRotation(-0.05);
    tag.layer.shouldRasterize = YES;
    tag.layer.rasterizationScale = [UIScreen mainScreen].scale;
    [h addSubview:tag];

    CGFloat y = heroH + 26;
    // назва
    UILabel *title = ZNLbl([UIFont boldSystemFontOfSize:17], [UIColor colorWithRed:0.17 green:0.13 blue:0.12 alpha:1]);
    title.text = [_item objectForKey:@"t"];
    title.numberOfLines = 0;
    if (![ZNTheme isFlat]) { title.shadowColor = [UIColor whiteColor]; title.shadowOffset = CGSizeMake(0, 1); }
    CGSize ts = [title.text sizeWithFont:title.font constrainedToSize:CGSizeMake(w - 24, 200)];
    title.frame = CGRectMake(12, y, w - 24, ts.height);
    [h addSubview:title];
    y += ts.height + 4;

    NSString *meta = [self metaLine];
    if (meta.length) {
        UILabel *m = ZNLbl([UIFont systemFontOfSize:13], ZN_TEXT_MUTED);
        m.text = meta; m.numberOfLines = 2;
        CGSize ms = [meta sizeWithFont:m.font constrainedToSize:CGSizeMake(w - 24, 40)];
        m.frame = CGRectMake(12, y, w - 24, ms.height);
        [h addSubview:m];
        y += ms.height + 4;
    }

    double p = [[_item objectForKey:@"p"] doubleValue], o = [[_item objectForKey:@"o"] doubleValue];
    if (o > p) {
        UILabel *sv = ZNLbl([UIFont boldSystemFontOfSize:14], [UIColor colorWithRed:0.18 green:0.54 blue:0.23 alpha:1]);
        sv.text = [NSString stringWithFormat:@"Економія %@", ZNPrice(@(o - p))];
        sv.frame = CGRectMake(12, y, w - 24, 18);
        [h addSubview:sv];
        y += 22;
    }

    // кнопка
    y += 6;
    _add = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    _add.frame = CGRectMake(10, y, w - 20, 44);
    _add.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _add.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    _add.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [_add setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.3] forState:UIControlStateNormal];
    [_add addTarget:self action:@selector(toggleList) forControlEvents:UIControlEventTouchUpInside];
    [h addSubview:_add];
    [self updateButton];
    y += 44 + 2;

    CGRect f = h.frame; f.size.height = y; h.frame = f;
    return h;
}

- (void)updateButton {
    BOOL in = [[ZNStore shared] isInList:_item];
    [_add setTitle:in ? @"✓ У списку" : @"+ Додати до списку" forState:UIControlStateNormal];
    [_add setBackgroundImage:ZNButtonImage(NO, in) forState:UIControlStateNormal];
    [_add setBackgroundImage:ZNButtonImage(YES, in) forState:UIControlStateHighlighted];
}

- (void)toggleList {
    [[ZNStore shared] toggleInList:_item];
    [self updateButton];
}

#pragma mark - table: дії

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 1; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return [_item objectForKey:@"l"] ? 2 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"act"];
    if (!c) c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"act"] autorelease];
    c.detailTextLabel.textColor = ZN_TEXT_MUTED;
    if (ip.row == 0) {
        c.textLabel.text = @"Скопіювати назву";
        c.detailTextLabel.text = nil;
        c.accessoryType = UITableViewCellAccessoryNone;
    } else {
        c.textLabel.text = @"Відкрити на сайті";
        NSString *host = [[NSURL URLWithString:[_item objectForKey:@"l"]] host];
        c.detailTextLabel.text = [host stringByReplacingOccurrencesOfString:@"www." withString:@""];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.row == 0) {
        [UIPasteboard generalPasteboard].string = [_item objectForKey:@"t"];
        UIAlertView *a = [[[UIAlertView alloc] initWithTitle:nil message:@"Назву скопійовано" delegate:nil
                                           cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
        [a show];
    } else {
        NSURL *u = [NSURL URLWithString:[_item objectForKey:@"l"]];
        if (u) [[UIApplication sharedApplication] openURL:u];
    }
}

@end
