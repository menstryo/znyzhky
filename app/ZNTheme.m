#import "ZNTheme.h"

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
