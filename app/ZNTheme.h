#import <UIKit/UIKit.h>

// Фірмові кольори «Знижок»: теплий коралово-гранатовий замість стандартного червоного,
// кремовий фон замість синьо-смугастого фону iOS 6.
#define ZN_ACCENT      [UIColor colorWithRed:0.83 green:0.30 blue:0.24 alpha:1]   // навбар, кнопки, перемикачі
#define ZN_ACCENT_DARK [UIColor colorWithRed:0.70 green:0.20 blue:0.16 alpha:1]   // ціни, бейджі
#define ZN_ACCENT_SOFT [UIColor colorWithRed:0.93 green:0.55 blue:0.45 alpha:1]   // вибрана вкладка на темному таббарі
#define ZN_BG          [UIColor colorWithRed:0.97 green:0.95 blue:0.92 alpha:1]   // кремовий фон
#define ZN_BG_HEADER   [UIColor colorWithRed:0.94 green:0.90 blue:0.86 alpha:1]   // смуга пошуку
#define ZN_TABBAR      [UIColor colorWithRed:0.20 green:0.15 blue:0.14 alpha:1]   // теплий темно-коричневий
#define ZN_TEXT_MUTED  [UIColor colorWithRed:0.52 green:0.45 blue:0.42 alpha:1]   // підписи, заголовки секцій

@interface ZNTheme : NSObject
+ (void)apply;                                        // UIAppearance для всього застосунку
+ (BOOL)isFlat;
+ (BOOL)handwriting;                                  // рукописний шрифт у списку (iOS 6 — так, iOS 7+ — ні, змінюється в «Ще»)
+ (void)setHandwriting:(BOOL)on;                                       // iOS 7+
+ (void)styleGroupedTable:(UITableView *)tv;          // кремовий фон замість смугастого
+ (UIView *)sectionHeaderWithTitle:(NSString *)title width:(CGFloat)w;
+ (UIView *)sectionFooterWithText:(NSString *)text width:(CGFloat)w;
+ (CGFloat)heightForFooterText:(NSString *)text width:(CGFloat)w;
@end
