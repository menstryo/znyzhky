#import "ZNDealViewController.h"
#import "ZNDealCell.h"
#import "ZNStore.h"
#import "ZNImageLoader.h"
#import <QuartzCore/QuartzCore.h>

@interface ZNDealViewController () {
    NSDictionary *_item;
    NSArray *_info;   // [[назва, значення]]
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
    [_item release]; [_info release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    ZNStore *st = [ZNStore shared];

    NSMutableArray *info = [NSMutableArray array];
    [info addObject:@[@"Магазин", [st storeName:[_item objectForKey:@"s"]]]];
    [info addObject:@[@"Категорія", [NSString stringWithFormat:@"%@ %@", [st categoryEmoji:[_item objectForKey:@"c"]],
                                     [st categoryName:[_item objectForKey:@"c"]]]]];
    double p = [[_item objectForKey:@"p"] doubleValue], o = [[_item objectForKey:@"o"] doubleValue];
    [info addObject:@[@"Економія", [NSString stringWithFormat:@"%@ (−%@%%)", ZNPrice(@(o - p)), [_item objectForKey:@"d"]]]];
    NSString *u = [_item objectForKey:@"u"];
    if ([u isKindOfClass:[NSString class]] && u.length) [info addObject:@[@"Ціна за", u]];
    NSString *e = [_item objectForKey:@"e"];
    if ([[_item objectForKey:@"gone"] boolValue]) {
        [info addObject:@[@"Статус", @"акція завершилась"]];
    } else if (ZNDaysLeft(e) != NSNotFound) {
        NSInteger left = ZNDaysLeft(e);
        NSString *s = left <= 0 ? @"сьогодні останній день" : (left == 1 ? @"до завтра" :
                      [NSString stringWithFormat:@"до %@ (%ld дн.)", ZNDateShort(e), (long)left]);
        [info addObject:@[@"Діє", s]];
    }
    _info = [info retain];

    self.tableView.tableHeaderView = [self buildHeader];
}

- (UIView *)buildHeader {
    CGFloat w = self.view.bounds.size.width;
    UIView *h = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 10)] autorelease];
    h.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    h.backgroundColor = [UIColor clearColor];

    UIImageView *iv = [[[UIImageView alloc] initWithFrame:CGRectMake((w - 140) / 2, 16, 140, 140)] autorelease];
    iv.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.backgroundColor = [UIColor whiteColor];
    iv.layer.cornerRadius = 8;
    iv.layer.borderWidth = 1;
    iv.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1].CGColor;
    iv.clipsToBounds = YES;
    NSURL *url = [[ZNStore shared] imageURLForItem:_item];
    iv.image = [[ZNImageLoader shared] cachedImageForURL:url];
    if (!iv.image && url) {
        [[ZNImageLoader shared] loadURL:url done:^(UIImage *img) { iv.image = img; }];
    }
    [h addSubview:iv];

    CGFloat y = 168;
    UILabel *title = [[[UILabel alloc] init] autorelease];
    title.text = [_item objectForKey:@"t"];
    title.font = [UIFont boldSystemFontOfSize:17];
    title.numberOfLines = 0;
    title.textAlignment = NSTextAlignmentCenter;
    title.backgroundColor = [UIColor clearColor];
    title.shadowColor = [UIColor whiteColor];
    title.shadowOffset = CGSizeMake(0, 1);
    CGSize ts = [title.text sizeWithFont:title.font constrainedToSize:CGSizeMake(w - 40, 200)];
    title.frame = CGRectMake(20, y, w - 40, ts.height);
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [h addSubview:title];
    y += ts.height + 10;

    // ціна — стара — бейдж в один рядок по центру
    UILabel *price = [[[UILabel alloc] init] autorelease];
    price.text = ZNPrice([_item objectForKey:@"p"]);
    price.font = [UIFont boldSystemFontOfSize:26];
    price.textColor = ZN_ACCENT;
    price.backgroundColor = [UIColor clearColor];
    ZNStrikeLabel *old = [[[ZNStrikeLabel alloc] init] autorelease];
    old.text = ZNPrice([_item objectForKey:@"o"]);
    old.font = [UIFont systemFontOfSize:16];
    old.textColor = [UIColor grayColor];
    old.backgroundColor = [UIColor clearColor];
    UILabel *badge = [[[UILabel alloc] init] autorelease];
    badge.text = [NSString stringWithFormat:@"−%@%%", [_item objectForKey:@"d"]];
    badge.font = [UIFont boldSystemFontOfSize:15];
    badge.textColor = [UIColor whiteColor];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.backgroundColor = ZN_ACCENT;
    badge.layer.cornerRadius = 5;
    badge.clipsToBounds = YES;

    CGSize ps = [price.text sizeWithFont:price.font], os = [old.text sizeWithFont:old.font], bs = [badge.text sizeWithFont:badge.font];
    CGFloat total = ps.width + 10 + os.width + 10 + bs.width + 12;
    CGFloat x = MAX(10, (w - total) / 2);
    price.frame = CGRectMake(x, y, ps.width, 32); x += ps.width + 10;
    old.frame = CGRectMake(x, y + 7, os.width, 20); x += os.width + 10;
    badge.frame = CGRectMake(x, y + 5, bs.width + 12, 24);
    [h addSubview:price]; [h addSubview:old]; [h addSubview:badge];
    for (UIView *v in @[price, old, badge]) v.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    y += 40;

    CGRect f = h.frame; f.size.height = y; h.frame = f;
    return h;
}

#pragma mark - table

enum { ZNSecInfo = 0, ZNSecActions };

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (s == ZNSecInfo) return _info.count;
    return [_item objectForKey:@"l"] ? 3 : 2;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == ZNSecInfo) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"info"];
        if (!c) c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"info"] autorelease];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        NSArray *row = [_info objectAtIndex:ip.row];
        c.textLabel.text = [row objectAtIndex:0];
        c.detailTextLabel.text = [row objectAtIndex:1];
        c.detailTextLabel.adjustsFontSizeToFitWidth = YES;
        return c;
    }
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"act"];
    if (!c) c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"act"] autorelease];
    c.textLabel.textAlignment = NSTextAlignmentCenter;
    c.textLabel.textColor = [UIColor colorWithRed:0.22 green:0.33 blue:0.53 alpha:1];
    if (ip.row == 0) {
        BOOL fav = [[ZNStore shared] isFavorite:_item];
        c.textLabel.text = fav ? @"★ Прибрати з обраного" : @"☆ Додати в обране";
    } else if (ip.row == 1) {
        c.textLabel.text = @"Скопіювати назву";
    } else {
        c.textLabel.text = @"Відкрити на сайті магазину";
    }
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != ZNSecActions) return;
    if (ip.row == 0) {
        [[ZNStore shared] toggleFavorite:_item];
        [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationFade];
    } else if (ip.row == 1) {
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
