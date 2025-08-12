//
// SequencerWindowController.mm
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

// Import this first to avoid 'DebugAssert is deprecated' warnings
#import <AssertMacros.h>

#import <sys/types.h>
#import <pwd.h>
#import <uuid/uuid.h>
#import <sys/utsname.h>

#import <CoreAudio/CoreAudio.h>
#import <CoreAudioKit/CoreAudioKit.h>
#import <AudioUnit/AUCocoaUIView.h>

#import <CoreMIDI/CoreMIDI.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "CAComponent.h"
#import "CAComponentDescription.h"
#import "CAStreamBasicDescription.h"

#import "SequencerWindowController.h"
#import "NSFileManager+DirectoryLocations.h"

@implementation SequencerWindowController

- (void)cleanup
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Stop playback
    if (mPlaying == true)
    {
        [mMIDIPlayer stop];
    }

    // Stop timer
    if (mSequenceTimer)
    {
        [mSequenceTimer invalidate];
        mSequenceTimer = nil;
    }
}

- (NSURL *)getSequenceURL
{
    // Create and configure the file open dialog
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:NO];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setDirectoryURL:[NSURL URLWithString:mSequenceStartDir]];
    
    // Display the dialog, and if the OK button was pressed, process the file
    NSURL *fileURL = [[NSURL alloc] initWithString:@""];
    
    if ([openDlg runModal] == NSModalResponseOK)
    {
        fileURL = [[openDlg URLs] objectAtIndex:0];
        
        // Save path where we ended up for next time
        mSequenceStartDir = (NSMutableString *)[[fileURL path]
                            stringByDeletingLastPathComponent];
    }
   
    return fileURL;
}

- (IBAction)iaLoadSequenceButtonPressed:(id)sender
{
    mSequenceFileURL = [self getSequenceURL];

    if ([mSequenceFileURL isEqual:@""] == NO)
    {
        [self setSequence];
    }
}

- (void)setSequence
{
    if (mSequenceTimer)
    {
        [mSequenceTimer invalidate];
        mSequenceTimer = nil;
    }
    
    mPlaying = false;
    [uiPlayButton setTitle:@"Play"];
    
    [mMIDIPlayer loadMidiData:[mSequenceFileURL path]];
    [mMIDIPlayer setSeqOutput:(MIDIEndpointRef)0 withGraph:mGraph];
       
    [mMIDIPlayer stop];
    
    [uiSequenceName setStringValue:[mSequenceFileURL lastPathComponent]];
    [uiMeasureCounter setStringValue:@"001:01"];
    mBeatCounter = 0;

    mSequenceTimer = [NSTimer scheduledTimerWithTimeInterval:
                      (60.0 / [mMIDIPlayer tempo])
                      target:self selector:@selector(beatCounter:)
                      userInfo:nil repeats:YES];
}

- (IBAction)iaPlayButtonPressed:(id)sender
{
    if (mPlaying == true)
    {
        [mMIDIPlayer pause];
        mPlaying = false;
        [uiPlayButton setTitle:@"Play"];
    }
    else
    {
        [mMIDIPlayer play];
        mPlaying = true;
        [uiPlayButton setTitle:@"Pause"];
    }
}

- (IBAction)iaStopButtonPressed:(id)sender
{
    [mMIDIPlayer stop];
    mPlaying = false;
    [uiPlayButton setTitle:@"Play"];
    [uiMeasureCounter setStringValue:@"001:01"];
    mBeatCounter = 0;
}

- (void)beatCounter:(NSTimer *)timer
{
    if (mPlaying == true)
    {
        ++mBeatCounter;
        UInt32 measureCounter = (mBeatCounter /
                                [mMIDIPlayer timeSignature]) + 1;
        NSString *string = [NSString stringWithFormat:@"%03i:%02i",
                            measureCounter,
                            (mBeatCounter % [mMIDIPlayer timeSignature]) + 1];
        [uiMeasureCounter setStringValue:string];
    }
}

- (void)awakeFromNib
{
}

- (void)initSMFPlayback
{
    // Set up logging
    mLog = os_log_create("com.larrymtaylor.SynthHost", "synth");
    NSString *path =
        [[NSFileManager defaultManager] applicationSupportDirectory];
    mLogFile = [[NSString alloc] initWithFormat:@"%@/logFile.txt", path];

    mMIDIPlayer = [[LTMidiPlayer alloc] init];

    [uiPlayButton setTitle:@"Play"];
    [uiMeasureCounter setStringValue:@"001:01"];
    mPlaying = false;
    mSequenceTimer = nil;
    
    // Set up the sequence starting directory
    struct passwd *pw = getpwuid(getuid());
    NSString *realHomeDir = [NSString stringWithUTF8String:pw->pw_dir];
    mSequenceStartDir = [[NSMutableString alloc] initWithString:realHomeDir];
    [mSequenceStartDir appendString:@"/Music"];
    mSequenceFileURL = [[NSURL alloc] initWithString:@""];
     
    // Watch for window close
    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(windowWillClose:)
      name:NSWindowWillCloseNotification object:[self window]];
    
    // Watch for graph handle notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(receiveGraphNotification:)
        name:@"LTGraphNotification" object:nil];
}

- (void)receiveGraphNotification:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:@"LTGraphNotification"] == YES)
    {
        NSDictionary *userInfo = notification.userInfo;
        NSNumber *graphHandle = userInfo[@"mGraph"];
        mGraph = (AUGraph)[graphHandle integerValue];
    }
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self.window setBackgroundColor:[NSColor colorWithRed:0.2
                                     green:0.2 blue:0.2 alpha:1.0]];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [self cleanup];
}

- (void)show
{
    [self.window center];
    [self.window makeKeyAndOrderFront:self];
}

@end
