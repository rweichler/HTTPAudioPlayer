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
#import <AVFoundation/AVFoundation.h>

#define HTTPAUDIOPLAYER_BUFFER_TIME 5 //start buffering if there is less than these many seconds downloaded past

@class HTTPAudioPlayer;
@protocol HTTPAudioPlayerDelegate <NSObject>

-(void)audioPlayerDidStartBuffering:(HTTPAudioPlayer *)audioPlayer;
-(BOOL)audioPlayerDidFinishBuffering:(HTTPAudioPlayer *)audioPlayer; //return true to continue playing, return false to not, if not implemented will assume true
-(void)audioPlayerDidFinishPlaying:(HTTPAudioPlayer *)audioPlayer;
-(void)audioPlayerFailedToPlay:(HTTPAudioPlayer *)audioPlayer;

//related to file download
-(void)audioPlayerDidFinishDownloading:(HTTPAudioPlayer *)audioPlayer;
-(void)audioPlayerDownloadFailed:(HTTPAudioPlayer *)audioPlayer;

@end

@interface HTTPAudioPlayer : NSObject<HTTPFileSaverDelegate, AVAudioPlayerDelegate>

-(id)initWithURL:(NSURL *)URL;
-(id)initWithURLs:(NSArray *)URLs;

@property (nonatomic, strong) HTTPFileSaver *fileSaver;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@property (nonatomic, readonly) BOOL buffering;
@property (nonatomic, readonly) BOOL canPlay;

@property (nonatomic) id<HTTPAudioPlayerDelegate> delegate;

//audio player stuff
@property (nonatomic) NSTimeInterval currentTime;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval availableDuration; //duration of currently available data
@property (nonatomic, readonly, getter = isPlaying) BOOL playing;


-(void)play;
-(void)pause;
-(void)stop;

//HTTP file saver stuff


-(BOOL)download;

@end
