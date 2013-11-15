HTTPAudioPlayer
========

My implementation of an Audio streamer/player over HTTP. Uses AVFoundation's AVAudioPlayer and my own simple HTTPFileSaver to accomplish this.

It basically is an AVPlayer with a couple of nifty features, including: 

* The ability to download the data before you play it
* Saving the file to disk instead of keeping it in memory
* Delegate methods for buffering
* When the internet connection dies, it resumes the download when you get it again
* Ability to set headers/cookies for files that require authorization

# How to use

```objc
//initialize the player
NSURL *httpURL = [NSURL URLWithString:@"http://example.com/somefile.mp3"];
HTTPAudioPlayer *player = [[HTTPAudioPlayer alloc] initWithURL:httpURL];
player.delegate = someDelegate;

//set the URL to save it to in a few ways
NSURL *someURL;
player.fileSaver.localURL = someURL;
player.fileSaver.documentsPath = @"test.mp3"; //localURL = ~mobile/Applicaitons/APP-FOLDER/Documents/XXX

//download and play!
[player download];
[player play];

//use these to pause and stop
[player pause];
[player stop];

//otherwise go ahead and call them on the AVAudioPlayer itself
player.audioPlayer.volume = 0.5;

```

You can also download a multitude of streams and stitch them together:

```objc
player.HTTPURLs = @[
    @"http://blah.com/blah1.mp3",
    @"http://blah.com/blah2.mp3"
];
```
You can also set some attributes, like the beginnings and ends to shave off:
```objc
player.HTTPURLs = @[
    @{
        @"url": @"http://blah.com/1.mp3",
        @"start": @1000 // in bytes
    }, 
    @{
        @"url": @"http://blah.com/2.mp3",
        @"start": @2000,
        @"end": @1000000
    },
    @"http://blah.com/3.mp3"
];
```
Setting headers/method/cookies/etc
```objc
player.properties = @{
    @"headers": @{
        @"Authorization": @"GoogleLogin auth=blah blah"
    },
    @"cookies": @{
        @"Cookie1": @"some value"
    },
    @"method": @"POST",
    @"params": @{
        @"param1": @"some value",
        @"param2": @"some other value",
    }
};
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
HTTPAudioPlayer *player;

if(secondsSinceLastPacketRecieved > 20 && player.fileSaver.downloading)
{
    //cancels download and deletes local file
    [player.fileSaver deleteLocalFile];
}

```

There's other stuff you can do, too. Take a look at the header files.

# License

This uses an MIT license. You can read it at the stop of the source code of any of the files.

# What this is compatible with

The only thing I've tested this on is on a jailbroken iOS 6.0 using the iOS 7.0 SDK (built for iOS5+). So it should be compatible with iOS 5+.

Also, I'm like 99% sure this won't work on simulator. Only on the device.
