/*
 Copyright (c) 2013 Reed Weichler
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */
//-------------------------------------------------------------------------
#pragma mark Forward declarations
//-------------------------------------------------------------------------
@interface NSString(NSString_Extended)
-(NSString *)urlencode;
@end

#import "HTTPFileSaver.h"

@interface HTTPFileSaver()
{
    BOOL appendLooping;
    NSMutableArray *dataAppendArray;
    
    NSURLConnection *_connection;
    BOOL _cancelled;
    
    int _currentFileSize;
    int _currentFileSizeBeforeFail;
    int _currentExpectedFileSize;
    
    NSDictionary *_currentURLDict;
    
    BOOL _downloaded;
    
    int _currentURLIndex;
}
-(void)callDelegateSelector:(SEL)selector;
@end

@implementation HTTPFileSaver
@synthesize HTTPURL=_HTTPURL, localURL=_localURL, delegate=_delegate, actualSize=_actualSize, expectedSize=_expectedSize, downloading=_downloading, HTTPURLs=_HTTPURLs;

-(id)initWithHTTPURLs:(NSArray *)HTTPURLs localURL:(NSURL *)localURL delegate:(NSObject<HTTPFileSaverDelegate> *)delegate
{
    if(self == [super init])
    {
        assert(HTTPURLs.count > 0);
        
        self.HTTPURLs = HTTPURLs;
        _localURL = localURL;
        _delegate = delegate;
        
        _currentFileSizeBeforeFail = 0;
        _currentURLIndex = 0;
        
    }
    return self;
}

-(id)initWithHTTPURL:(NSURL *)HTTPURL localURL:(NSURL *)localURL delegate:(NSObject<HTTPFileSaverDelegate> *)delegate
{
    if(self == [super init])
    {
        _HTTPURL = HTTPURL;
        _localURL = localURL;
        _delegate = delegate;
        
        _currentFileSizeBeforeFail = 0;
        _currentURLIndex = 0;
    }
    return self;
}

-(id)initWithHTTPURL:(NSURL *)HTTPURL localURL:(NSURL *)localURL
{
    return [self initWithHTTPURL:HTTPURL localURL:localURL delegate:nil];
}

-(id)initWithHTTPPath:(NSString *)HTTPPath localPath:(NSString *)localPath delegate:(NSObject<HTTPFileSaverDelegate> *)delegate
{
    NSURL *HTTPURL = HTTPPath == nil? nil:[NSURL URLWithString:HTTPPath];
    return [self initWithHTTPURL:HTTPURL localURL:[NSURL URLWithString:localPath] delegate:delegate];
}

-(id)initWithHTTPPath:(NSString *)HTTPPath localPath:(NSString *)localPath
{
    return [self initWithHTTPPath:HTTPPath localPath:localPath delegate:nil];
}

-(id)initWithHTTPPath:(NSString *)HTTPPath documentsPath:(NSString *)documentsPath delegate:(NSObject<HTTPFileSaverDelegate> *)delegate
{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:documentsPath];
    
    return [self initWithHTTPPath:HTTPPath localPath:path delegate:delegate];
}

-(id)initWithHTTPPath:(NSString *)HTTPPath documentsPath:(NSString *)documentsPath
{
    return [self initWithHTTPPath:HTTPPath documentsPath:documentsPath delegate:nil];
}

-(BOOL)start
{
    return [self startIsInitial:true];
}

-(BOOL)resume
{
    return [self startIsInitial:false];
}

-(void)setHTTPURLs:(NSArray *)HTTPURLs
{
    int index = _currentURLIndex;
    
    NSLog(@"Setting HTTPURLS, first index is %d", index);
    
    _HTTPURLs = HTTPURLs;
    
    if(_HTTPURLs == nil) return;
    
    id url;
    if([HTTPURLs[index] isKindOfClass:NSDictionary.class])
    {
        _currentURLDict = HTTPURLs[index];
        url = _currentURLDict[@"url"];
    }
    else
    {
        url = HTTPURLs[index];
    }
    if([url isKindOfClass:NSURL.class])
        _HTTPURL = url;
    else if([url isKindOfClass:NSString.class])
        _HTTPURL = [NSURL URLWithString:url];
}

-(void)forceCompletion
{
    _downloading = false;
    _downloaded = true;
    _expectedSize = 300000;
    _actualSize = self.expectedSize;
    
    [self callDelegateSelector:@selector(fileSaverCompleted:)];
}

-(BOOL)fileExistsAtLocalURL
{
    return self.localURL != nil && [NSFileManager.defaultManager fileExistsAtPath:self.localURL.path];
}

-(BOOL)startIsInitial:(BOOL)initial
{
    if(initial && self.fileExistsAtLocalURL) return false;
    
    if(_HTTPURL == nil || _localURL == nil || (initial && (self.downloading || self.downloaded))) return false;
    
    NSLog(@"Starting request with URL: %@", _HTTPURL);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_HTTPURL];
    if(self.properties[@"cookies"])
    {
        NSDictionary *cookies = self.properties[@"cookies"];
        //convert cookies into NSHTTPCookies
        NSMutableArray *cookieJar = @[].mutableCopy;
        for(id key in cookies)
        {
            NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        _HTTPURL, NSHTTPCookieOriginURL,
                                        key, NSHTTPCookieName,
                                        [cookies valueForKey:key], NSHTTPCookieValue,
                                        nil];
            NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:properties];
            if(cookie != nil)
                [cookieJar addObject:cookie];
        }
        //put cookies in header
        NSDictionary *cookieHeader = [NSHTTPCookie requestHeaderFieldsWithCookies:cookieJar];
        for(id key in cookieHeader)
        {
            [request addValue:cookieHeader[key] forHTTPHeaderField:key];
        }
    }
    if(self.properties[@"headers"])
    {
        NSDictionary *headers = self.properties[@"headers"];
        for(id key in headers)
        {
            [request addValue:headers[key] forHTTPHeaderField:key];
        }
    }
    if(self.properties[@"method"])
    {
        request.HTTPMethod = [self.properties[@"method"] uppercaseString];
    }
    if(self.properties[@"params"])
    {
        NSDictionary *params = self.properties[@"params"];
        //add params
        NSMutableString *body = [NSMutableString string];
        BOOL setFirst = false;
        for(NSString *key in params)
        {
            if(!setFirst)
            {
                setFirst = true;
            }
            else
            {
                [body appendString:@"&"];
            }
            NSString *val = [NSString stringWithFormat:@"%@", params[key]];
            
            NSString *tempkey = [NSString stringWithFormat:@"%@", key];
            
            [body appendFormat:@"%@%@%@", tempkey.urlencode, @"=", val.urlencode];
        }
        if([request.HTTPMethod isEqualToString:@"GET"] || self.properties[@"method"] == nil)
        {
            NSString *strURL = [NSString stringWithFormat:@"%@%@%@", _HTTPURL, @"?", body];
            request.URL = [NSURL URLWithString:strURL];
        }
        else
        {
            request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
        }
    }
    
    int start = [_currentURLDict[@"start"] intValue] + _currentFileSizeBeforeFail;
    int end = [_currentURLDict[@"end"] intValue];
    if(start || end)
    {
        NSString *endstr;
        if(end == 0)
        {
            endstr = @"";
        }
        else
        {
            endstr = [NSString stringWithFormat:@"%d", end];
        }
        
        NSString *val = [NSString stringWithFormat:@"bytes=%d-%@", start, endstr];
        NSLog(@"Range: %@", val);
        
        [request addValue:val forHTTPHeaderField:@"Range"];
    }
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (!_connection) return false;
    
    _cancelled = false;
    [_connection start];
    
    return true;
}

-(BOOL)cancel
{
    if(_connection == nil) return false;
    
    [_connection cancel];
    _connection = nil;
    _downloading = false;
    _cancelled = true;
    
    dataAppendArray = nil;
    
    [self callDelegateSelector:@selector(fileSaverCancelled:)];
    
    return true;
}

-(BOOL)deleteLocalFile
{
    [self cancel];
    
    NSFileManager *manager = NSFileManager.defaultManager;
    if(![manager fileExistsAtPath:_localURL.path isDirectory:nil]) return false;
    
    return [manager removeItemAtURL:_localURL error:nil];
}

-(BOOL)pauseDownload
{
    if(self.pausedDownload) return false;
    self.pausedDownload = true;
    
    
    [_connection cancel];
    _currentFileSizeBeforeFail += _currentFileSize;
    _expectedSize += _currentFileSize;
    _currentFileSize = 0;
    
    return true;
}

-(void)connectionFailedWithStatusCode:(int)statusCode
{
    [self pauseDownload];
    if(statusCode == 0) //connection simply timed out, try again
    {
        [self startIsInitial:false];
    }
    else //actual error
    {
        
    }
    
    
    if([self.delegate respondsToSelector:@selector(fileSaver:failedWithStatusCode:)])
    {
        [self.delegate fileSaver:self failedWithStatusCode:statusCode];
    }
    
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSLog(@"GOT RESPONSE, expectedContentLength = %d", (int)response.expectedContentLength);
    if(_cancelled) return;
    
    int statusCode = [(NSHTTPURLResponse *)response statusCode];
    if(statusCode < 200 || statusCode > 299)
    {
        NSLog(@"FAILURE: response statuscode is %d", statusCode);
        [self connectionFailedWithStatusCode:statusCode];
        return;
    }
    
    self.pausedDownload = false;
    
    if(dataAppendArray == nil)
        dataAppendArray = @[].mutableCopy;
    
    if(!_downloading)
    {
        [[NSData data] writeToFile:_localURL.path options:NSDataWritingAtomic error:nil];
        _actualSize = 0;
        _expectedSize = 0;
        _downloading = true;
    }
    _currentExpectedFileSize = (int)response.expectedContentLength;
    [self callDelegateSelector:@selector(fileSaverStarted:)];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    int len = (int)data.length;
    int dataStart = 0, dataLen = len;
    /*
    if(_HTTPURLs != nil && _currentURLDict != nil && (_currentURLDict[@"start"] || _currentURLDict[@"end"]))
    {
        int start = [_currentURLDict[@"start"] intValue];
        int end = [_currentURLDict[@"end"] intValue];
        
        if(start != 0 && _currentFileSize < start)
        {
            dataStart = start - _currentFileSize;
            //NSLog(@"changing start");
        }
        
        if(end != 0 && _currentFileSize + len > end && _currentFileSize < end)
        {
            dataLen = end - _currentFileSize - dataStart;
            //NSLog(@"changing end");
        }
        else
        {
            dataLen = len - dataStart;
        }
        if(dataLen < 0) dataLen = 0;
    }
    
    _currentExpectedFileSize -= len - dataLen;
    
    //if we previously failed the download, then don't redownload it
    int difference = _currentFileSizeBeforeFail - (_currentFileSize + dataStart);
    if(difference > 0)
    {
        dataLen -= difference;
        dataStart += difference;
        if(dataLen < 0) dataLen = 0;
    }
    
    if(!(dataStart == 0 && dataLen == len) && dataLen != 0)
    {
        NSRange range = {dataStart, dataLen};
        data = [data subdataWithRange:range];
    }
    else if(dataLen == 0)
    {
        data = nil;
    }*/
    
    _currentFileSize += len;
    
    if(data != nil)
        [dataAppendArray addObject:data];
    [self appendLoop];
    
    [self callDelegateSelector:@selector(fileSaverGotData:)];
}

-(void)appendLoop
{
    if(!appendLooping)
    {
        appendLooping = true;
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:_localURL.path];
        while(dataAppendArray.count > 0 && !_cancelled)
        {
            NSData *data = dataAppendArray[0];
            _actualSize += data.length;
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:data];
            [dataAppendArray removeObjectAtIndex:0];
        }
        [fileHandle closeFile];
        appendLooping = false;
    }
    
}

-(void)setLocalURL:(NSURL *)localURL
{
    if(!_downloading)
    {
        _localURL = localURL;
    }
}

-(void)setHTTPURL:(NSURL *)HTTPURL
{
    if(!_downloading)
    {
        _HTTPURL = HTTPURL;
    }
}

-(int)expectedSize
{
    return _expectedSize + _currentExpectedFileSize;
}

-(BOOL)downloaded
{
    if(_downloaded) return true;
    
    id obj = _currentURLDict;
    if(obj == nil) obj = _HTTPURL;
    return self.expectedSize != 0 && self.expectedSize == self.actualSize && (_HTTPURLs == nil || [_HTTPURLs indexOfObject:obj] == NSNotFound || [_HTTPURLs indexOfObject:obj] == _HTTPURLs.count - 1);
}

-(void)setDocumentsPath:(NSString *)documentsPath
{
    if(_downloading) return;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:documentsPath];
    
    self.localURL = [NSURL URLWithString:path];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    _currentFileSize = 0;
    _currentFileSizeBeforeFail = 0;
    _expectedSize += _currentExpectedFileSize;
    _currentExpectedFileSize = 0;
    if(_HTTPURLs != nil)
    {
        _currentURLIndex++;
        
        if(_currentURLIndex < _HTTPURLs.count)
        {
            id url;
            if([_HTTPURLs[_currentURLIndex] isKindOfClass:NSDictionary.class])
            {
                _currentURLDict = _HTTPURLs[_currentURLIndex];
                url = _currentURLDict[@"url"];
            }
            else
            {
                url = _HTTPURLs[_currentURLIndex];
            }
            if([url isKindOfClass:NSURL.class])
                _HTTPURL = url;
            else if([url isKindOfClass:NSString.class])
                _HTTPURL = [NSURL URLWithString:url];
            
            [self startIsInitial:false];
            NSLog(@"finished section");
            return;
        }
        else
        {
            _HTTPURL = nil;
            _currentURLDict = nil;
            _HTTPURLs = nil;
            _currentURLIndex = 0;
        }
    }
    NSLog(@"finished download: %d %d", _actualSize, self.expectedSize);
    _downloading = false;
    _downloaded = true;
    [self callDelegateSelector:@selector(fileSaverCompleted:)];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    //NSLog(@"connection failed, i.e. timed out");
    
    [self connectionFailedWithStatusCode:0];
    
}

-(void)callDelegateSelector:(SEL)selector
{
    if(self.delegate != nil && [self.delegate respondsToSelector:selector])
    {
        [self.delegate performSelector:selector withObject:self];
    }
}

@end
//-------------------------------------------------------------------------

@implementation NSString (NSString_Extended)

- (NSString *)urlencode {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[self UTF8String];
    int sourceLen = (int)strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}
@end
