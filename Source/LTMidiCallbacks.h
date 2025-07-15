//
// LTMidiCallbacks.h
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

// Import this first to avoid 'DebugAssert' is deprecated warnings
#import <AssertMacros.h>

#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import "CAComponent.h"

#import "LTMidi.h"
#import "LTLog.h"

#define kMaxRecordEvents  (1024 * 100)
#define kMaxPlayEvents    256

// This constant is to avoid issues with Apple's woke madness
// replacing kAudioObjectPropertyElementMaster with
// kAudioObjectPropertyElementMain
#define kAudioObjectPropertyElementMasterx  0

struct LTMIDIControl
{
    os_log_t log;
    AudioUnit synthUnit;
    int channel;
    int low;
    int high;
    int transpose;
    Byte status;
    OSStatus err;
    MIDIPortRef outPort;
    MIDIEndpointRef destination;
    int recordEnable;
    int recordCount;
    struct LTMidiEvent recordData[kMaxRecordEvents];
    int playHead;
    int playTail;
    struct LTMidiEvent playData[kMaxPlayEvents];
};

struct LTCallbackData
{
    os_log_t log;
    Float64 tempo;
    Float64 beat;
};

void midiNotifyProc(const MIDINotification *message, void *refCon);
OSStatus getBeatAndTempo(void *userData, Float64 *outBeat, Float64 *outTempo);
OSStatus renderNotifyProc(void *inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *inTimeStamp,
                          UInt32 inBusNumber, UInt32 inNumberFrames,
                          AudioBufferList *ioData);
void midiReadProc(const MIDIPacketList *inPktList, void *refCon,
                  void *connRefCon);
OSStatus midiOutputProc(void *userData, const AudioTimeStamp *timeStamp,
                        UInt32 midiOutNum,
                        const struct MIDIPacketList *inPktList);

