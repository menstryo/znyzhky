#import <UIKit/UIKit.h>

// Завантаження мініатюр: пам'ять → диск → мережа, не більше 4 запитів одночасно,
// останні запитані йдуть першими (щоб при прокрутці вантажились видимі клітинки).
@interface ZNImageLoader : NSObject
+ (ZNImageLoader *)shared;
- (UIImage *)cachedImageForURL:(NSURL *)url;
- (void)loadURL:(NSURL *)url done:(void (^)(UIImage *img))done;
@end
