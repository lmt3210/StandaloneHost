//
// SettingsWindowController.h
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

#import "LTLog.h"
#import "SynthWindowController.h"


// This constant is to avoid issues with Apple's woke madness
// replacing kAudioObjectPropertyElementMaster with
// kAudioObjectPropertyElementMain
#define kAudioObjectPropertyElementMasterx  0

@interface SettingsWindowController : NSWindowController
{
    // IB: MIDI input, MIDI output, and audio output
    IBOutlet NSPopUpButton *uiMIDIInputPopUpButton;
    IBOutlet NSPopUpButton *uiMIDIOutputPopUpButton;
    IBOutlet NSPopUpButton *uiAudioDevicePopUpButton;
    IBOutlet NSPopUpButton *uiAudioChannelPopUpButton;
    IBOutlet NSPopUpButton *uiAudioSampleRatePopUpButton;
    
    // IB: Channel, key range, and transpose fields
    IBOutlet NSTextField *uiChannelInput;
    IBOutlet NSTextField *uiLowKeyInput;
    IBOutlet NSTextField *uiHighKeyInput;
    IBOutlet NSTextField *uiTransposeInput;
    IBOutlet NSTextField *uiTempoInput;
    
    // IB: Record button
    IBOutlet NSButtonCell *uiRecordCheckBox;
    
    // For saving and restoring
    NSMutableString *mMIDIInputName;
    NSMutableString *mMIDIOutputName;
    NSMutableString *mAudioDeviceName;
    NSMutableString *mAudioChannelName;
    NSMutableString *mAudioSampleRateName;
    NSNumber *mMIDIChannel;
    NSNumber *mLowKey;
    NSNumber *mHighKey;
    NSNumber *mTranspose;
    NSNumber *mTempo;
    
    // Audio devices
    NSMutableDictionary *mAudioDeviceIDs;
    NSMutableDictionary *mAudioDeviceChannelCounts;
    
    // Device indices
    NSNumber *mMIDIInputIndex;
    NSNumber *mMIDIOutputIndex;
    NSNumber *mChannelIndex;

    // Synth name
    NSString *mAppName;
    
    // For logging
    os_log_t mLog;
    NSString *mLogFile;
}

- (void)cleanup;
- (void)initSettings:(NSString *)appName;
- (void)sendSettings;

- (IBAction)iaMIDIInputPopUpButtonPressed:(id)sender;
- (IBAction)iaMIDIOutputPopUpButtonPressed:(id)sender;
- (IBAction)iaAudioDevicePopUpButtonPressed:(id)sender;
- (IBAction)iaAudioChannelPopUpButtonPressed:(id)sender;
- (IBAction)iaAudioSampleRatePopUpButtonPressed:(id)sender;
- (IBAction)iaRecordCheckBox:(id)sender;

@end
