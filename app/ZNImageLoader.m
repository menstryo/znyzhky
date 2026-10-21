#import "ZNImageLoader.h"
#import "ZNRequest.h"

#define ZN_MAX_ACTIVE 4

@interface ZNImageLoader () {
    NSCache *_mem;
    NSMutableDictionary *_waiters;   // url → [blocks]
    NSMutableArray *_queue;          // NSURL, LIFO
    NSInteger _active;
    NSString *_dir;
}
@end

@implementation ZNImageLoader

+ (ZNImageLoader *)shared {
    static ZNImageLoader *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[ZNImageLoader alloc] init]; });
    return s;
}

- (id)init {
    if ((self = [super init])) {
        _mem = [[NSCache alloc] init];
        _mem.countLimit = 300;
        _waiters = [[NSMutableDictionary alloc] init];
        _queue = [[NSMutableArray alloc] init];
        _dir = [[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]
                 stringByAppendingPathComponent:@"img"] retain];
        [[NSFileManager defaultManager] createDirectoryAtPath:_dir withIntermediateDirectories:YES attributes:nil error:NULL];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memoryWarning)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [self trimDiskCache];
    }
    return self;
}

- (void)memoryWarning { [_mem removeAllObjects]; }

// шлях на диску: img/silpo/abc.jpg → silpo_abc.jpg (імена вже хеші)
- (NSString *)diskPath:(NSURL *)url {
    NSArray *c = [url pathComponents];
    NSString *name = c.count >= 2
        ? [NSString stringWithFormat:@"%@_%@", [c objectAtIndex:c.count - 2], [c lastObject]]
        : [c lastObject];
    return [_dir stringByAppendingPathComponent:name];
}

// прибираємо файли, яких не відкривали 30 днів
- (void)trimDiskCache {
    NSString *dir = _dir;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSFileManager *fm = [[[NSFileManager alloc] init] autorelease];
        NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:-30 * 86400];
        for (NSString *f in [fm contentsOfDirectoryAtPath:dir error:NULL]) {
            NSString *p = [dir stringByAppendingPathComponent:f];
            NSDate *m = [[fm attributesOfItemAtPath:p error:NULL] fileModificationDate];
            if (m && [m compare:limit] == NSOrderedAscending) [fm removeItemAtPath:p error:NULL];
        }
    });
}

// Декодуємо JPEG одразу у фоні: інакше UIImage розпаковується вже під час прокрутки
// на головному потоці — на iPhone 4S це і є «смикання» сітки.
static UIImage *ZNDecode(NSData *data) {
    if (!data.length) return nil;
    UIImage *src = [UIImage imageWithData:data scale:1];
    if (!src) return nil;
    CGImageRef cg = src.CGImage;
    size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, 0, cs, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(cs);
    if (!ctx) return src;
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
    CGImageRef out = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    UIImage *img = [UIImage imageWithCGImage:out scale:1 orientation:UIImageOrientationUp];
    CGImageRelease(out);
    return img;
}

static dispatch_queue_t ZNDecodeQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = dispatch_queue_create("znyzhky.images", DISPATCH_QUEUE_SERIAL); });
    return q;
}

// лише пам'ять — без читання диска на головному потоці
- (UIImage *)cachedImageForURL:(NSURL *)url {
    return url ? [_mem objectForKey:url] : nil;
}

- (void)deliver:(UIImage *)img forURL:(NSURL *)url {
    if (img) [_mem setObject:img forKey:url];
    NSArray *blocks = [[[_waiters objectForKey:url] retain] autorelease];
    [_waiters removeObjectForKey:url];
    if (img) for (void (^b)(UIImage *) in blocks) b(img);
}

- (void)loadURL:(NSURL *)url done:(void (^)(UIImage *))done {
    if (!url) return;
    UIImage *img = [_mem objectForKey:url];
    if (img) { done(img); return; }
    NSMutableArray *w = [_waiters objectForKey:url];
    if (w) {
        [w addObject:[[done copy] autorelease]];
        if ([_queue containsObject:url]) { [_queue removeObject:url]; [_queue addObject:url]; }
        return;
    }
    [_waiters setObject:[NSMutableArray arrayWithObject:[[done copy] autorelease]] forKey:url];

    // спершу диск — у фоні
    NSString *path = [self diskPath:url];
    [url retain];
    dispatch_async(ZNDecodeQueue(), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        UIImage *disk = ZNDecode([NSData dataWithContentsOfFile:path]);
        [disk retain];
        [pool release];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (disk) [self deliver:disk forURL:url];
            else if ([_waiters objectForKey:url]) {
                [_queue addObject:url];
                if (_queue.count > 60) {
                    // найстаріший запит (клітинка давно прокручена) — викидаємо разом з очікувачами
                    [_waiters removeObjectForKey:[_queue objectAtIndex:0]];
                    [_queue removeObjectAtIndex:0];
                }
                [self pump];
            }
            [disk release];
            [url release];
        });
    });
}

- (void)pump {
    while (_active < ZN_MAX_ACTIVE && _queue.count) {
        NSURL *url = [[[_queue lastObject] retain] autorelease];
        [_queue removeLastObject];
        _active++;
        NSURLRequest *req = ZNMakeRequest(url, NSURLRequestReturnCacheDataElseLoad, 20);
        NSString *path = [self diskPath:url];
        [ZNRequest start:req done:^(NSURLResponse *resp, NSData *data, NSError *err) {
            _active--;
            NSData *ok = (ZNStatusCode(resp) == 200 && data.length) ? [[data copy] autorelease] : nil;
            if (!ok) { [self deliver:nil forURL:url]; [self pump]; return; }
            [ok retain]; [url retain];
            dispatch_async(ZNDecodeQueue(), ^{
                NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                UIImage *img = [ZNDecode(ok) retain];
                if (img) [ok writeToFile:path atomically:YES];
                [pool release];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self deliver:img forURL:url];
                    [img release]; [ok release]; [url release];
                });
            });
            [self pump];
        }];
    }
}

@end
