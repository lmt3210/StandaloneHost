// 
// LTMidiPlayer.h
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

#import <Foundation/Foundation.h>

#include <os/log.h>

#define kDefaultTempo          120
#define kDefaultTimeSignature  4

@interface LTMidiPlayer : NSObject
{
    MusicPlayer mMusicPlayer;
    MusicSequence mMusicSequence;
    UInt32 mTempo;
    UInt32 mTimeSignature;

    // For logging
    os_log_t mLog;
}

- (void)play;
- (void)pause;
- (void)stop;
- (BOOL)isPlaying;
- (UInt32)tempo;
- (UInt32)timeSignature;
- (void)loadMidiData:(NSString *)fileName;
- (void)setSeqOutput:(MIDIEndpointRef)MIDIDestination withGraph:(AUGraph)graph;

@end
