#import <UIKit/UIKit.h>
#import "ZNStore.h"
#import "ZNDealCell.h"
#import "ZNTheme.h"
#import "ZNDealListViewController.h"
#import "ZNGroupsViewController.h"
#import "ZNFavoritesViewController.h"
#import "ZNSettingsViewController.h"

@interface ZNAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UITabBarController *tabs;
@end

@implementation ZNAppDelegate
@synthesize window = _window, tabs = _tabs;

static UINavigationController *ZNNav(UIViewController *root, NSString *title, NSString *icon) {
    UINavigationController *n = [[[UINavigationController alloc] initWithRootViewController:root] autorelease];
    n.tabBarItem = [[[UITabBarItem alloc] initWithTitle:title image:[UIImage imageNamed:icon] tag:0] autorelease];
    return n;
}

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [ZNTheme apply];
    if ([ZNTheme isFlat]) [app setStatusBarStyle:1 /* UIStatusBarStyleLightContent */];
    self.window = [[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds] autorelease];
    if ([self.window respondsToSelector:@selector(setTintColor:)]) self.window.tintColor = ZN_ACCENT; // iOS 7+

    ZNDealListViewController *all = [[[ZNDealListViewController alloc] initWithTitle:@"Усі акції" filter:nil] autorelease];
    ZNGroupsViewController *stores = [[[ZNGroupsViewController alloc] initWithMode:ZNGroupStores] autorelease];
    ZNGroupsViewController *cats = [[[ZNGroupsViewController alloc] initWithMode:ZNGroupCategories] autorelease];
    ZNFavoritesViewController *favs = [[[ZNFavoritesViewController alloc] init] autorelease];
    ZNSettingsViewController *settings = [[[ZNSettingsViewController alloc] init] autorelease];

    self.tabs = [[[UITabBarController alloc] init] autorelease];
    self.tabs.viewControllers = @[ ZNNav(all, @"Усі", @"tab-all"),
                                   ZNNav(stores, @"Магазини", @"tab-stores"),
                                   ZNNav(cats, @"Категорії", @"tab-cats"),
                                   ZNNav(favs, @"Обране", @"tab-fav"),
                                   ZNNav(settings, @"Ще", @"tab-more") ];

    self.window.rootViewController = self.tabs;
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBadge)
                                                 name:ZNStoreDidUpdateNotification object:nil];
    [[ZNStore shared] refreshIfStale];
    return YES;
}

// бейдж на «Обране» — скільки товарів зі списку слів зараз в акції
- (void)updateBadge {
    NSUInteger n = [[ZNStore shared] watchMatchCount];
    UIViewController *fav = [self.tabs.viewControllers objectAtIndex:3];
    fav.tabBarItem.badgeValue = n ? [NSString stringWithFormat:@"%lu", (unsigned long)n] : nil;
}

- (void)applicationWillEnterForeground:(UIApplication *)app {
    [[ZNStore shared] refreshIfStale];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_window release];
    [_tabs release];
    [super dealloc];
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ZNAppDelegate class]));
    }
}
