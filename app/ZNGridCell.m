#import "ZNGridCell.h"
#import "ZNDealCell.h"
#import "ZNTheme.h"
#import "ZNStore.h"
#import "ZNImageLoader.h"
#import <QuartzCore/QuartzCore.h>

#define ZN_PHOTO_H 104.0f

@interface ZNGridCell () {
    UIView *_card;
    UIImageView *_photo;
    UILabel *_badge;
    UILabel *_store;
    UIView *_tag;
    ZNStrikeLabel *_old;
    UILabel *_price;
    UILabel *_title;
    UILabel *_meta;
    UIButton *_add;
    NSURL *_imageURL;
}
@end

@implementation ZNGridCell

@synthesize item = _item;

+ (CGSize)sizeForWidth:(CGFloat)totalWidth columns:(NSInteger *)outColumns {
    NSInteger cols = MAX(2, (NSInteger)floorf((totalWidth - 8) / 152.0f)); // iPhone — 2, iPad — 4–6
    CGFloat w = floorf((totalWidth - 8 - 8 * cols) / cols);
    if (outColumns) *outColumns = cols;
    return CGSizeMake(w, ZN_PHOTO_H + 82);
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _card = [[UIView alloc] initWithFrame:self.contentView.bounds];
        _card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _card.backgroundColor = [UIColor whiteColor];
        _card.layer.cornerRadius = 7;
        _card.layer.shadowColor = [UIColor colorWithRed:0.25 green:0.12 blue:0.08 alpha:1].CGColor;
        _card.layer.shadowOpacity = 0.22;
        _card.layer.shadowOffset = CGSizeMake(0, 1);
        _card.layer.shadowRadius = 1.5;
        [self.contentView addSubview:_card];

        _photo = [[UIImageView alloc] init];
        _photo.contentMode = UIViewContentModeScaleAspectFit;
        _photo.backgroundColor = [UIColor whiteColor];
        _photo.clipsToBounds = YES;
        [_card addSubview:_photo];

        _badge = [[UILabel alloc] init];
        _badge.font = [UIFont boldSystemFontOfSize:12];
        _badge.textColor = [UIColor whiteColor];
        _badge.backgroundColor = ZN_ACCENT;
        _badge.textAlignment = NSTextAlignmentCenter;
        _badge.layer.cornerRadius = 3;
        _badge.clipsToBounds = YES;
        [_card addSubview:_badge];

        _store = [[UILabel alloc] init];
        _store.font = [UIFont boldSystemFontOfSize:10];
        _store.textColor = [UIColor whiteColor];
        _store.backgroundColor = [UIColor colorWithRed:0.17 green:0.13 blue:0.11 alpha:0.72];
        _store.textAlignment = NSTextAlignmentCenter;
        _store.layer.cornerRadius = 3;
        _store.clipsToBounds = YES;
        [_card addSubview:_store];

        // жовтий цінник, трохи нахилений — як наліпка в магазинній газетці
        _tag = [[UIView alloc] init];
        _tag.backgroundColor = [UIColor colorWithRed:1.0 green:0.84 blue:0.24 alpha:1];
        _tag.layer.cornerRadius = 3;
        _tag.layer.shadowColor = [UIColor blackColor].CGColor;
        _tag.layer.shadowOpacity = 0.28;
        _tag.layer.shadowOffset = CGSizeMake(0, 1.5);
        _tag.layer.shadowRadius = 1.5;
        _old = [[ZNStrikeLabel alloc] init];
        _old.font = [UIFont systemFontOfSize:10];
        _old.textColor = [UIColor colorWithRed:0.40 green:0.33 blue:0.28 alpha:1];
        _old.backgroundColor = [UIColor clearColor];
        _old.textAlignment = NSTextAlignmentRight;
        [_tag addSubview:_old];
        _price = [[UILabel alloc] init];
        _price.font = [UIFont boldSystemFontOfSize:18];
        _price.textColor = [UIColor colorWithRed:0.17 green:0.13 blue:0.11 alpha:1];
        _price.backgroundColor = [UIColor clearColor];
        _price.textAlignment = NSTextAlignmentRight;
        _price.adjustsFontSizeToFitWidth = YES;
        _price.minimumScaleFactor = 0.6;
        [_tag addSubview:_price];
        [_card addSubview:_tag];

        _title = [[UILabel alloc] init];
        _title.font = [UIFont systemFontOfSize:12];
        _title.textColor = [UIColor colorWithRed:0.17 green:0.13 blue:0.11 alpha:1];
        _title.numberOfLines = 2;
        _title.backgroundColor = [UIColor clearColor];
        [_card addSubview:_title];

        _meta = [[UILabel alloc] init];
        _meta.font = [UIFont systemFontOfSize:10];
        _meta.textColor = ZN_TEXT_MUTED;
        _meta.backgroundColor = [UIColor clearColor];
        [_card addSubview:_meta];

        _add = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _add.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        _add.layer.cornerRadius = 4;
        _add.layer.borderWidth = 1;
        [_add addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];
        [_card addSubview:_add];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAddButton)
                                                     name:ZNStoreListChangedNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_card release]; [_photo release]; [_badge release]; [_store release]; [_tag release]; [_old release];
    [_price release]; [_title release]; [_meta release]; [_add release]; [_imageURL release]; [_item release];
    [super dealloc];
}

- (void)setHighlighted:(BOOL)h {
    [super setHighlighted:h];
    _card.backgroundColor = h ? [UIColor colorWithRed:0.98 green:0.93 blue:0.90 alpha:1] : [UIColor whiteColor];
}

- (void)addTapped {
    if (!_item) return;
    [[ZNStore shared] toggleInList:_item];
    // маленька «пружинка», щоб було видно, що натискання спрацювало
    _add.transform = CGAffineTransformMakeScale(1.15, 1.15);
    [UIView animateWithDuration:0.2 animations:^{ _add.transform = CGAffineTransformIdentity; }];
}

- (void)updateAddButton {
    BOOL in = _item && [[ZNStore shared] isInList:_item];
    [_add setTitle:(in ? @"✓ У списку" : @"+ У список") forState:UIControlStateNormal];
    [_add setTitleColor:(in ? [UIColor whiteColor] : ZN_ACCENT_DARK) forState:UIControlStateNormal];
    _add.backgroundColor = in ? ZN_ACCENT : [UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1];
    _add.layer.borderColor = (in ? ZN_ACCENT_DARK : [UIColor colorWithRed:0.86 green:0.80 blue:0.75 alpha:1]).CGColor;
}

- (void)setItem:(NSDictionary *)item {
    if (item != _item) { [_item release]; _item = [item retain]; }
    ZNStore *st = [ZNStore shared];
    _title.text = [item objectForKey:@"t"];
    _price.text = ZNPriceShort([item objectForKey:@"p"]);
    _old.text = ZNPriceShort([item objectForKey:@"o"]);
    _badge.text = [NSString stringWithFormat:@"−%@%%", [item objectForKey:@"d"]];
    _store.text = [st storeName:[item objectForKey:@"s"]];

    NSMutableArray *meta = [NSMutableArray array];
    NSString *e = [item objectForKey:@"e"];
    NSInteger left = ZNDaysLeft(e);
    if (left == 0) [meta addObject:@"останній день"];
    else if (left == 1) [meta addObject:@"до завтра"];
    else if (left != NSNotFound && left > 0) [meta addObject:[NSString stringWithFormat:@"до %@", ZNDateShort(e)]];
    NSString *u = [item objectForKey:@"u"];
    if ([u isKindOfClass:[NSString class]] && u.length && ![u isEqualToString:@"шт"]) [meta addObject:[NSString stringWithFormat:@"за %@", u]];
    _meta.text = meta.count ? [meta componentsJoinedByString:@" · "] : @" ";
    _meta.textColor = (left != NSNotFound && left <= 1) ? ZN_ACCENT_DARK : ZN_TEXT_MUTED;

    [self updateAddButton];

    NSURL *url = [st imageURLForItem:item];
    [_imageURL release]; _imageURL = [url retain];
    UIImage *img = [[ZNImageLoader shared] cachedImageForURL:url];
    _photo.image = img;
    if (!img && url) {
        [[ZNImageLoader shared] loadURL:url done:^(UIImage *loaded) {
            if ([_imageURL isEqual:url]) _photo.image = loaded;
        }];
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = _card.bounds.size.width;
    _photo.frame = CGRectMake(6, 6, w - 12, ZN_PHOTO_H - 12);
    CGSize bs = [_badge.text sizeWithFont:_badge.font];
    _badge.frame = CGRectMake(5, 5, bs.width + 8, 17);
    CGSize ss = [_store.text sizeWithFont:_store.font];
    _store.frame = CGRectMake(5, ZN_PHOTO_H - 21, ss.width + 8, 15);

    // цінник: праворуч унизу фото, заходить на текст
    CGSize ps = [_price.text sizeWithFont:_price.font];
    CGFloat tw = MIN(w * 0.62f, MAX(56, ps.width + 12));
    _tag.transform = CGAffineTransformIdentity;
    _tag.frame = CGRectMake(w - tw - 4, ZN_PHOTO_H - 26, tw, 36);
    _old.frame = CGRectMake(4, 2, tw - 8, 12);
    _price.frame = CGRectMake(4, 13, tw - 8, 21);
    _tag.transform = CGAffineTransformMakeRotation(-0.06);

    CGSize ts = [_title.text sizeWithFont:_title.font constrainedToSize:CGSizeMake(w - 14, 30) lineBreakMode:NSLineBreakByTruncatingTail];
    _title.frame = CGRectMake(7, ZN_PHOTO_H + 12, w - 14, MAX(15, ts.height)); // текст притиснутий догори
    _meta.frame = CGRectMake(7, ZN_PHOTO_H + 42, w - 14, 13);
    _add.frame = CGRectMake(6, ZN_PHOTO_H + 57, w - 12, 22);
}

@end
