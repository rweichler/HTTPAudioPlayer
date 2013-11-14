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

#import "HTTPAudioPlayer.h"

@interface HTTPAudioPlayer()
{
    BOOL _justStartedDownload;
    
    NSTimer *_bufferTimer;
    
    BOOL _songEndedStillBuffering;
    NSTimeInterval _lastCurrentTime;
    
    BOOL _stopped;
    
    BOOL _alreadyStopped;
    
#ifdef TARGET_OS_IPHONE
    int _backgroundTask;
#endif
}
-(void)startBufferTimer;
-(void)stopBufferTimer;
-(void)bufferTimerCheck:(NSTimer *)bufferTimer;


@end

@implementation HTTPAudioPlayer
@synthesize fileSaver=_fileSaver, audioPlayer=_audioPlayer, buffering=_buffering;

-(id)initWithURL:(NSURL *)URL
{
    if(self == [super init])
    {
        _fileSaver = [[HTTPFileSaver alloc] initWithHTTPURL:URL localURL:nil delegate:self];
#ifdef TARGET_OS_IPHONE
        _backgroundTask = -1;
#endif
    }
    return self;
}

-(id)initWithURLs:(NSArray *)URLs
{
    if(self == [super init])
    {
        _fileSaver = [[HTTPFileSaver alloc] initWithHTTPURLs:URLs localURL:nil delegate:self];
#ifdef TARGET_OS_IPHONE
        _backgroundTask = -1;
#endif
    }
    return self;
}

-(void)fileSaverGotData:(HTTPFileSaver *)saver
{
    if((_justStartedDownload || _audioPlayer == nil) && (saver.actualSize > 80000 || saver.downloaded))
    {
        //NSLog(@"actualSize: %d", saver.actualSize);
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_fileSaver.localURL error:nil];
        _audioPlayer.delegate = self;
        [_audioPlayer prepareToPlay];
        
        
        _justStartedDownload = false;
    }
    
    if(_buffering && self.canPlay)
    {
        BOOL shouldPlay = true;
        
        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDidFinishBuffering:)])
        {
            shouldPlay = [self.delegate audioPlayerDidFinishBuffering:self];
        }
        
        if(shouldPlay)
        {
            [self startBufferTimer];
            [_audioPlayer play];
        }
        
        [self stopBuffering];
    }
    
    
    if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerGotData:)])
    {
        [self.delegate audioPlayerGotData:self];
    }
    
    /*
    //test filesaver failure
    if(saver.actualSize > 1000000 && !_alreadyStopped)
    {
        _alreadyStopped = true;
        [self.fileSaver connection:nil didFailWithError:nil];
    }
    //*/
    
}
-(void)setProperties:(NSDictionary *)properties
{
    self.fileSaver.properties = properties;
}

-(void)fileSaverFailed:(HTTPFileSaver *)saver
{
    if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDownloadFailed:)])
    {
        [self.delegate audioPlayerDownloadFailed:self];
    }
}

-(void)fileSaverCompleted:(HTTPFileSaver *)saver
{
    NSLog(@"file saver completed");
    _justStartedDownload = false;
    if(_audioPlayer == nil)
    {
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_fileSaver.localURL error:nil];
        _audioPlayer.delegate = self;
        _stopped = true;
    }
    if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDidFinishDownloading:)])
    {
        [self.delegate audioPlayerDidFinishDownloading:self];
    }
}

-(BOOL)canPlay
{
    NSTimeInterval currentTime;
    if(_songEndedStillBuffering)
        currentTime = _lastCurrentTime;
    else
        currentTime = self.currentTime;
    
    //can only play if there's HTTPAUDIOPLAYER_BUFFER_TIME seconds of audio available or if finished downloading
    return !_justStartedDownload && _fileSaver.expectedSize != 0 && _audioPlayer != nil && (_fileSaver.downloaded || self.availableDuration - currentTime > HTTPAUDIOPLAYER_BUFFER_TIME);
}

-(BOOL)download
{
    if(_justStartedDownload || _fileSaver.downloaded || _fileSaver.downloading) return false;
    
    BOOL success = [_fileSaver start];

    if(success) _justStartedDownload = true;
    
    return success;
}

-(void)play
{
    if(_audioPlayer.playing) return;
    NSLog(@"play: %d, %d, %d, %d, %d, %d.", self.canPlay, _justStartedDownload, _fileSaver.expectedSize, _audioPlayer == nil, _fileSaver.downloaded, self.availableDuration - self.currentTime > HTTPAUDIOPLAYER_BUFFER_TIME);
    if(self.canPlay)
    {
        if(_stopped)
        {
            if(_fileSaver.downloaded)
            {
                [_audioPlayer prepareToPlay];
            }
            else if(_fileSaver.downloading)
            {
                NSLog(@"still downloading, should work.");
            }
            else
            {
                NSLog(@"stopped download, shouldnt work");
            }
            _stopped = false;
        }
        [self stopBuffering];
        BOOL success = [_audioPlayer play];
        if(!success)
        {
            [self audioPlayerDecodeErrorDidOccur:_audioPlayer error:nil];
        }
    }
    else
    {
        NSLog(@"Can't Play");
        [self startBuffering];
        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDidStartBuffering:)])
        {
            [self.delegate audioPlayerDidStartBuffering:self];
        }
    }
}

-(void)startBuffering
{
    if(_buffering) return;
    _buffering = true;
#ifdef TARGET_OS_IPHONE
    if(_backgroundTask != -1)
    {
        NSLog(@"Something went horribly wrong.");
    }
    _backgroundTask = [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{
        [UIApplication.sharedApplication endBackgroundTask:_backgroundTask];
        _backgroundTask = -1;
    }];
#endif
}

-(void)stopBuffering
{
    if(!_buffering) return;
    _buffering = false;
#ifdef TARGET_OS_IPHONE
    if(_backgroundTask != -1)
    {
        [UIApplication.sharedApplication endBackgroundTask:_backgroundTask];
        _backgroundTask = -1;
    }
    else
    {
        NSLog(@"Oh my god, something went horribly wrong.");
    }
#endif
}

-(void)pause
{
    [_audioPlayer pause];
}

#pragma mark audio player stuff

-(NSTimeInterval)currentTime{return _audioPlayer.currentTime;}
-(void)setCurrentTime:(NSTimeInterval)currentTime{_audioPlayer.currentTime=currentTime;}
-(NSTimeInterval)duration{return _audioPlayer.duration;}

-(NSTimeInterval)availableDuration
{
    if(_fileSaver.expectedSize == 0) return 0;
    
    return self.duration*_fileSaver.actualSize/_fileSaver.expectedSize;
}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if(!_fileSaver.downloaded)
    {
        NSLog(@"Ended and song isn't downloaded");
        [self startBuffering];
        _songEndedStillBuffering = true;
        _lastCurrentTime = player.currentTime;
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_fileSaver.localURL error:nil];
        _audioPlayer.delegate = self;
        [_audioPlayer prepareToPlay];
        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDidStartBuffering:)])
        {
            [self.delegate audioPlayerDidStartBuffering:self];
        }
    }
    else
    {
        [self stopBuffering];
        [self stopBufferTimer];
        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDidFinishPlaying:)])
        {
            [self.delegate audioPlayerDidFinishPlaying:self];
        }
    }
}

-(void)fileSaver:(HTTPFileSaver *)saver failedWithStatusCode:(int)statusCode
{
    if([self.delegate respondsToSelector:@selector(audioPlayer:failedWithStatusCode:)])
    {
        [self.delegate audioPlayer:self failedWithStatusCode:statusCode];
    }
}

-(void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerFailedToPlay:)])
    {
        [self.delegate audioPlayerFailedToPlay:self];
    }
}

-(BOOL)isPlaying
{
    return _audioPlayer.playing;
}

-(void)fileSaverCancelled:(HTTPFileSaver *)saver
{
    _justStartedDownload = false;
}

-(void)stop
{
    [_fileSaver cancel];
    [_audioPlayer stop];
    _stopped = true;
    [self stopBuffering];
    _audioPlayer.currentTime = 0;
}

#pragma mark buffer timer stuff

-(void)startBufferTimer
{
    [self stopBufferTimer];
    _bufferTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(bufferTimerCheck:) userInfo:nil repeats:true];
}

-(void)stopBufferTimer
{
    [_bufferTimer invalidate];
    _bufferTimer = nil;
}

-(void)bufferTimerCheck:(NSTimer *)bufferTimer
{
    //pause and alert delegate of buffer if there isn't enough time
    if(!_buffering && _audioPlayer.playing && !self.canPlay)
    {
        [_audioPlayer pause];
        [self startBuffering];
        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDidStartBuffering:)])
        {
            [self.delegate audioPlayerDidStartBuffering:self];
        }
    }
    else if(_buffering && _songEndedStillBuffering && self.canPlay)
    {
        _songEndedStillBuffering = false;
        _audioPlayer.currentTime = _lastCurrentTime;
        [self stopBuffering];
        [_audioPlayer play];
    }
    
}

@end
