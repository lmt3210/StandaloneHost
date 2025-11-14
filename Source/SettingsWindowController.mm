//
// SettingsWindowController.mm
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

#import <sys/types.h>
#import <pwd.h>
#import <uuid/uuid.h>

#import <CoreAudio/CoreAudio.h>
#import <CoreAudioKit/CoreAudioKit.h>
#import <AudioUnit/AUCocoaUIView.h>

#import <CoreMIDI/CoreMIDI.h>
#import <AudioToolbox/MusicDevice.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "CAComponent.h"
#import "CAComponentDescription.h"
#import "CAStreamBasicDescription.h"

#import "SettingsWindowController.h"
#import "SynthWindowController.h"
#import "NSFileManager+DirectoryLocations.h"

@implementation SettingsWindowController

- (void)synchronizeForNewMIDIInputs
{
    [uiMIDIInputPopUpButton removeAllItems];
    [uiMIDIInputPopUpButton addItemWithTitle:@"None"];
    
    ItemCount sourceCount = MIDIGetNumberOfSources();
    
    for (ItemCount i = 0 ; i < sourceCount; ++i)
    {
        MIDIEndpointRef source = MIDIGetSource(i);
        
        if (source != (MIDIEndpointRef)0)
        {
            CFStringRef name = nil;
            OSStatus err = MIDIObjectGetStringProperty(source,
                               kMIDIPropertyDisplayName, &name);
            
            if (err == (OSStatus)noErr)
            {
                [uiMIDIInputPopUpButton
                 addItemWithTitle:(__bridge NSString *)name];
            }
        }
    }

    [self validateMIDIInput];
}

- (void)synchronizeForNewMIDIOutputs
{
    [uiMIDIOutputPopUpButton removeAllItems];
    [uiMIDIOutputPopUpButton addItemWithTitle:@"None"];
    
    ItemCount destCount = MIDIGetNumberOfDestinations();
    
    for (ItemCount i = 0 ; i < destCount; ++i)
    {
        MIDIEndpointRef source = MIDIGetDestination(i);
        
        if (source != (MIDIEndpointRef)0)
        {
            CFStringRef name = nil;
            OSStatus err = MIDIObjectGetStringProperty(source,
                               kMIDIPropertyDisplayName, &name);
            
            if (err == (OSStatus)noErr)
            {
                [uiMIDIOutputPopUpButton
                 addItemWithTitle:(__bridge NSString *)name];
            }
        }
    }

    [self validateMIDIOutput];
}

- (void)synchronizeForNewAudioDevice
{
    [uiAudioDevicePopUpButton removeAllItems];

    // Find out how many audio devices there are
    AudioObjectPropertyAddress pa;
    pa.mSelector = kAudioHardwarePropertyDevices;
    pa.mScope = kAudioObjectPropertyScopeWildcard;
    pa.mElement = kAudioObjectPropertyElementMasterx;
    
    UInt32 propSize;
    OSStatus error = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,
                                                    &pa, 0, NULL, &propSize);
    
    if (error == noErr)
    {
        // Calculate the number of audio devices
        int deviceCount = propSize / sizeof(AudioDeviceID);
        
        LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
              @"Found %i audio devices", deviceCount);
       
        // Get all the audio device IDs
        AudioDeviceID *audioDevices = (AudioDeviceID *)malloc(propSize);
        memset(audioDevices, 0, propSize);
        error = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                           &pa, 0, NULL, &propSize,
                                           (void *)audioDevices);
        
        if (error == noErr)
        {
            
            for (int i = 0; i < deviceCount; i++)
            {
                propSize = sizeof(CFStringRef);
                NSString *result;
                NSString *name = [NSMutableString stringWithString:@""];
                int outputCount = 0;
                AudioDeviceID devId = audioDevices[i];
            
                // Get the device name
                pa.mSelector = kAudioDevicePropertyDeviceNameCFString;
                error = AudioObjectGetPropertyData(devId, &pa, 0, NULL,
                                                   &propSize, (void *)&result);
                
                if (error == noErr)
                {
                    name = [result copy];
                }
                else
                {
                    LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                          @"Error getting name, error = %i (%@)",
                          error, statusToString(error));
                }
               
                // Get the device sample rate
                Float64 sampleRate;
                UInt32 size = sizeof(Float64);
                pa.mScope = kAudioDevicePropertyScopeOutput;
                pa.mSelector = kAudioDevicePropertyNominalSampleRate;
                
                error = AudioObjectGetPropertyData(devId, &pa, 0, NULL, &size,
                                                   (void *)&sampleRate);
                
                if (error != noErr)
                {
                    LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                          @"Error getting sample rate, error = %i (%@)",
                          error, statusToString(error));
                }
                
                if ([name isEqualToString:@""] == NO)
                {
                    // Get the number of output channels
                    size = 0;
                    pa.mSelector = kAudioDevicePropertyStreamConfiguration;
                    pa.mScope = kAudioDevicePropertyScopeOutput;
                    error = AudioObjectGetPropertyDataSize(devId, &pa, 0, NULL,
                                                           &size);
                    
                    if ((error == noErr) && (size > 0))
                    {
                        AudioBufferList *buf = (AudioBufferList *)malloc(size);
                        memset(buf, 0, size);
                        error = AudioObjectGetPropertyData(devId, &pa, 0, NULL,
                                                           &size, (void *)buf);
                    
                        if (error == noErr)
                        {
                            // Count the total number of output channels
                            for (int idx = 0; idx < buf->mNumberBuffers; idx++)
                            {
                                outputCount +=
                                    buf->mBuffers[idx].mNumberChannels;
                            }
                        }
                        
                        free(buf);
                        
                        if (outputCount > 0)
                        {
                            [uiAudioDevicePopUpButton addItemWithTitle:name];
                        }
                    }
                    else
                    {
                        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                              @"Error getting output stream configuration, "
                               "error = %i (%@)",
                              error, statusToString(error));
                    }
                    
                    LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                          @"Found %@, output channel count = %i, "
                          "sample rate = %i, ID = %i", name,
                          outputCount, (int)sampleRate, devId);
                    
                    [mAudioDeviceIDs setValue:
                        [NSNumber numberWithInteger:devId] forKey:name];
                    [mAudioDeviceChannelCounts setValue:
                        [NSNumber numberWithInteger:outputCount] forKey:name];
                }
            }
        }
        else
        {
            LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"Error getting audio device IDs, error = %i (%@)",
                  error, statusToString(error));
        }
        
        free(audioDevices);
    }
    else
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"AudioObjectGetPropertyDataSize for kAudioObjectSystemObject "
              " error = %i (%@)", error, statusToString(error));
    }
}

- (void)synchronizeForNewAudioChannels
{
    int outputCount = [[mAudioDeviceChannelCounts
                        objectForKey:mAudioDeviceName] intValue];
    NSNumber *deviceID = [mAudioDeviceIDs valueForKey:mAudioDeviceName];
    AudioDeviceID activeAudioDeviceID = (AudioDeviceID)[deviceID integerValue];
    NSMutableArray *channelList = [[NSMutableArray alloc] init];
    
    // Get the output channel names
    for (int i = 0; i < outputCount; i++)
    {
        NSMutableString *channelName = [[NSMutableString alloc] init];
        UInt32 dataSize = sizeof(channelName);
        AudioObjectPropertyAddress pa;
        pa.mSelector = kAudioObjectPropertyElementName;
        pa.mScope = kAudioDevicePropertyScopeOutput;
        pa.mElement = i + 1;
        OSStatus error = AudioObjectGetPropertyData(activeAudioDeviceID,
                                                    &pa, 0, NULL, &dataSize,
                                                    (void *)&channelName);
        
        if ((error != noErr) || ([channelName length] == 0))
        {
            [channelList addObject:
             [NSString stringWithFormat:@"Ch. %d", i + 1]];
        }
        else
        {
            [channelList addObject:channelName];
        }
    }
    
    // Update the channelPopUp selections
    [uiAudioChannelPopUpButton removeAllItems];

    if (outputCount > 0)
    {
        for (int i = 0; i < outputCount; i += 2)
        {
            NSMutableString *channelEntry = [[NSMutableString alloc] init];
            [channelEntry appendString:(NSString *)channelList[i]];
            [channelEntry appendString:@" / "];
            [channelEntry appendString:(NSString *)channelList[i + 1]];
            [uiAudioChannelPopUpButton addItemWithTitle:channelEntry];
        }
    }
    else
    {
        [uiAudioChannelPopUpButton addItemWithTitle:@"N/A"];
    }
}

- (void)synchronizeForNewSampleRate
{
    [uiAudioSampleRatePopUpButton removeAllItems];
    [uiAudioSampleRatePopUpButton addItemWithTitle:@"48000"];
    [uiAudioSampleRatePopUpButton addItemWithTitle:@"44100"];
    mAudioSampleRateName = (NSMutableString *)@"48000";
}

- (IBAction)iaMIDIInputPopUpButtonPressed:(id)sender
{
    NSString *inputName =
        (NSString *)[uiMIDIInputPopUpButton titleOfSelectedItem];

    if ([inputName containsString:@"Inactive"] == YES)
    {
        mMIDIInputIndex = [NSNumber numberWithLong:kNoneDevice];
    }
    else
    {
        mMIDIInputName = [inputName copy];
        [self validateMIDIInput];
    }
}

- (IBAction)iaMIDIOutputPopUpButtonPressed:(id)sender
{
    NSString *outputName =
        (NSString *)[uiMIDIOutputPopUpButton titleOfSelectedItem];

    if ([outputName containsString:@"Inactive"] == YES)
    {
        mMIDIOutputIndex = [NSNumber numberWithLong:kNoneDevice];
    }
    else
    {
        mMIDIOutputName = [outputName copy];
        [self validateMIDIOutput];
    }
}

- (void)validateMIDIInput
{
    if ([mMIDIInputName isEqualToString:@"None"] == YES)
    {
        [uiMIDIInputPopUpButton selectItemWithTitle:mMIDIInputName];
        mMIDIInputIndex = [NSNumber numberWithLong:kNoneDevice];
    }
    else if ([uiMIDIInputPopUpButton
              indexOfItemWithTitle:mMIDIInputName] == -1)
    {
        NSMutableString *name =
            [[NSMutableString alloc] initWithString:mMIDIInputName];
        [name appendString:@" (Inactive)"];
        [uiMIDIInputPopUpButton addItemWithTitle:name];
        [uiMIDIInputPopUpButton selectItemWithTitle:name];
        mMIDIInputIndex = [NSNumber numberWithLong:kNoneDevice];
    }
    else
    {
        [uiMIDIInputPopUpButton selectItemWithTitle:mMIDIInputName];
        long index = [uiMIDIInputPopUpButton
                     indexOfItemWithTitle:mMIDIInputName] - 1;
        mMIDIInputIndex = [NSNumber numberWithLong:index];
    }
}

- (void)validateMIDIOutput
{
    if ([mMIDIOutputName isEqualToString:@"None"] == YES)
    {
        [uiMIDIOutputPopUpButton selectItemWithTitle:mMIDIOutputName];
        mMIDIOutputIndex = [NSNumber numberWithLong:kNoneDevice];
    }
    else if ([uiMIDIOutputPopUpButton
              indexOfItemWithTitle:mMIDIOutputName] == -1)
    {
        NSMutableString *name =
            [[NSMutableString alloc] initWithString:mMIDIOutputName];
        [name appendString:@" (Inactive)"];
        [uiMIDIOutputPopUpButton addItemWithTitle:name];
        [uiMIDIOutputPopUpButton selectItemWithTitle:name];
        mMIDIOutputIndex = [NSNumber numberWithLong:kNoneDevice];
    }
    else
    {
        [uiMIDIOutputPopUpButton selectItemWithTitle:mMIDIOutputName];
        long index = [uiMIDIOutputPopUpButton
                     indexOfItemWithTitle:mMIDIOutputName] - 1;
        mMIDIOutputIndex = [NSNumber numberWithLong:index];
    }
}

- (IBAction)iaAudioDevicePopUpButtonPressed:(id)sender
{
    mAudioDeviceName = (NSMutableString *)[uiAudioDevicePopUpButton
                                           titleOfSelectedItem];
    
    [self synchronizeForNewAudioChannels];
    [uiAudioChannelPopUpButton selectItemAtIndex:0];
    mAudioChannelName = (NSMutableString *)[uiAudioChannelPopUpButton
                                            titleOfSelectedItem];
    mChannelIndex = [NSNumber numberWithLong:0];
}

- (IBAction)iaAudioChannelPopUpButtonPressed:(id)sender
{
    mAudioChannelName = (NSMutableString *)[uiAudioChannelPopUpButton
                                            titleOfSelectedItem];
    long index = [uiAudioChannelPopUpButton indexOfSelectedItem];
    mChannelIndex = [NSNumber numberWithLong:index];
}

- (IBAction)iaAudioSampleRatePopUpButtonPressed:(id)sender
{
    mAudioSampleRateName = (NSMutableString *)[uiAudioSampleRatePopUpButton
                                               titleOfSelectedItem];
}

- (IBAction)iaRecordCheckBox:(id)sender
{
    NSString *record = @"Enabled";
    
    if ([uiRecordCheckBox state] == NSOnState)
    {
        record = @"Enabled";
    }
    else
    {
        record = @"Disabled";
    }
    
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              record, @"Record", nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:
      @"com.larrymtaylor.StandaloneHost.RecordNotification" object:nil
      userInfo:settings];
}

- (void)loadSettings
{
    NSUserDefaults *userDefaults =
        [[NSUserDefaultsController sharedUserDefaultsController] values];

    NSString *settingsKey =
        [[NSString alloc] initWithFormat:@"%@ Settings", mAppName];
    
    if ([userDefaults valueForKey:settingsKey] != nil)
    {
        // Get settings
        NSDictionary *settings = [userDefaults valueForKey:settingsKey];
        LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
              @"Loading settings: %@", [settings description]);
        
        // MIDI input
        mMIDIInputName = [settings objectForKey:@"Midi Input"];
        mMIDIInputName = (mMIDIInputName == nil) ?
                         (NSMutableString *)@"None" : mMIDIInputName;
        [self validateMIDIInput];
        
        // MIDI output
        mMIDIOutputName = [settings objectForKey:@"Midi Output"];
        mMIDIOutputName = (mMIDIOutputName == nil) ?
                          (NSMutableString *)@"None" : mMIDIOutputName;
        [self validateMIDIOutput];
        
        // Key split and transpose settings
        mMIDIChannel = [settings objectForKey:@"Channel"];
        mLowKey = [settings objectForKey:@"Low Key"];
        mHighKey = [settings objectForKey:@"High Key"];
        mTranspose = [settings objectForKey:@"Transpose"];
        mTempo = [settings objectForKey:@"Tempo"];

        mMIDIChannel = (mMIDIChannel == nil) ? [NSNumber numberWithInteger:1] :
                       mMIDIChannel;
        mLowKey = (mLowKey == nil) ? [NSNumber numberWithInteger:33] : mLowKey;
        mHighKey = (mHighKey == nil) ? [NSNumber numberWithInteger:96] :
                   mHighKey;
        mTranspose = (mTranspose == nil) ? [NSNumber numberWithInteger:0] :
                     mTranspose;
        mTempo = (mTempo == nil) ? [NSNumber numberWithInteger:120] : mTempo;

        [uiChannelInput setStringValue:[mMIDIChannel stringValue]];
        [uiLowKeyInput setStringValue:[mLowKey stringValue]];
        [uiHighKeyInput setStringValue:[mHighKey stringValue]];
        [uiTransposeInput setStringValue:[mTranspose stringValue]];
        [uiTempoInput setStringValue:[mTempo stringValue]];

        // Audio output
        mAudioDeviceName = [settings objectForKey:@"Audio Device"];
        mAudioChannelName = [settings objectForKey:@"Audio Channel"];
        mAudioSampleRateName = [settings objectForKey:@"Sample Rate"];

        mAudioDeviceName = (mAudioDeviceName == nil) ?
                           (NSMutableString *)@"Built-in Output" :
                           mAudioDeviceName;
        mAudioChannelName = (mAudioChannelName == nil) ?
                            (NSMutableString *)@"Ch. 1 / Ch. 2" :
                            mAudioChannelName;
        mAudioSampleRateName = (mAudioSampleRateName == nil) ?
                               (NSMutableString *)@"48000" :
                               mAudioSampleRateName;

        long index = [uiAudioDevicePopUpButton
                     indexOfItemWithTitle:mAudioDeviceName];
        
        if (index == -1)
        {
            [uiAudioDevicePopUpButton selectItemAtIndex:0];
            mAudioDeviceName = (NSMutableString *)[uiAudioDevicePopUpButton
                                                   titleOfSelectedItem];
        }
        else
        {
            [uiAudioDevicePopUpButton selectItemWithTitle:mAudioDeviceName];
        }
        
        [self synchronizeForNewAudioChannels];
        
        index = [uiAudioChannelPopUpButton
                 indexOfItemWithTitle:mAudioChannelName];
        
        if (index == -1)
        {
            [uiAudioChannelPopUpButton selectItemAtIndex:0];
            mAudioChannelName = (NSMutableString *)[uiAudioChannelPopUpButton
                                                    titleOfSelectedItem];
            mChannelIndex = [NSNumber numberWithLong:0];
        }
        else
        {
            [uiAudioChannelPopUpButton selectItemWithTitle:mAudioChannelName];
            mChannelIndex = [NSNumber numberWithLong:index];
        }

        index = [uiAudioSampleRatePopUpButton
                 indexOfItemWithTitle:mAudioSampleRateName];
        
        if (index == -1)
        {
            [uiAudioSampleRatePopUpButton selectItemAtIndex:0];
            mAudioSampleRateName =
                (NSMutableString *)[uiAudioSampleRatePopUpButton
                                    titleOfSelectedItem];
        }
        else
        {
            [uiAudioSampleRatePopUpButton
             selectItemWithTitle:mAudioSampleRateName];
        }
    }
}

- (void)saveSettings
{
    if (mAppName != nil)
    {
        mMIDIChannel = [NSNumber numberWithInt:[uiChannelInput intValue]];
        mLowKey = [NSNumber numberWithInt:[uiLowKeyInput intValue]];
        mHighKey = [NSNumber numberWithInt:[uiHighKeyInput intValue]];
        mTranspose = [NSNumber numberWithInt:[uiTransposeInput intValue]];
        mTempo = [NSNumber numberWithInt:[uiTempoInput intValue]];

        NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                                  mMIDIInputName, @"Midi Input",
                                  mMIDIOutputName, @"Midi Output",
                                  mAudioDeviceName, @"Audio Device",
                                  mAudioChannelName, @"Audio Channel",
                                  mAudioSampleRateName, @"Sample Rate",
                                  mMIDIChannel, @"Channel",
                                  mLowKey, @"Low Key",
                                  mHighKey, @"High Key",
                                  mTranspose, @"Transpose",
                                  mTempo, @"Tempo", nil];
 
        NSUserDefaults *userDefaults =
            [[NSUserDefaultsController sharedUserDefaultsController] values];
        NSString *settingsKey = 
            [[NSString alloc] initWithFormat:@"%@ Settings", mAppName];
    
        [userDefaults setValue:settings forKey:settingsKey];
        
        LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
              @"Saving settings: %@", [settings description]);
    }
}

- (void)sendSettings
{
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              mMIDIInputIndex, @"Midi Input Index",
                              mMIDIOutputIndex, @"Midi Output Index",
                              mChannelIndex, @"Channel Index",
                              mAudioDeviceName, @"Audio Device",
                              mAudioSampleRateName, @"Sample Rate",
                              mMIDIChannel, @"Channel",
                              mLowKey, @"Low Key",
                              mHighKey, @"High Key",
                              mTranspose, @"Transpose",
                              mTempo, @"Tempo",
                              mAudioDeviceIDs, @"Device IDs",
                              mAudioDeviceChannelCounts, @"Channel Counts",
                              nil];
 
    [[NSNotificationCenter defaultCenter] postNotificationName:
      @"com.larrymtaylor.StandaloneHost.SettingsNotification" object:nil
      userInfo:settings];
}

- (void)cleanup
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)receiveMIDINotification:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:@"LTMIDINotification"] == YES)
    {
        [self synchronizeForNewMIDIInputs];
        [self synchronizeForNewMIDIOutputs];
    }
}

- (void)awakeFromNib
{
    [self.window setBackgroundColor:[NSColor colorWithSRGBRed:(61.0 / 255.0)
                                     green:(39.0 / 255.0) blue:(93.0 / 255.0)
                                     alpha:1.0]];
}

- (void)initSettings:(NSString *)appName
{
    mAppName = [[NSString alloc] initWithString:appName];
    
    // Set up logging
    mLog = os_log_create("com.larrymtaylor.StandaloneHost", "Settings");
    NSString *path =
        [[NSFileManager defaultManager] applicationSupportDirectory];
    mLogFile = [[NSString alloc] initWithFormat:@"%@/logFile.txt", path];
    
    // Initialize member variables
    mAudioDeviceIDs = [[NSMutableDictionary alloc] init];
    mAudioDeviceChannelCounts = [[NSMutableDictionary alloc] init];
    mMIDIInputIndex = [[NSNumber alloc] initWithLong:kNoneDevice];
    mMIDIOutputIndex = [[NSNumber alloc] initWithLong:kNoneDevice];
    
    // Initialize user settings
    mMIDIInputName = (NSMutableString *)@"None";
    mMIDIOutputName = (NSMutableString *)@"None";
    mAudioDeviceName = (NSMutableString *)@"Built-in Output";
    mAudioChannelName = (NSMutableString *)@"Ch. 1 / Ch. 2";
    mChannelIndex = [NSNumber numberWithLong:0];
    mAudioSampleRateName = (NSMutableString *)@"48000";
    
    mMIDIChannel = [[NSNumber alloc] initWithInt:1];
    mLowKey = [[NSNumber alloc] initWithInt:33];
    mHighKey = [[NSNumber alloc] initWithInt:96];
    mTranspose = [[NSNumber alloc] initWithInt:0];
    mTempo = [[NSNumber alloc] initWithInt:120];
    
    [uiChannelInput setStringValue:[mMIDIChannel stringValue]];
    [uiLowKeyInput setStringValue:[mLowKey stringValue]];
    [uiHighKeyInput setStringValue:[mHighKey stringValue]];
    [uiTransposeInput setStringValue:[mTranspose stringValue]];
    [uiTempoInput setStringValue:[mTempo stringValue]];
    
    // Populate pick lists
    [self synchronizeForNewMIDIInputs];
    [self synchronizeForNewMIDIOutputs];
    [self synchronizeForNewAudioDevice];
    [self synchronizeForNewAudioChannels];
    [self synchronizeForNewSampleRate];
    
    // Load settings
    [self loadSettings];
    
    // Watch for window close
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification
        object:[self window]];
    
    // Watch for MIDI notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(receiveMIDINotification:)
        name:@"LTMIDINotification" object:nil];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [self saveSettings];
    [self sendSettings];
}

@end
