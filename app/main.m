#import <UIKit/UIKit.h>
#import "ZNStore.h"
#import "ZNDealCell.h"
#import "ZNTheme.h"
#import "ZNGridViewController.h"
#import "ZNShoppingListViewController.h"
#import "ZNSettingsViewController.h"
#import "ZNLeafletsViewController.h"

@interface ZNAppDelegate : UIResponder <UIApplicationDelegate> {
    UINavigationController *_navDeals, *_navPapers, *_navList, *_navMore;
}
@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UITabBarController *tabs;
@end

@implementation ZNAppDelegate
@synthesize window = _window, tabs = _tabs;

static UINavigationController *ZNNav(UIViewController *root, NSString *title, NSString *icon) {
    UINavigationController *n = [[[UINavigationController alloc] initWithRootViewController:root] autorelease];
    n.tabBarItem = [[[UITabBarItem alloc] initWithTitle:title image:[UIImage imageNamed:icon] tag:0] autorelease];
    if ([n.navigationBar respondsToSelector:@selector(setTranslucent:)] && [ZNTheme isFlat]) n.navigationBar.translucent = NO;
    return n;
}

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [ZNTheme apply];
    if ([ZNTheme isFlat]) [app setStatusBarStyle:1 /* UIStatusBarStyleLightContent */];
    self.window = [[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds] autorelease];
    if ([self.window respondsToSelector:@selector(setTintColor:)]) self.window.tintColor = ZN_ACCENT; // iOS 7+

    ZNGridViewController *deals = [[[ZNGridViewController alloc] init] autorelease];
    ZNLeafletsViewController *papers = [[[ZNLeafletsViewController alloc] init] autorelease];
    ZNShoppingListViewController *list = [[[ZNShoppingListViewController alloc] init] autorelease];
    ZNSettingsViewController *more = [[[ZNSettingsViewController alloc] init] autorelease];

    self.tabs = [[[UITabBarController alloc] init] autorelease];
    _navDeals  = [ZNNav(deals, @"Акції", @"tab-all") retain];
    _navPapers = [ZNNav(papers, @"Газетки", @"tab-news") retain];
    _navList   = [ZNNav(list, @"Список", @"tab-list") retain];
    _navMore   = [ZNNav(more, @"Ще", @"tab-more") retain];
    if ([ZNTheme isFlat]) self.tabs.tabBar.translucent = NO;
    [self updateTabs];

    self.window.rootViewController = self.tabs;
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBadge)
                                                 name:ZNStoreDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBadge)
                                                 name:ZNStoreListChangedNotification object:nil];
    [self updateBadge];
    [[ZNStore shared] refreshIfStale];
    // перший запуск — спитати місто (один раз)
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (![ZNStore shared].cityId && ![ud boolForKey:@"cityAsked"]) {
        [ud setBool:YES forKey:@"cityAsked"];
        [self performSelector:@selector(askCity) withObject:nil afterDelay:0.6];
    }
    return YES;
}

- (void)askCity {
    ZNCityPickerViewController *p = [[[ZNCityPickerViewController alloc] init] autorelease];
    p.modal = YES;
    p.title = @"Ваше місто";
    UINavigationController *n = [[[UINavigationController alloc] initWithRootViewController:p] autorelease];
    [self.tabs presentViewController:n animated:YES completion:nil];
}

// «Газетки» видно лише тоді, коли в місті вони є
- (BOOL)cityHasLeaflets {
    ZNStore *st = [ZNStore shared];
    if (!st.cityId) return NO;
    if (st.leaflets.count) return YES;
    for (NSDictionary *c in st.cities)
        if ([[c objectForKey:@"id"] isEqual:st.cityId]) return [[c objectForKey:@"leaflets"] integerValue] > 0;
    return NO;
}

- (void)updateTabs {
    BOOL show = [self cityHasLeaflets];
    NSArray *want = show ? @[ _navDeals, _navPapers, _navList, _navMore ] : @[ _navDeals, _navList, _navMore ];
    if ([self.tabs.viewControllers isEqualToArray:want]) return;
    UIViewController *sel = self.tabs.selectedViewController;
    [self.tabs setViewControllers:want animated:NO];
    if (sel && [want containsObject:sel]) self.tabs.selectedViewController = sel;
}

// бейджі: «Список» — скільки ще купити, «Ще» — скільки товарів зі слів зараз в акції
- (void)updateBadge {
    [self updateTabs];
    ZNStore *st = [ZNStore shared];
    NSUInteger open = st.listOpenCount, words = st.watchMatchCount;
    _navList.tabBarItem.badgeValue = open ? [NSString stringWithFormat:@"%lu", (unsigned long)open] : nil;
    _navMore.tabBarItem.badgeValue = words ? [NSString stringWithFormat:@"%lu", (unsigned long)words] : nil;
}

- (void)applicationWillEnterForeground:(UIApplication *)app {
    [[ZNStore shared] refreshIfStale];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_window release];
    [_tabs release];
    [_navDeals release]; [_navPapers release]; [_navList release]; [_navMore release];
    [super dealloc];
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ZNAppDelegate class]));
    }
}
