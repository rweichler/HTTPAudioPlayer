HTTPAudioStreamer
========

My implementation of an Audio Streamer over HTTP. Uses AVFoundation's AVAudioPlayer and my own simple HTTPFileSaver to accomplish this.

# How to use

```objc
//initialize the streamer
NSURL *httpURL = [NSURL URLWithString:@"http://example.com/somefile.mp3"];
HTTPAudioStreamer *streamer = [[HTTPAudioStreamer alloc] initWithURL:httpURL];
streamer.delegate = someDelegate;

//set the URL to save it to in a few ways
NSURL *someURL;
streamer.fileSaver.localURL = someURL;
streamer.fileSaver.documentsPath = @"test.mp3"; //localURL = ~mobile/Applicaitons/APP-FOLDER/Documents/XXX

//download and play!
[streamer download];
[streamer play];

//use these to pause and stop
[streamer pause];
[streamer stop];

//otherwise go ahead and call them on the AVAudioPlayer itself
streamer.audioPlayer.volume = 0.5;

```

## Delegate methods

```objc
-(void)audioPlayerDidStartBuffering:(HTTPAudioPlayer *)audioPlayer;
-(BOOL)audioPlayerDidFinishBuffering:(HTTPAudioPlayer *)audioPlayer; //return true to continue playing, return false to not, if not implemented will assume true
-(void)audioPlayerDidFinishPlaying:(HTTPAudioPlayer *)audioPlayer;
-(void)audioPlayerFailedToPlay:(HTTPAudioPlayer *)audioPlayer;

-(void)audioPlayerDidFinishDownloading:(HTTPAudioPlayer *)audioPlayer;
-(void)audioPlayerDownloadFailed:(HTTPAudioPlayer *)audioPlayer;

```

## HTTPFileSaver

You can also use methods on HTTPAudioPlayer's HTTPFileSaver to manipulate the download. For example:

```objc
HTTPAudioStreamer *streamer;

if(secondsSinceLastPacketRecieved > 20 && streamer.fileSaver.downloading)
{
    //cancels download and deletes local file
    [streamer.fileSaver deleteLocalFile];
}

```

There's other stuff you can do, too. Take a look at the header files.

# License

This uses an MIT license. You can read it at the stop of the source code of any of the files.
