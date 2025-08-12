//
// SynthWindowController.h
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

#import <Cocoa/Cocoa.h>

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import "CAComponent.h"

#import "LTMidi.h"
#import "LTMidiCallbacks.h"
#import "LTAUGraph.h"
#import "LTSynthWindow.h"
#import "LTLog.h"

#define kNoneDevice  999

typedef enum
{
    SYNTH_STATUS_FOUND,
    SYNTH_STATUS_NOT_SUPPORTED,
    SYNTH_STATUS_UNKNOWN
} synthStatus;


@interface SynthWindowController : NSWindowController
{
    // AU information
    NSString *mAUName;
    NSString *mDisplayName;
    OSType mAUMfg;
    OSType mAUType;
    OSType mAUSubtype;

    // For AU window
    LTSynthWindow *mSynthWindow;

    // For AU graph
    LTAUGraph *mAUGraph;
    AudioUnit mSynthUnit;
    AudioUnit mOutputUnit;

    // MIDI
    MIDIClientRef mMIDIClient;
    MIDIPortRef mMIDIInPort;
    MIDIPortRef mMIDIOutPort;
    MIDIEndpointRef mMIDISource;
    MIDIEndpointRef mMIDIDestination;
    NSTimer *mMIDITimer;
    struct LTMIDIControl mMIDIControl;
    
    // For changing settings
    NSNumber *mMIDIInputIndex;
    NSNumber *mMIDIOutputIndex;
    NSNumber *mChannelIndex;
    NSMutableString *mAudioDeviceName;
    NSMutableString *mAudioSampleRateName;
    NSNumber *mMIDIChannel;
    NSNumber *mLowKey;
    NSNumber *mHighKey;
    NSNumber *mTranspose;
    NSNumber *mTempo;

    // Audio devices
    NSMutableDictionary *mAudioDeviceIDs;
    NSMutableDictionary *mAudioDeviceChannelCounts;
    
    // Sample rate
    Float64 mSampleRate;
    
    // MIDI capture
    int mLastRecordCount;
    NSTimer *mRecordTimer;
    
    // Callback data
    struct LTCallbackData mCallbackData;
    
    // For logging
    os_log_t mLog;
    NSString *mLogFile;
}

- (synthStatus)loadSynth:(NSString *)appName;
- (void)cleanup;

@end
