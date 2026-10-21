#import <Foundation/Foundation.h>

// NSURLConnection-обгортка, що довіряє сертифікату нашого хоста даних.
// На iOS 6 застаріле сховище кореневих сертифікатів; дані публічні, тож це прийнятно.
@interface ZNRequest : NSObject {
    NSURLConnection *_conn;
    NSMutableData *_data;
    NSURLResponse *_resp;
    void (^_done)(NSURLResponse *, NSData *, NSError *);
}
+ (ZNRequest *)start:(NSURLRequest *)req done:(void (^)(NSURLResponse *resp, NSData *data, NSError *err))done;
- (void)cancel;
@end

// SDK 9.3 прив'язує NSURL*-класи до CFNetwork, а на iOS 6 вони живуть у Foundation —
// пряме посилання валить застосунок при запуску (dyld: Symbol not found). Тому лише через рантайм.
NSMutableURLRequest *ZNMakeRequest(NSURL *url, NSURLRequestCachePolicy policy, NSTimeInterval timeout);
NSInteger ZNStatusCode(NSURLResponse *resp);
