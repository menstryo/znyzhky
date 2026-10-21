#import "ZNRequest.h"

@implementation ZNRequest

+ (ZNRequest *)start:(NSURLRequest *)req done:(void (^)(NSURLResponse *, NSData *, NSError *))done {
    ZNRequest *r = [[ZNRequest alloc] init]; // звільняється після завершення
    r->_done = [done copy];
    r->_data = [[NSMutableData alloc] init];
    r->_conn = [[NSClassFromString(@"NSURLConnection") alloc] initWithRequest:req delegate:r startImmediately:NO];
    [r->_conn scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [r->_conn start];
    return r;
}

- (void)dealloc {
    [_conn release];
    [_data release];
    [_resp release];
    [_done release];
    [super dealloc];
}

- (void)finish:(NSError *)err {
    if (_done) {
        void (^d)(NSURLResponse *, NSData *, NSError *) = _done;
        _done = nil;
        d(_resp, err ? nil : _data, err);
        [d release];
        [self autorelease];
    }
}

- (void)cancel {
    if (_done) {
        [_conn cancel];
        [_done release];
        _done = nil;
        [self autorelease];
    }
}

- (void)connection:(NSURLConnection *)c willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch {
    if ([ch.protectionSpace.authenticationMethod isEqualToString:@"NSURLAuthenticationMethodServerTrust"]) {
        [ch.sender useCredential:[NSClassFromString(@"NSURLCredential") credentialForTrust:ch.protectionSpace.serverTrust] forAuthenticationChallenge:ch];
    } else {
        [ch.sender performDefaultHandlingForAuthenticationChallenge:ch];
    }
}

- (void)connection:(NSURLConnection *)c didReceiveResponse:(NSURLResponse *)r {
    [_resp release]; _resp = [r retain];
    [_data setLength:0];
}
- (void)connection:(NSURLConnection *)c didReceiveData:(NSData *)d { [_data appendData:d]; }
- (void)connectionDidFinishLoading:(NSURLConnection *)c { [self finish:nil]; }
- (void)connection:(NSURLConnection *)c didFailWithError:(NSError *)e { [self finish:e]; }
- (NSCachedURLResponse *)connection:(NSURLConnection *)c willCacheResponse:(NSCachedURLResponse *)r { return nil; }

@end

NSMutableURLRequest *ZNMakeRequest(NSURL *url, NSURLRequestCachePolicy policy, NSTimeInterval timeout) {
    return [NSClassFromString(@"NSMutableURLRequest") requestWithURL:url cachePolicy:policy timeoutInterval:timeout];
}

NSInteger ZNStatusCode(NSURLResponse *resp) {
    return [resp respondsToSelector:@selector(statusCode)] ? [(id)resp statusCode] : 0;
}
