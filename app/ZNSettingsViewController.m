#import "ZNSettingsViewController.h"
#import "ZNStore.h"

enum { ZNSecStores = 0, ZNSecFilter, ZNSecData, ZNSecAbout, ZNSecCount };

@implementation ZNSettingsViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Налаштування";
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reloadTable) name:ZNStoreDidUpdateNotification object:nil];
    [nc addObserver:self selector:@selector(reloadTable) name:ZNStoreLoadingNotification object:nil];
}

- (void)reloadTable { [self.tableView reloadData]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSArray *)stores { return [ZNStore shared].stores; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return ZNSecCount; }

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    switch (s) {
        case ZNSecStores: return @"Магазини";
        case ZNSecFilter: return @"Фільтр";
        case ZNSecData:   return @"Дані";
        default:          return @"Про застосунок";
    }
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == ZNSecStores) return @"Акції загальнонаціональні: ціни можуть трохи відрізнятися в окремих магазинах мережі.";
    if (s == ZNSecData) return @"Дані оновлюються на сервері кожні 4 години.";
    if (s == ZNSecAbout) return @"Знижки не пов'язані з жодною мережею магазинів.";
    return nil;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case ZNSecStores: return MAX(1, (NSInteger)self.stores.count);
        case ZNSecFilter: return 1;
        case ZNSecData:   return 3;
        default:          return 3;
    }
}

- (NSString *)formatDate:(NSDate *)d {
    if (!d) return @"—";
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    f.dateFormat = @"dd.MM HH:mm";
    return [f stringFromDate:d];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease];
    ZNStore *st = [ZNStore shared];
    switch (ip.section) {
        case ZNSecStores: {
            if (!self.stores.count) {
                c.textLabel.text = @"Ще не завантажено";
                c.textLabel.textColor = [UIColor grayColor];
                c.selectionStyle = UITableViewCellSelectionStyleNone;
                break;
            }
            NSDictionary *s = [self.stores objectAtIndex:ip.row];
            c.textLabel.text = [s objectForKey:@"name"];
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *sw = [[[UISwitch alloc] init] autorelease];
            sw.on = [st isStoreEnabled:[s objectForKey:@"id"]];
            sw.tag = ip.row;
            [sw addTarget:self action:@selector(storeSwitched:) forControlEvents:UIControlEventValueChanged];
            c.accessoryView = sw;
            break;
        }
        case ZNSecFilter: {
            c.textLabel.text = @"Мінімальна знижка";
            NSInteger m = st.minDiscount;
            c.detailTextLabel.text = m ? [NSString stringWithFormat:@"від %ld%%", (long)m] : @"будь-яка";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        }
        case ZNSecData: {
            if (ip.row == 0) {
                c.textLabel.text = @"Зібрано на сервері";
                c.detailTextLabel.text = [self formatDate:st.updatedAt];
                c.selectionStyle = UITableViewCellSelectionStyleNone;
            } else if (ip.row == 1) {
                c.textLabel.text = st.loading ? @"Оновлення…" : @"Оновити зараз";
                c.textLabel.textAlignment = NSTextAlignmentCenter;
                c.textLabel.textColor = [UIColor colorWithRed:0.22 green:0.33 blue:0.53 alpha:1];
            } else {
                c.textLabel.text = @"Сервер";
                c.detailTextLabel.text = [[st.serverURL stringByReplacingOccurrencesOfString:@"https://" withString:@""]
                                          stringByReplacingOccurrencesOfString:@"http://" withString:@""];
                c.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            break;
        }
        default: {
            if (ip.row == 0) {
                c.textLabel.text = @"Канал розробника";
                c.detailTextLabel.text = @"t.me/menstryo";
                c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else if (ip.row == 1) {
                c.textLabel.text = @"Задати питання";
                c.detailTextLabel.text = @"t.me/menstry0";
                c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                c.textLabel.text = @"Версія";
                c.detailTextLabel.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
                c.selectionStyle = UITableViewCellSelectionStyleNone;
            }
        }
    }
    return c;
}

- (void)storeSwitched:(UISwitch *)sw {
    if (sw.tag >= (NSInteger)self.stores.count) return;
    NSDictionary *s = [self.stores objectAtIndex:sw.tag];
    [[ZNStore shared] setStore:[s objectForKey:@"id"] enabled:sw.on];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == ZNSecFilter) {
        UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:@"Мінімальна знижка" delegate:self cancelButtonTitle:nil
                                          destructiveButtonTitle:nil otherButtonTitles:@"Будь-яка", @"від 20%", @"від 30%",
                                                                 @"від 40%", @"від 50%", nil] autorelease];
        s.cancelButtonIndex = [s addButtonWithTitle:@"Скасувати"];
        if (self.tabBarController) [s showFromTabBar:self.tabBarController.tabBar];
        else [s showInView:self.view];
    } else if (ip.section == ZNSecData && ip.row == 1) {
        [[ZNStore shared] refresh];
    } else if (ip.section == ZNSecData && ip.row == 2) {
        UIAlertView *a = [[[UIAlertView alloc] initWithTitle:@"Адреса сервера"
                                                     message:@"Залиште порожньою, щоб повернути стандартну"
                                                    delegate:self cancelButtonTitle:@"Скасувати" otherButtonTitles:@"Зберегти", nil] autorelease];
        a.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField *tf = [a textFieldAtIndex:0];
        tf.text = [ZNStore shared].serverURL;
        tf.keyboardType = UIKeyboardTypeURL;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [a show];
    } else if (ip.section == ZNSecAbout && ip.row < 2) {
        NSString *u = ip.row == 0 ? @"https://t.me/menstryo" : @"https://t.me/menstry0";
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:u]];
    }
}

- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {
    if (i == s.cancelButtonIndex || i < 0) return;
    static const NSInteger vals[] = { 0, 20, 30, 40, 50 };
    if (i < 5) [[ZNStore shared] setMinDiscount:vals[i]];
    [self.tableView reloadData];
}

- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (i == a.cancelButtonIndex) return;
    [[ZNStore shared] setServerURL:[a textFieldAtIndex:0].text];
    [self.tableView reloadData];
    [[ZNStore shared] refresh];
}

@end
