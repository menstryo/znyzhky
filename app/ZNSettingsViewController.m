#import "ZNSettingsViewController.h"
#import "ZNGridViewController.h"
#import "ZNStore.h"
#import "ZNTheme.h"
#import "ZNLeafletsViewController.h"
#import "ZNNotifier.h"

enum { ZNSecCity = 0, ZNSecNotify, ZNSecLook, ZNSecWords, ZNSecData, ZNSecAbout, ZNSecCount };

@implementation ZNSettingsViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Ще";
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [ZNTheme styleGroupedTable:self.tableView];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reloadTable) name:ZNStoreDidUpdateNotification object:nil];
    [nc addObserver:self selector:@selector(reloadTable) name:ZNStoreLoadingNotification object:nil];
}

- (void)reloadTable { [self.tableView reloadData]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - headers / footers

- (NSString *)titleFor:(NSInteger)s {
    switch (s) {
        case ZNSecCity:  return @"Місто";
        case ZNSecNotify: return @"Сповіщення";
        case ZNSecLook:  return @"Вигляд";
        case ZNSecWords: return @"Відстежувати слова";
        case ZNSecData:  return @"Дані";
        default:         return @"Про застосунок";
    }
}
- (NSString *)footerFor:(NSInteger)s {
    if (s == ZNSecCity) return @"Для Metro, Novus, ЕКО маркет і газеток місцевих мереж. Вкладка «Газетки» з’являється, лише якщо вони є у вашому місті. Сільпо, АТБ, Varus і Аврора — однакові по всій Україні.";
    if (s == ZNSecLook) return @"Шрифт «Marker Felt» у списку покупок — як в оригінальних «Нотатках».";
    if (s == ZNSecNotify) return @"Не частіше двох нових на день і не вночі (22:00–9:00). Нове перевіряється у фоні приблизно раз на 2 години.";
    if (s == ZNSecWords) return @"Наприклад «кава», «Nivea», «підгузки». Бейдж на вкладці «Ще» покаже, скільки таких товарів зараз в акції в усіх магазинах.";
    if (s == ZNSecData) return @"Акції збираються на сервері кожні 4 години. Ціни національних мереж можуть трохи відрізнятися в окремих магазинах.";
    return @"Знижки не пов'язані з жодною мережею магазинів.";
}
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    return [ZNTheme sectionHeaderWithTitle:[self titleFor:s] width:tv.bounds.size.width];
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return 40; }
- (UIView *)tableView:(UITableView *)tv viewForFooterInSection:(NSInteger)s {
    return [ZNTheme sectionFooterWithText:[self footerFor:s] width:tv.bounds.size.width];
}
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s {
    return [ZNTheme heightForFooterText:[self footerFor:s] width:tv.bounds.size.width];
}

#pragma mark - rows

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return ZNSecCount; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (s == ZNSecCity) return 1;
    if (s == ZNSecNotify) return 4;
    if (s == ZNSecLook) return 1;
    if (s == ZNSecWords) return [ZNStore shared].watchWords.count + 1;
    return 3;
}

- (NSString *)formatDate:(NSDate *)d {
    if (!d) return @"—";
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    f.dateFormat = @"dd.MM HH:mm";
    return [f stringFromDate:d];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease];
    c.detailTextLabel.textColor = ZN_TEXT_MUTED;
    ZNStore *st = [ZNStore shared];
    if (ip.section == ZNSecCity) {
        c.textLabel.text = @"Ваше місто";
        c.detailTextLabel.text = st.cityName ?: @"не вибрано";
        if (!st.cityId) c.detailTextLabel.textColor = ZN_ACCENT_DARK;
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (ip.section == ZNSecLook) {
        c.textLabel.text = @"Рукописний список";
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[[UISwitch alloc] init] autorelease];
        sw.on = [ZNTheme handwriting];
        [sw addTarget:self action:@selector(handSwitch:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
    } else if (ip.section == ZNSecNotify) {
        NSArray *kinds = @[ZNNotifyList, ZNNotifyWords, ZNNotifyCheap, ZNNotifyNews];
        NSArray *titles = @[@"Кінець акцій зі списку", @"Нові акції за словами", @"Дешевше в іншій мережі", @"Нові газетки"];
        c.textLabel.text = [titles objectAtIndex:ip.row];
        c.textLabel.adjustsFontSizeToFitWidth = YES;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[[UISwitch alloc] init] autorelease];
        sw.on = [[ZNNotifier shared] isOn:[kinds objectAtIndex:ip.row]];
        sw.tag = ip.row;
        [sw addTarget:self action:@selector(notifySwitch:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
    } else if (ip.section == ZNSecWords) {
        NSArray *words = st.watchWords;
        if (ip.row < (NSInteger)words.count) {
            NSString *w = [words objectAtIndex:ip.row];
            NSUInteger n = [st itemsMatchingText:w inItems:st.allItems].count;
            c.textLabel.text = w;
            c.detailTextLabel.text = n ? [NSString stringWithFormat:@"%lu в акції", (unsigned long)n] : @"немає";
            if (n) c.detailTextLabel.textColor = ZN_ACCENT_DARK;
            c.accessoryType = n ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
            c.selectionStyle = n ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
        } else {
            c.textLabel.text = @"+ Додати слово";
            c.textLabel.textColor = ZN_ACCENT_DARK;
        }
    } else if (ip.section == ZNSecData) {
        if (ip.row == 0) {
            c.textLabel.text = @"Зібрано на сервері";
            c.detailTextLabel.text = [self formatDate:st.updatedAt];
            c.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (ip.row == 1) {
            c.textLabel.text = st.loading ? @"Оновлення…" : @"Оновити зараз";
            c.textLabel.textColor = ZN_ACCENT_DARK;
            NSUInteger n = st.allItems.count;
            c.detailTextLabel.text = n ? [NSString stringWithFormat:@"%lu акцій", (unsigned long)n] : nil;
        } else {
            c.textLabel.text = @"Сервер";
            c.detailTextLabel.text = [[st.serverURL stringByReplacingOccurrencesOfString:@"https://" withString:@""]
                                      stringByReplacingOccurrencesOfString:@"http://" withString:@""];
            c.detailTextLabel.adjustsFontSizeToFitWidth = YES;
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
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
    return c;
}

- (void)handSwitch:(UISwitch *)sw {
    [ZNTheme setHandwriting:sw.on];
    [[NSNotificationCenter defaultCenter] postNotificationName:ZNStoreListChangedNotification object:nil]; // список перемалюється
}

- (void)notifySwitch:(UISwitch *)sw {
    NSArray *kinds = @[ZNNotifyList, ZNNotifyWords, ZNNotifyCheap, ZNNotifyNews];
    [[ZNNotifier shared] setOn:sw.on kind:[kinds objectAtIndex:sw.tag]];
}

- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip {
    return ip.section == ZNSecWords && ip.row < (NSInteger)[ZNStore shared].watchWords.count;
}
- (NSString *)tableView:(UITableView *)tv titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)ip { return @"Видалити"; }
- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip {
    if (style == UITableViewCellEditingStyleDelete) [[ZNStore shared] removeWatchWordAtIndex:ip.row];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    ZNStore *st = [ZNStore shared];
    if (ip.section == ZNSecCity) {
        [self.navigationController pushViewController:[[[ZNCityPickerViewController alloc] init] autorelease] animated:YES];
    } else if (ip.section == ZNSecWords) {
        if (ip.row < (NSInteger)st.watchWords.count) {
            NSString *w = [st.watchWords objectAtIndex:ip.row];
            if (![st itemsMatchingText:w inItems:st.allItems].count) return;
            ZNGridViewController *g = [[[ZNGridViewController alloc] initWithFixedQuery:w] autorelease];
            [self.navigationController pushViewController:g animated:YES];
        } else {
            UIAlertView *a = [[[UIAlertView alloc] initWithTitle:@"Відстежувати слово"
                                                         message:@"Покажемо всі акційні товари, в назві яких воно є"
                                                        delegate:self cancelButtonTitle:@"Скасувати" otherButtonTitles:@"Додати", nil] autorelease];
            a.alertViewStyle = UIAlertViewStylePlainTextInput;
            a.tag = 1;
            [a textFieldAtIndex:0].placeholder = @"наприклад: кава";
            [a textFieldAtIndex:0].autocorrectionType = UITextAutocorrectionTypeNo;
            [a show];
        }
    } else if (ip.section == ZNSecData && ip.row == 1) {
        [st refresh];
    } else if (ip.section == ZNSecData && ip.row == 2) {
        UIAlertView *a = [[[UIAlertView alloc] initWithTitle:@"Адреса сервера"
                                                     message:@"Залиште порожньою, щоб повернути стандартну"
                                                    delegate:self cancelButtonTitle:@"Скасувати" otherButtonTitles:@"Зберегти", nil] autorelease];
        a.alertViewStyle = UIAlertViewStylePlainTextInput;
        a.tag = 2;
        UITextField *tf = [a textFieldAtIndex:0];
        tf.text = st.serverURL;
        tf.keyboardType = UIKeyboardTypeURL;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [a show];
    } else if (ip.section == ZNSecAbout && ip.row < 2) {
        NSString *u = ip.row == 0 ? @"https://t.me/menstryo" : @"https://t.me/menstry0";
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:u]];
    }
}

- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (i == a.cancelButtonIndex) return;
    if (a.tag == 1) {
        [[ZNStore shared] addWatchWord:[a textFieldAtIndex:0].text];
    } else {
        [[ZNStore shared] setServerURL:[a textFieldAtIndex:0].text];
        [[ZNStore shared] refresh];
    }
    [self.tableView reloadData];
}

@end
