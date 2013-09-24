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

#import "HTTPFileSaver.h"

@interface HTTPFileSaver()
{
    BOOL appendLooping;
    NSMutableArray *dataAppendArray;
    
    NSURLConnection *_connection;
    BOOL _cancelled;
}
-(void)callDelegateSelector:(SEL)selector;

@end

@implementation HTTPFileSaver
@synthesize HTTPURL=_HTTPURL, localURL=_localURL, delegate=_delegate, actualSize=_actualSize, expectedSize=_expectedSize, downloading=_downloading;

-(id)initWithHTTPURL:(NSURL *)HTTPURL localURL:(NSURL *)localURL delegate:(NSObject<HTTPFileSaverDelegate> *)delegate
{
    if(self == [super init])
    {
        _HTTPURL = HTTPURL;
        _localURL = localURL;
        _delegate = delegate;
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
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
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
    if(_HTTPURL == nil || _localURL == nil || self.downloading || self.downloaded) return false;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_HTTPURL];
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (!_connection) return false;
    
    
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
    
    return true;
}

-(BOOL)deleteLocalFile
{
    [self cancel];
    
    NSFileManager *manager = NSFileManager.defaultManager;
    if(![manager fileExistsAtPath:_localURL.path isDirectory:nil]) return false;
    
    return [manager removeItemAtURL:_localURL error:nil];
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _downloading = true;
    [[NSData data] writeToFile:_localURL.path options:NSDataWritingAtomic error:nil];
    dataAppendArray = @[].mutableCopy;
    _expectedSize = response.expectedContentLength;
    [self callDelegateSelector:@selector(fileSaverStarted:)];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    //[webData appendData:data];
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

-(BOOL)downloaded
{
    return self.expectedSize != 0 && self.expectedSize == self.actualSize;
}

-(void)setDocumentsPath:(NSString *)documentsPath
{
    if(_downloading) return;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:documentsPath];
    
    self.localURL = [NSURL URLWithString:path];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    _downloading = false;
    [self callDelegateSelector:@selector(fileSaverCompleted:)];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self callDelegateSelector:@selector(fileSaverFailed:)];
    
}

-(void)callDelegateSelector:(SEL)selector
{
    if(self.delegate != nil && [self.delegate respondsToSelector:selector])
    {
        [self.delegate performSelector:selector withObject:self];
    }
}


@end
