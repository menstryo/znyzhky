#import "ZNDealCell.h"
#import "ZNStore.h"
#import "ZNImageLoader.h"
#import <QuartzCore/QuartzCore.h>

@implementation ZNStrikeLabel
- (void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:rect];
    CGSize sz = [self.text sizeWithFont:self.font];
    CGFloat w = MIN(sz.width, rect.size.width);
    CGFloat x = rect.origin.x;
    if (self.textAlignment == NSTextAlignmentRight) x = CGRectGetMaxX(rect) - w;
    CGFloat y = roundf(CGRectGetMidY(rect)) + 0.5f;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, (self.highlighted && self.highlightedTextColor ? self.highlightedTextColor : self.textColor).CGColor);
    CGContextSetLineWidth(ctx, 1);
    CGContextMoveToPoint(ctx, x, y);
    CGContextAddLineToPoint(ctx, x + w, y);
    CGContextStrokePath(ctx);
}
@end

@interface ZNDealCell () {
    UIImageView *_photo;
    UILabel *_title;
    UILabel *_price;
    ZNStrikeLabel *_old;
    UILabel *_badge;
    UILabel *_meta;
    NSURL *_imageURL;
}
@end

@implementation ZNDealCell

@synthesize item = _item, showsStore = _showsStore;

+ (CGFloat)height { return 86; }

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid])) {
        _showsStore = YES;
        UIView *cv = self.contentView;

        _photo = [[UIImageView alloc] initWithFrame:CGRectZero];
        _photo.contentMode = UIViewContentModeScaleAspectFit;
        _photo.backgroundColor = [UIColor whiteColor];
        _photo.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1].CGColor;
        _photo.layer.borderWidth = 1;
        _photo.layer.cornerRadius = 4;
        _photo.clipsToBounds = YES;
        [cv addSubview:_photo];

        _title = [[UILabel alloc] initWithFrame:CGRectZero];
        _title.font = [UIFont boldSystemFontOfSize:14];
        _title.numberOfLines = 2;
        _title.lineBreakMode = NSLineBreakByTruncatingTail;
        _title.backgroundColor = [UIColor clearColor];
        _title.highlightedTextColor = [UIColor whiteColor];
        [cv addSubview:_title];

        _price = [[UILabel alloc] initWithFrame:CGRectZero];
        _price.font = [UIFont boldSystemFontOfSize:17];
        _price.textColor = ZN_ACCENT_DARK;
        _price.backgroundColor = [UIColor clearColor];
        _price.highlightedTextColor = [UIColor whiteColor];
        [cv addSubview:_price];

        _old = [[ZNStrikeLabel alloc] initWithFrame:CGRectZero];
        _old.font = [UIFont systemFontOfSize:13];
        _old.textColor = ZN_TEXT_MUTED;
        _old.backgroundColor = [UIColor clearColor];
        _old.highlightedTextColor = [UIColor whiteColor];
        [cv addSubview:_old];

        _badge = [[UILabel alloc] initWithFrame:CGRectZero];
        _badge.font = [UIFont boldSystemFontOfSize:13];
        _badge.textColor = [UIColor whiteColor];
        _badge.textAlignment = NSTextAlignmentCenter;
        _badge.backgroundColor = ZN_ACCENT;
        _badge.layer.cornerRadius = 4;
        _badge.clipsToBounds = YES;
        [cv addSubview:_badge];

        _meta = [[UILabel alloc] initWithFrame:CGRectZero];
        _meta.font = [UIFont systemFontOfSize:12];
        _meta.textColor = ZN_TEXT_MUTED;
        _meta.backgroundColor = [UIColor clearColor];
        _meta.highlightedTextColor = [UIColor whiteColor];
        [cv addSubview:_meta];
    }
    return self;
}

- (void)dealloc {
    [_photo release]; [_title release]; [_price release]; [_old release];
    [_badge release]; [_meta release]; [_item release]; [_imageURL release];
    [super dealloc];
}

- (void)setHighlighted:(BOOL)h animated:(BOOL)a {
    [super setHighlighted:h animated:a];
    _badge.backgroundColor = ZN_ACCENT; // стандартна підсвітка робить фон підписів прозорим
}
- (void)setSelected:(BOOL)s animated:(BOOL)a {
    [super setSelected:s animated:a];
    _badge.backgroundColor = ZN_ACCENT;
}

- (void)setItem:(NSDictionary *)item {
    if (item != _item) { [_item release]; _item = [item retain]; }
    ZNStore *st = [ZNStore shared];
    BOOL gone = [[item objectForKey:@"gone"] boolValue];

    _title.text = [item objectForKey:@"t"];
    _price.text = ZNPrice([item objectForKey:@"p"]);
    _old.text = ZNPrice([item objectForKey:@"o"]);
    _badge.text = [NSString stringWithFormat:@"−%@%%", [item objectForKey:@"d"]];
    _title.textColor = gone ? [UIColor grayColor] : [UIColor blackColor];

    NSMutableArray *meta = [NSMutableArray array];
    if (_showsStore) [meta addObject:[st storeName:[item objectForKey:@"s"]]];
    if (gone) {
        [meta addObject:@"акція завершилась"];
    } else {
        NSString *e = [item objectForKey:@"e"];
        NSInteger left = ZNDaysLeft(e);
        if (left == 0) [meta addObject:@"останній день"];
        else if (left == 1) [meta addObject:@"до завтра"];
        else if (left != NSNotFound && left > 0) [meta addObject:[NSString stringWithFormat:@"до %@", ZNDateShort(e)]];
    }
    NSString *u = [item objectForKey:@"u"];
    if ([u isKindOfClass:[NSString class]] && u.length && ![u isEqualToString:@"шт"]) [meta addObject:[NSString stringWithFormat:@"за %@", u]];
    _meta.text = [meta componentsJoinedByString:@" · "];

    // фото
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
    CGFloat pad = 10, imgS = 64;
    _photo.frame = CGRectMake(pad, 11, imgS, imgS);
    CGFloat x = pad + imgS + 10;
    CGFloat tw = w - x - pad;
    CGSize ts = [_title.text sizeWithFont:_title.font constrainedToSize:CGSizeMake(tw, 36) lineBreakMode:NSLineBreakByTruncatingTail];
    _title.frame = CGRectMake(x, 6, tw, MAX(18, ts.height));

    CGSize bs = [_badge.text sizeWithFont:_badge.font];
    CGFloat bw = bs.width + 10;
    _badge.frame = CGRectMake(w - pad - bw, 44, bw, 20);

    CGSize ps = [_price.text sizeWithFont:_price.font];
    _price.frame = CGRectMake(x, 43, MIN(ps.width, tw - bw - 8), 22);
    CGFloat ox = CGRectGetMaxX(_price.frame) + 8;
    _old.frame = CGRectMake(ox, 46, MAX(0, w - pad - bw - 6 - ox), 18);

    _meta.frame = CGRectMake(x, 64, tw, 16);
}

@end
