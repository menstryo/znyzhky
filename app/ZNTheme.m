#import "ZNTheme.h"
#import <QuartzCore/QuartzCore.h>

@implementation ZNTheme

+ (BOOL)isFlat { return [[[UIDevice currentDevice] systemVersion] floatValue] >= 7; }

+ (BOOL)handwriting {
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:@"handwriting"];
    return v ? [v boolValue] : ![self isFlat];
}
+ (void)setHandwriting:(BOOL)on {
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:@"handwriting"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (UIFont *)noteFont:(CGFloat)size bold:(BOOL)bold {
    if ([self handwriting]) {
        // Noteworthy — шрифт «Нотаток» iOS 6 (з кирилицею)
        UIFont *f = [UIFont fontWithName:bold ? @"Noteworthy-Bold" : @"Noteworthy-Light" size:size];
        if (f) return f;
    }
    return bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
}

static void ZNRGB(ZNButtonKind k, BOOL top, CGFloat *c) {
    switch (k) {
        case ZNButtonAccent: if (top) { c[0]=0.90; c[1]=0.45; c[2]=0.38; } else { c[0]=0.76; c[1]=0.24; c[2]=0.18; } break;
        case ZNButtonGreen:  if (top) { c[0]=0.40; c[1]=0.70; c[2]=0.38; } else { c[0]=0.20; c[1]=0.50; c[2]=0.22; } break;
        default:             if (top) { c[0]=1.00; c[1]=1.00; c[2]=0.99; } else { c[0]=0.93; c[1]=0.89; c[2]=0.85; } break;
    }
}

+ (UIImage *)buttonImage:(ZNButtonKind)kind pressed:(BOOL)pressed radius:(CGFloat)radius {
    static NSMutableDictionary *cache = nil;
    if (!cache) cache = [[NSMutableDictionary alloc] init];
    NSString *key = [NSString stringWithFormat:@"%d-%d-%.0f", kind, pressed, radius];
    UIImage *hit = [cache objectForKey:key];
    if (hit) return hit;

    BOOL flat = [self isFlat];
    CGFloat cap = radius + 3;
    CGSize size = CGSizeMake(cap * 2 + 2, cap * 2 + 3);
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat top[3], bot[3];
    ZNRGB(kind, YES, top); ZNRGB(kind, NO, bot);
    if (pressed) for (int i = 0; i < 3; i++) { top[i] *= 0.86f; bot[i] *= 0.86f; }

    if (flat) {
        CGRect r = CGRectMake(0.5f, 0.5f, size.width - 1, size.height - 1);
        UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
        UIColor *fill = kind == ZNButtonLight
            ? (pressed ? [UIColor colorWithRed:0.95 green:0.91 blue:0.88 alpha:1] : [UIColor whiteColor])
            : [UIColor colorWithRed:(top[0] + bot[0]) / 2 green:(top[1] + bot[1]) / 2 blue:(top[2] + bot[2]) / 2 alpha:1];
        [fill setFill]; [p fill];
        if (kind == ZNButtonLight) {
            [[UIColor colorWithRed:0.86 green:0.80 blue:0.75 alpha:1] setStroke];
            p.lineWidth = 1; [p stroke];
        }
    } else {
        CGRect r = CGRectMake(0.5f, 0.5f, size.width - 1, size.height - 2.5f);
        UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
        // світла «тиснена» тінь знизу
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 0, [UIColor colorWithWhite:1 alpha:0.7].CGColor);
        [[UIColor whiteColor] setFill]; [p fill];
        CGContextRestoreGState(ctx);
        // градієнт (натиснута — догори дриґом)
        CGFloat comps[8] = { top[0], top[1], top[2], 1, bot[0], bot[1], bot[2], 1 };
        if (pressed) { CGFloat t[8] = { bot[0], bot[1], bot[2], 1, top[0], top[1], top[2], 1 }; memcpy(comps, t, sizeof t); }
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
        CGContextSaveGState(ctx);
        [p addClip];
        CGContextDrawLinearGradient(ctx, g, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
        if (!pressed) {   // відблиск зверху
            [[UIColor colorWithWhite:1 alpha:kind == ZNButtonLight ? 0.9f : 0.32f] setFill];
            CGContextFillRect(ctx, CGRectMake(0, 1, size.width, 1));
        }
        CGContextRestoreGState(ctx);
        CGGradientRelease(g); CGColorSpaceRelease(cs);
        UIColor *border = kind == ZNButtonLight ? [UIColor colorWithRed:0.72 green:0.65 blue:0.59 alpha:1]
                                                : [UIColor colorWithRed:bot[0] * 0.75f green:bot[1] * 0.75f blue:bot[2] * 0.75f alpha:1];
        [border setStroke];
        p.lineWidth = 1; [p stroke];
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    img = [img resizableImageWithCapInsets:UIEdgeInsetsMake(cap, cap, cap, cap)];
    [cache setObject:img forKey:key];
    return img;
}

+ (void)styleButton:(UIButton *)b kind:(ZNButtonKind)kind radius:(CGFloat)radius {
    BOOL flat = [self isFlat];
    b.backgroundColor = [UIColor clearColor];
    b.layer.backgroundColor = [UIColor clearColor].CGColor;
    b.layer.borderWidth = 0;
    b.layer.cornerRadius = 0;
    [b setBackgroundImage:[self buttonImage:kind pressed:NO radius:radius] forState:UIControlStateNormal];
    [b setBackgroundImage:[self buttonImage:kind pressed:YES radius:radius] forState:UIControlStateHighlighted];
    BOOL light = kind == ZNButtonLight;
    [b setTitleColor:light ? ZN_ACCENT_DARK : [UIColor whiteColor] forState:UIControlStateNormal];
    [b setTitleColor:light ? ZN_ACCENT_DARK : [UIColor colorWithWhite:1 alpha:0.85] forState:UIControlStateHighlighted];
    if (flat) {
        b.titleLabel.shadowOffset = CGSizeZero;
    } else {
        [b setTitleShadowColor:light ? [UIColor whiteColor] : [UIColor colorWithWhite:0 alpha:0.35] forState:UIControlStateNormal];
        b.titleLabel.shadowOffset = light ? CGSizeMake(0, 1) : CGSizeMake(0, -1);
    }
}

+ (void)apply {
    BOOL flat = [self isFlat];

    // навбар
    UINavigationBar *nb = [UINavigationBar appearance];
    if (flat) {
        // appearance-проксі не відповідає на respondsToSelector:, тож перевіряємо сам клас
        if ([UINavigationBar instancesRespondToSelector:@selector(setBarTintColor:)]) [nb performSelector:@selector(setBarTintColor:) withObject:ZN_ACCENT];
        nb.tintColor = [UIColor whiteColor];
        nb.titleTextAttributes = @{ NSForegroundColorAttributeName: [UIColor whiteColor] };
    } else {
        nb.tintColor = ZN_ACCENT;
    }

    // пошук і сегменти — у тон навбару (на iOS 6 вони сині за замовчуванням)
    [[UISearchBar appearance] setTintColor:flat ? ZN_ACCENT : ZN_BG_HEADER];
    // iOS 7+: «Скасувати» в пошуку на кораловому навбарі — білим (інакше коралове на кораловому)
    if (flat) [[UIBarButtonItem appearanceWhenContainedIn:[UISearchBar class], nil]
                  setTitleTextAttributes:@{ UITextAttributeTextColor: [UIColor whiteColor] } forState:UIControlStateNormal];
    [[UISegmentedControl appearance] setTintColor:ZN_ACCENT];

    // таббар — теплий темний, вибрана вкладка коралова
    UITabBar *tb = [UITabBar appearance];
    if (flat) {
        if ([UITabBar instancesRespondToSelector:@selector(setBarTintColor:)]) [tb performSelector:@selector(setBarTintColor:) withObject:ZN_TABBAR];
        tb.tintColor = ZN_ACCENT_SOFT;
    } else {
        tb.tintColor = ZN_TABBAR;
        tb.selectedImageTintColor = ZN_ACCENT_SOFT;
    }
    NSDictionary *normal = @{ UITextAttributeTextColor: [UIColor colorWithWhite:0.75 alpha:1] };
    NSDictionary *selected = @{ UITextAttributeTextColor: ZN_ACCENT_SOFT };
    [[UITabBarItem appearance] setTitleTextAttributes:normal forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:selected forState:UIControlStateSelected];

    [[UISwitch appearance] setOnTintColor:ZN_ACCENT];
    if ([UIRefreshControl class]) [[UIRefreshControl appearance] setTintColor:ZN_ACCENT];
}

+ (void)styleGroupedTable:(UITableView *)tv {
    tv.backgroundView = nil;
    tv.backgroundColor = ZN_BG;
}

+ (UIView *)sectionHeaderWithTitle:(NSString *)title width:(CGFloat)w {
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 36)] autorelease];
    v.backgroundColor = [UIColor clearColor];
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(20, 12, w - 40, 22)] autorelease];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.text = [self isFlat] ? [title uppercaseString] : title;
    l.font = [self isFlat] ? [UIFont systemFontOfSize:13] : [UIFont boldSystemFontOfSize:16];
    l.textColor = ZN_TEXT_MUTED;
    l.backgroundColor = [UIColor clearColor];
    if (![self isFlat]) { l.shadowColor = [UIColor whiteColor]; l.shadowOffset = CGSizeMake(0, 1); }
    [v addSubview:l];
    return v;
}

+ (CGFloat)heightForFooterText:(NSString *)text width:(CGFloat)w {
    if (!text.length) return 0;
    CGSize s = [text sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(w - 40, 400)];
    return s.height + 18;
}

+ (UIView *)sectionFooterWithText:(NSString *)text width:(CGFloat)w {
    CGFloat h = [self heightForFooterText:text width:w];
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)] autorelease];
    v.backgroundColor = [UIColor clearColor];
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(20, 6, w - 40, h - 12)] autorelease];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.text = text;
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    l.font = [UIFont systemFontOfSize:14];
    l.textColor = ZN_TEXT_MUTED;
    l.backgroundColor = [UIColor clearColor];
    if (![self isFlat]) { l.shadowColor = [UIColor whiteColor]; l.shadowOffset = CGSizeMake(0, 1); }
    [v addSubview:l];
    return v;
}

@end
