#import <UIKit/UIKit.h>

// Картка акції в сітці: фото, жовтий цінник-наліпка, бейдж знижки, магазин, кнопка «+ у список».
@interface ZNGridCell : UICollectionViewCell
@property (nonatomic, retain) NSDictionary *item;
+ (CGSize)sizeForWidth:(CGFloat)totalWidth columns:(NSInteger *)outColumns;
@end

// спільні намальовані фони (також для екрана товару)
UIImage *ZNStretchable(CGSize size, CGFloat radius, UIColor *fill, UIColor *shadow, CGFloat shadowY, CGFloat inset);
UIImage *ZNTagImage(void);
