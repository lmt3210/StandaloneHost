// 
// LTMidiPlayer.m
//
// Copyright (c) 2020-2025 Larry M. Taylor
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software. Permission is granted to anyone to
// use this software for any purpose, including commercial applications, and to
// to alter it and redistribute it freely, subject to 
// the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source
//    distribution.
//

#import <CoreMidi/CoreMidi.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "LTMidiPlayer.h"
#import "LTLog.h"


@implementation LTMidiPlayer

- (instancetype)init
{
    if ((self = [super init]))
    {
        // Create a log object
        mLog = os_log_create("com.larrymtaylor.LTMidiPlayer", "");
    }
    
    return self;
}

- (void)play
{
    if (mMusicPlayer)
    {
        OSStatus err = MusicPlayerStart(mMusicPlayer);
        
        if (err != noErr)
        {
            LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
                  @"MusicPlayerStart error = %i (%@)", err,
                  statusToString(err));
        }
    }
}

- (void)pause
{
    if (mMusicPlayer)
    {
        OSStatus err = MusicPlayerStop(mMusicPlayer);
    
        if (err != noErr)
        {
            LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR, 
                  @"MusicPlayerStop error = %i (%@)",
                  err, statusToString(err));
        }
    }
}

- (void)stop
{
    if (mMusicPlayer)
    {
        OSStatus err = MusicPlayerStop(mMusicPlayer);
    
        if (err != noErr)
        {
            LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
                  @"MusicPlayerStop error = %i (%@)", err,
                  statusToString(err));
        }
        
        err = MusicPlayerSetTime(mMusicPlayer, 0);
        
        if (err != noErr)
        {
            LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
                  @"MusicPlayerSetTime error = %i (%@)", err,
                  statusToString(err));
        }
    }
}

- (BOOL)isPlaying
{
    if (mMusicPlayer)
    {
        Boolean isRunning;
        MusicPlayerIsPlaying(mMusicPlayer, &isRunning);
        return isRunning;
    }

    return NO;
}

- (UInt32)tempo
{
    return mTempo;
}

- (UInt32)timeSignature
{
    return mTimeSignature;
}

- (void)loadMidiData:(NSString *)fileName
{
    [self stop];
    
    if (mMusicPlayer)
    {
        DisposeMusicPlayer(mMusicPlayer);
    }

    if (mMusicSequence)
    {
        DisposeMusicSequence(mMusicSequence);
    }
    
    OSStatus err = NewMusicPlayer(&mMusicPlayer);
    
    if (err != noErr)
    {
        LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
              @"NewMusicPlayer error = %i (%@)", err, statusToString(err));
    }
    
    err = NewMusicSequence(&mMusicSequence);
    
    if (err != noErr)
    {
        LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
              @"NewMusicSequence error = %i (%@)", err, statusToString(err));
    }
    
    NSData *data = [NSData dataWithContentsOfFile:fileName];
    
    err = MusicSequenceFileLoadData(mMusicSequence, (__bridge CFDataRef)data,
                                    kMusicSequenceFile_MIDIType,
                                    kMusicSequenceLoadSMF_PreserveTracks);
    
    if (err != noErr)
    {
        LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
              @"MusicSequenceFileLoadData error = %i (%@)", err,
              statusToString(err));
    }
    
    err = MusicPlayerSetSequence(mMusicPlayer, mMusicSequence);
    
    if (err != noErr)
    {
        LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
              @"MusicPlayerSetSequence error = %i (%@)", err,
              statusToString(err));
    }
    
    NSDictionary *dict =
        (NSDictionary *)MusicSequenceGetInfoDictionary(mMusicSequence);

    if (dict[@kAFInfoDictionary_Tempo])
    {
        mTempo = [dict[@kAFInfoDictionary_Tempo] intValue];
    }
    else
    {
        mTempo = kDefaultTempo;
    }

    if (dict[@kAFInfoDictionary_TimeSignature])
    {
        mTimeSignature = [dict[@kAFInfoDictionary_TimeSignature] intValue];
    }
    else
    {
        mTimeSignature = kDefaultTimeSignature;
    }

    err = MusicPlayerPreroll(mMusicPlayer);
    
    if (err != noErr)
    {
        LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
              @"MusicPlayerPreroll error = %i (%@)", err, statusToString(err));
    }
}

- (void)setSeqOutput:(MIDIEndpointRef)MIDIDestination withGraph:(AUGraph)graph
{
    BOOL wasPlaying = NO;
    OSStatus err = statusErr;
    
    if ([self isPlaying] == YES)
    {
        [self pause];
        wasPlaying = YES;
    }
    
    if (mMusicSequence != NULL)
    {
        if (MIDIDestination != (MIDIEndpointRef)0)
        {
            err = MusicSequenceSetMIDIEndpoint(mMusicSequence,
                                               MIDIDestination);
            
            if (err != noErr)
            {
                LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
                      @"MusicSequenceSetSetMIDIEndpoint "
                      "error = %i (%@)", err, statusToString(err));
            }
        }
        
        if (graph != NULL)
        {
            err = MusicSequenceSetAUGraph(mMusicSequence, graph);
        
            if (err != noErr)
            {
                LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
                      @"MusicSequenceSetAUGraph error = %i (%@)",
                      err, statusToString(err));
            }
        }
    }
    
    if (wasPlaying == YES)
    {
        [self play];
    }
}

@end
