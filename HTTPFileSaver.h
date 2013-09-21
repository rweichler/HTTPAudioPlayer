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

#import <Foundation/Foundation.h>

@class HTTPFileSaver;
@protocol HTTPFileSaverDelegate<NSObject>
@optional
-(void)fileSaverStarted:(HTTPFileSaver *)saver;
-(void)fileSaverCompleted:(HTTPFileSaver *)saver;
-(void)fileSaverFailed:(HTTPFileSaver *)saver;
-(void)fileSaverGotData:(HTTPFileSaver *)saver;
@end

@interface HTTPFileSaver : NSObject<NSURLConnectionDelegate>

-(id)initWithHTTPURL:(NSURL *)HTTPURL localURL:(NSURL *)localURL;
-(id)initWithHTTPURL:(NSURL *)HTTPURL localURL:(NSURL *)localURL delegate:(NSObject<HTTPFileSaverDelegate> *)delegate;

-(id)initWithHTTPPath:(NSString *)HTTPPath localPath:(NSString *)localPath;
-(id)initWithHTTPPath:(NSString *)HTTPPath localPath:(NSString *)localPath delegate:(NSObject<HTTPFileSaverDelegate> *)delegate;

-(id)initWithHTTPPath:(NSString *)HTTPPath documentsPath:(NSString *)documentsPath;
-(id)initWithHTTPPath:(NSString *)HTTPPath documentsPath:(NSString *)documentsPath delegate:(NSObject<HTTPFileSaverDelegate> *)delegate;

@property (nonatomic, strong) NSURL *HTTPURL;
@property (nonatomic, strong) NSURL *localURL;
-(void)setDocumentsPath:(NSString *)documentsPath; //localURL = ~mobile/Applicaitons/APP-FOLDER/Documents/XXX

@property (nonatomic, readonly) int actualSize; //# of bytes downloaded so far
@property (nonatomic, readonly) int expectedSize; //this will be 0 if the download has not been attempted at all
@property (nonatomic, readonly) BOOL downloading;
@property (nonatomic, readonly) BOOL downloaded;

@property (nonatomic) NSObject<HTTPFileSaverDelegate> *delegate;

-(BOOL)start;
-(BOOL)cancel;
-(BOOL)deleteLocalFile;

@end
