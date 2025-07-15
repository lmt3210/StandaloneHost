//
// SequencerWindowController.h
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
#import "LTMidiPlayer.h"
#import "LTLog.h"

@interface SequencerWindowController : NSWindowController
{
    // IB: Sequence buttons and text
    IBOutlet NSButton *uiLoadSequenceButton;
    IBOutlet NSButton *uiPlayButton;
    IBOutlet NSButton *uiStopButton;
    IBOutlet NSTextField *uiSequenceName;
    IBOutlet NSTextField *uiMeasureCounter;
    
    // MIDI player
    AUGraph mGraph;
    NSMutableString *mSequenceStartDir;
    NSURL *mSequenceFileURL;
    LTMidiPlayer *mMIDIPlayer;
    NSTimer *mSequenceTimer;
    BOOL mPlaying;
    UInt32 mBeatCounter;
    
    // For logging
    os_log_t mLog;
    NSString *mLogFile;
}

- (void)cleanup;
- (void)initSMFPlayback;
- (void)show;

- (IBAction)iaLoadSequenceButtonPressed:(id)sender;
- (IBAction)iaPlayButtonPressed:(id)sender;
- (IBAction)iaStopButtonPressed:(id)sender;

@end
