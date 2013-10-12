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
    
    int _currentFileSize;
    
    NSDictionary *_currentURLDict;
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
    return [self startIsInitial:true];
}

-(void)setHTTPURLs:(NSArray *)HTTPURLs
{
    _HTTPURLs = HTTPURLs;
    
    if(_HTTPURLs == nil) return;
    
    id url;
    if([HTTPURLs[0] isKindOfClass:NSDictionary.class])
    {
        _currentURLDict = HTTPURLs[0];
        url = _currentURLDict[@"url"];
    }
    else
    {
        url = HTTPURLs[0];
    }
    if([url isKindOfClass:NSURL.class])
        _HTTPURL = url;
    else if([url isKindOfClass:NSString.class])
        _HTTPURL = [NSURL URLWithString:url];
}

-(BOOL)startIsInitial:(BOOL)initial
{
    if(_HTTPURL == nil || _localURL == nil || (initial && (self.downloading || self.downloaded))) return false;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_HTTPURL];
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
    if(!_downloading)
    {
        [[NSData data] writeToFile:_localURL.path options:NSDataWritingAtomic error:nil];
        dataAppendArray = @[].mutableCopy;
        _downloading = true;
    }
    _expectedSize += (int)response.expectedContentLength;
    [self callDelegateSelector:@selector(fileSaverStarted:)];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    int len = (int)data.length;
    
    if(_HTTPURLs != nil && _currentURLDict != nil && (_currentURLDict[@"start"] || _currentURLDict[@"end"]))
    {
        int start = [_currentURLDict[@"start"] intValue];
        int end = [_currentURLDict[@"end"] intValue];
        
        int dataStart = 0;
        
        if(start != 0 && _currentFileSize < start)
        {
            dataStart = start - _currentFileSize;
            //NSLog(@"changing start");
        }
        
        int dataLen;
        
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
        
        //NSLog(@"%d-%d", dataStart, dataLen);
        
        if(!(dataStart == 0 && dataLen == len))
        {
            if(dataLen == 0)
            {
                data = nil;
            }
            else
            {
                NSRange range = {dataStart, dataLen};
                data = [data subdataWithRange:range];
            }
        }
        _expectedSize -= len - dataLen;
    }
    
    //NSLog(@"recieved data");
    
    _currentFileSize += len;
    //[webData appendData:data];
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

-(BOOL)downloaded
{
    id obj = _currentURLDict;
    if(obj == nil) obj = _HTTPURL;
    return self.expectedSize != 0 && self.expectedSize == self.actualSize && (_HTTPURLs == nil || [_HTTPURLs indexOfObject:obj] == NSNotFound || [_HTTPURLs indexOfObject:obj] == _HTTPURLs.count - 1);
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
    _currentFileSize = 0;
    if(_HTTPURLs != nil)
    {
        NSLog(@"finished section");
        id obj;
        if(_currentURLDict != nil)
            obj = _currentURLDict;
        else
            obj = _HTTPURL;
        NSUInteger index = [_HTTPURLs indexOfObject:obj];
        if(index != NSNotFound && index < _HTTPURLs.count - 1)
        {
            index = index + 1;
            
            id url;
            if([_HTTPURLs[index] isKindOfClass:NSDictionary.class])
            {
                _currentURLDict = _HTTPURLs[index];
                url = _currentURLDict[@"url"];
            }
            else
            {
                url = _HTTPURLs[index];
            }
            if([url isKindOfClass:NSURL.class])
                _HTTPURL = url;
            else if([url isKindOfClass:NSString.class])
                _HTTPURL = [NSURL URLWithString:url];
            
            [self startIsInitial:false];
            return;
        }
        else if(index == _HTTPURLs.count - 1)
        {
            _HTTPURL = nil;
            _currentURLDict = nil;
            _HTTPURLs = nil;
        }
    }
    NSLog(@"finished download");
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
