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

- (UIImage *)cachedImageForURL:(NSURL *)url {
    if (!url) return nil;
    UIImage *img = [_mem objectForKey:url];
    if (img) return img;
    NSString *p = [self diskPath:url];
    NSData *d = [NSData dataWithContentsOfFile:p];
    if (d.length) {
        img = [UIImage imageWithData:d scale:1];
        if (img) [_mem setObject:img forKey:url];
    }
    return img;
}

- (void)loadURL:(NSURL *)url done:(void (^)(UIImage *))done {
    if (!url) return;
    UIImage *img = [self cachedImageForURL:url];
    if (img) { done(img); return; }
    NSMutableArray *w = [_waiters objectForKey:url];
    if (w) {
        [w addObject:[[done copy] autorelease]];
        // підняти в черзі
        if ([_queue containsObject:url]) { [_queue removeObject:url]; [_queue addObject:url]; }
        return;
    }
    [_waiters setObject:[NSMutableArray arrayWithObject:[[done copy] autorelease]] forKey:url];
    [_queue addObject:url];
    if (_queue.count > 60) {
        // найстаріший запит (клітинка давно прокручена) — викидаємо разом з очікувачами
        [_waiters removeObjectForKey:[_queue objectAtIndex:0]];
        [_queue removeObjectAtIndex:0];
    }
    [self pump];
}

- (void)pump {
    while (_active < ZN_MAX_ACTIVE && _queue.count) {
        NSURL *url = [[[_queue lastObject] retain] autorelease];
        [_queue removeLastObject];
        _active++;
        NSURLRequest *req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:20];
        [ZNRequest start:req done:^(NSURLResponse *resp, NSData *data, NSError *err) {
            _active--;
            NSInteger code = [resp isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)resp statusCode] : 0;
            UIImage *img = (code == 200 && data.length) ? [UIImage imageWithData:data scale:1] : nil;
            if (img) {
                [_mem setObject:img forKey:url];
                [data writeToFile:[self diskPath:url] atomically:YES];
            }
            NSArray *blocks = [[[_waiters objectForKey:url] retain] autorelease];
            [_waiters removeObjectForKey:url];
            if (img) for (void (^b)(UIImage *) in blocks) b(img);
            [self pump];
        }];
    }
}

@end
