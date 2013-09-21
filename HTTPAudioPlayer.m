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
    }
    return self;
}

-(void)fileSaverGotData:(HTTPFileSaver *)saver
{
    if((_justStartedDownload || _audioPlayer == nil) && saver.actualSize > 50000)
    {
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
        
        _buffering = false;
    }
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
    if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDidFinishDownloading:)])
    {
        [self.delegate audioPlayerDidFinishDownloading:self];
    }
}

-(BOOL)canPlay
{
    //can only play if there's HTTPAUDIOPLAYER_BUFFER_TIME seconds of audio available or if finished downloading
    return !_justStartedDownload && _fileSaver.expectedSize != 0 && _audioPlayer != nil && (_fileSaver.downloaded || self.availableDuration - self.currentTime > HTTPAUDIOPLAYER_BUFFER_TIME);
}

-(BOOL)download
{
    if(_justStartedDownload) return false;
    
    BOOL success = [_fileSaver start];
    
    if(success) _justStartedDownload = true;
    
    return success;
}

-(void)play
{
    if(self.canPlay && !_audioPlayer.playing)
    {
        _buffering = false;
        BOOL success = [_audioPlayer play];
        if(!success)
        {
            [self audioPlayerDecodeErrorDidOccur:_audioPlayer error:nil];
        }
    }
    else
    {
        _buffering = true;
        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDidStartBuffering:)])
        {
            [self.delegate audioPlayerDidStartBuffering:self];
        }
    }
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
    _buffering = false;
    [self stopBufferTimer];
    if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDidFinishPlaying:)])
    {
        [self.delegate audioPlayerDidFinishPlaying:self];
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

-(void)stop
{
    [_audioPlayer stop];
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
        _buffering = true;
        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(audioPlayerDidStartBuffering:)])
        {
            [self.delegate audioPlayerDidStartBuffering:self];
        }
    }
    
}

@end
