#import "ZNGridCell.h"
#import "ZNDealCell.h"
#import "ZNTheme.h"
#import "ZNStore.h"
#import "ZNImageLoader.h"
#import <QuartzCore/QuartzCore.h>

#define ZN_PHOTO_H 104.0f

// Усі «дорогі» ефекти (тіні, заокруглення з обрізкою) намальовані заздалегідь у розтяжні картинки:
// layer.shadow і masksToBounds рендеряться поза екраном на кожному кадрі — на 4S це й гальмувало прокрутку.
static UIImage *ZNStretchable(CGSize size, CGFloat radius, UIColor *fill, UIColor *shadow, CGFloat shadowY, CGFloat inset) {
    CGFloat scale = [UIScreen mainScreen].scale;
    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectInset(CGRectMake(0, 0, size.width, size.height - shadowY), inset, inset);
    if (shadow) {
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, shadowY), shadowY + 0.5f, shadow.CGColor);
        [fill setFill];
        [[UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius] fill];
        CGContextRestoreGState(ctx);
    }
    [fill setFill];
    [[UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius] fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGFloat c = ceilf(radius + inset + shadowY + 1);
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(c, c, c, c)];
}

static UIImage *ZNCardImage(void) {
    static UIImage *i = nil;
    if (!i) i = [ZNStretchable(CGSizeMake(30, 32), 7, [UIColor whiteColor],
                               [UIColor colorWithRed:0.25 green:0.12 blue:0.08 alpha:0.30], 1.5, 1) retain];
    return i;
}
static UIImage *ZNCardPressedImage(void) {
    static UIImage *i = nil;
    if (!i) i = [ZNStretchable(CGSizeMake(30, 32), 7, [UIColor colorWithRed:0.98 green:0.93 blue:0.90 alpha:1],
                               [UIColor colorWithRed:0.25 green:0.12 blue:0.08 alpha:0.30], 1.5, 1) retain];
    return i;
}
// жовтий цінник з тінню й прозорою облямівкою 1 px — тоді при повороті краї не «рвуться»
static UIImage *ZNTagImage(void) {
    static UIImage *i = nil;
    if (!i) i = [ZNStretchable(CGSizeMake(24, 26), 3, [UIColor colorWithRed:1.0 green:0.84 blue:0.24 alpha:1],
                               [UIColor colorWithWhite:0 alpha:0.35], 1.5, 2) retain];
    return i;
}

@interface ZNGridCell () {
    UIImageView *_card;
    UIImageView *_photo;
    UILabel *_badge;
    UILabel *_store;
    UIView *_tag;
    UIImageView *_tagBg;
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

static UILabel *ZNLabel(UIFont *f, UIColor *c) {
    UILabel *l = [[UILabel alloc] init];
    l.font = f;
    l.textColor = c;
    l.backgroundColor = [UIColor clearColor];
    return l;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _card = [[UIImageView alloc] initWithFrame:CGRectInset(self.contentView.bounds, -1, -1)];
        _card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _card.image = ZNCardImage();
        _card.highlightedImage = ZNCardPressedImage();
        [self.contentView addSubview:_card];

        _photo = [[UIImageView alloc] init];
        _photo.contentMode = UIViewContentModeScaleAspectFit;
        _photo.backgroundColor = [UIColor whiteColor];
        _photo.opaque = YES;
        [self.contentView addSubview:_photo];

        // бейджі: фон через layer без обрізки (cornerRadius без masksToBounds — дешево)
        _badge = ZNLabel([UIFont boldSystemFontOfSize:12], [UIColor whiteColor]);
        _badge.textAlignment = NSTextAlignmentCenter;
        _badge.layer.backgroundColor = ZN_ACCENT.CGColor;
        _badge.layer.cornerRadius = 3;
        [self.contentView addSubview:_badge];

        _store = ZNLabel([UIFont boldSystemFontOfSize:10], [UIColor whiteColor]);
        _store.textAlignment = NSTextAlignmentCenter;
        _store.layer.backgroundColor = [UIColor colorWithRed:0.17 green:0.13 blue:0.11 alpha:0.72].CGColor;
        _store.layer.cornerRadius = 3;
        [self.contentView addSubview:_store];

        _tag = [[UIView alloc] init];
        _tagBg = [[UIImageView alloc] initWithImage:ZNTagImage()];
        [_tag addSubview:_tagBg];
        _old = [[ZNStrikeLabel alloc] init];
        _old.font = [UIFont systemFontOfSize:9];
        _old.textColor = [UIColor colorWithRed:0.40 green:0.33 blue:0.28 alpha:1];
        _old.backgroundColor = [UIColor clearColor];
        _old.textAlignment = NSTextAlignmentRight;
        [_tag addSubview:_old];
        _price = ZNLabel([UIFont boldSystemFontOfSize:15], [UIColor colorWithRed:0.17 green:0.13 blue:0.11 alpha:1]);
        _price.textAlignment = NSTextAlignmentRight;
        _price.adjustsFontSizeToFitWidth = YES;
        _price.minimumScaleFactor = 0.6;
        [_tag addSubview:_price];
        [self.contentView addSubview:_tag];

        _title = ZNLabel([UIFont systemFontOfSize:12], [UIColor colorWithRed:0.17 green:0.13 blue:0.11 alpha:1]);
        _title.numberOfLines = 2;
        [self.contentView addSubview:_title];

        _meta = ZNLabel([UIFont systemFontOfSize:10], ZN_TEXT_MUTED);
        [self.contentView addSubview:_meta];

        _add = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _add.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        _add.layer.cornerRadius = 4;
        _add.layer.borderWidth = 1;
        [_add addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_add];

        // растеризуємо нахилений цінник один раз — поворот без антиаліасингу інакше дорогий і «зубчастий»
        _tag.layer.shouldRasterize = YES;
        _tag.layer.rasterizationScale = [UIScreen mainScreen].scale;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAddButton)
                                                     name:ZNStoreListChangedNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_card release]; [_photo release]; [_badge release]; [_store release]; [_tag release]; [_tagBg release];
    [_old release]; [_price release]; [_title release]; [_meta release]; [_add release]; [_imageURL release]; [_item release];
    [super dealloc];
}

- (void)setHighlighted:(BOOL)h {
    [super setHighlighted:h];
    _card.highlighted = h;
}

- (void)addTapped {
    if (!_item) return;
    [[ZNStore shared] toggleInList:_item];
    _add.transform = CGAffineTransformMakeScale(1.15, 1.15);
    [UIView animateWithDuration:0.2 animations:^{ _add.transform = CGAffineTransformIdentity; }];
}

- (void)updateAddButton {
    BOOL in = _item && [[ZNStore shared] isInList:_item];
    [_add setTitle:(in ? @"✓ У списку" : @"+ У список") forState:UIControlStateNormal];
    [_add setTitleColor:(in ? [UIColor whiteColor] : ZN_ACCENT_DARK) forState:UIControlStateNormal];
    _add.layer.backgroundColor = (in ? ZN_ACCENT : [UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1]).CGColor;
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
    CGFloat w = self.contentView.bounds.size.width;
    _photo.frame = CGRectMake(6, 6, w - 12, ZN_PHOTO_H - 12);
    CGSize bs = [_badge.text sizeWithFont:_badge.font];
    _badge.frame = CGRectMake(5, 5, bs.width + 8, 17);
    CGSize ss = [_store.text sizeWithFont:_store.font];
    _store.frame = CGRectMake(5, ZN_PHOTO_H - 21, ss.width + 8, 15);

    // цінник: праворуч унизу фото, заходить на текст
    CGSize ps = [_price.text sizeWithFont:_price.font];
    CGFloat tw = MIN(w * 0.55f, MAX(46, ps.width + 14));
    _tag.transform = CGAffineTransformIdentity;
    _tag.frame = CGRectMake(w - tw - 4, ZN_PHOTO_H - 22, tw, 33);
    _tagBg.frame = _tag.bounds; // явно: autoresizing від нульового розміру додавав зайві 26 pt жовтого
    _old.frame = CGRectMake(4, 3, tw - 10, 10);
    _price.frame = CGRectMake(4, 12, tw - 10, 17);
    _tag.transform = CGAffineTransformMakeRotation(-0.05);

    CGSize ts = [_title.text sizeWithFont:_title.font constrainedToSize:CGSizeMake(w - 14, 30) lineBreakMode:NSLineBreakByTruncatingTail];
    _title.frame = CGRectMake(7, ZN_PHOTO_H + 12, w - 14, MAX(15, ts.height)); // текст притиснутий догори
    _meta.frame = CGRectMake(7, ZN_PHOTO_H + 42, w - 14, 13);
    _add.frame = CGRectMake(6, ZN_PHOTO_H + 57, w - 12, 22);
}

@end
