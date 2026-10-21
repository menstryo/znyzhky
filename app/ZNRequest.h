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
