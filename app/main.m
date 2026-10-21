#import <UIKit/UIKit.h>
#import "ZNStore.h"
#import "ZNDealCell.h"
#import "ZNTheme.h"
#import "ZNGridViewController.h"
#import "ZNShoppingListViewController.h"
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

    ZNGridViewController *deals = [[[ZNGridViewController alloc] init] autorelease];
    ZNShoppingListViewController *list = [[[ZNShoppingListViewController alloc] init] autorelease];
    ZNSettingsViewController *more = [[[ZNSettingsViewController alloc] init] autorelease];

    self.tabs = [[[UITabBarController alloc] init] autorelease];
    self.tabs.viewControllers = @[ ZNNav(deals, @"Акції", @"tab-all"),
                                   ZNNav(list, @"Список", @"tab-list"),
                                   ZNNav(more, @"Ще", @"tab-more") ];

    self.window.rootViewController = self.tabs;
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBadge)
                                                 name:ZNStoreDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBadge)
                                                 name:ZNStoreListChangedNotification object:nil];
    [self updateBadge];
    [[ZNStore shared] refreshIfStale];
    return YES;
}

// бейджі: «Список» — скільки ще купити, «Ще» — скільки товарів зі слів зараз в акції
- (void)updateBadge {
    ZNStore *st = [ZNStore shared];
    NSUInteger open = st.listOpenCount, words = st.watchMatchCount;
    [[self.tabs.viewControllers objectAtIndex:1] tabBarItem].badgeValue = open ? [NSString stringWithFormat:@"%lu", (unsigned long)open] : nil;
    [[self.tabs.viewControllers objectAtIndex:2] tabBarItem].badgeValue = words ? [NSString stringWithFormat:@"%lu", (unsigned long)words] : nil;
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
