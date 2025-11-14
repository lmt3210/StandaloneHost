//
// SynthWindowController.mm
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

#import "Synths.h"
#import "LTAUMgr.h"
#import "SynthWindowController.h"
#import "NSFileManager+DirectoryLocations.h"


@implementation SynthWindowController

- (instancetype)init
{
    if ((self = [super init]))
    {
        // Set up logging
        mLog = os_log_create("com.larrymtaylor.StandaloneHost", "Synth");
        mMIDIControl.log = mLog;
        NSString *path =
            [[NSFileManager defaultManager] applicationSupportDirectory];
        mLogFile = [[NSString alloc] initWithFormat:@"%@/logFile.txt", path];

        // Initialize variables
        mAUMgr = nil;
        mSynthUnit = nil;
        mOutputUnit = nil;
    }

    return self;
}

- (void)setupMIDI
{
    OSStatus err = statusErr;
    
    err = MIDIClientCreate(CFSTR("StandaloneHost"), midiNotifyProc,
                                 &mMIDIControl, &mMIDIClient);
    
    if (err != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR, 
              @"MIDIClientCreate error = %i (%@)", err, statusToString(err));
    }
    
    mMIDIControl.synthUnit = mSynthUnit;
    err = MIDIInputPortCreate(mMIDIClient, CFSTR("Input port"), midiReadProc,
                              &mMIDIControl, &mMIDIInPort);
    
    if (err != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"MIDIInputPortCreate error = %i (%@)", err,
              statusToString(err));
    }

    err = MIDIOutputPortCreate(mMIDIClient, CFSTR("Output port"),
                               &mMIDIOutPort);
    
    if (err != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"MIDIOutputPortCreate error = %i (%@)", err,
              statusToString(err));
    }
}

- (void)setMIDIInput
{
    OSStatus err = statusErr;
    
    if (mMIDIInPort && mMIDISource)
    {
        err = MIDIPortDisconnectSource(mMIDIInPort, mMIDISource);
        mMIDISource = NULL;
        
        if (err != noErr)
        {
            LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"MIDIPortDisconnectSource error = %i (%@)",
                  err, statusToString(err));
        }
    }
   
    long index = [mMIDIInputIndex longValue];

    if ((index != kNoneDevice) && (mMIDIInPort))
    {
        mMIDISource = MIDIGetSource(index);
        err = MIDIPortConnectSource(mMIDIInPort, mMIDISource, NULL);
        
        if (err != noErr)
        {
            LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"MIDIPortConnectSource error = %i (%@)", err,
                  statusToString(err));
        }
    }
}

- (void)setMIDIOutput
{
    long index = [mMIDIOutputIndex longValue];
    
    if ((index != kNoneDevice) && (mMIDIOutPort))
    {
        mMIDIDestination = MIDIGetDestination(index);
            
        if (mMIDIDestination == (MIDIEndpointRef)NULL)
        {
            mMIDIControl.outPort = NULL;
            mMIDIControl.destination = NULL;
            LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"MIDIGetDestination error");
        }
        else
        {
            mMIDIControl.outPort = mMIDIOutPort;
            mMIDIControl.destination = mMIDIDestination;
        }
    }
}

- (void)setAudioUnit
{
    AudioComponentDescription desc = { 0 };
    desc.componentType = mAUType;
    desc.componentSubType = mAUSubtype;
    desc.componentManufacturer = mAUMfg;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
          @"Setting up AU with type %@, subtype %@, manufacturer %@",
          statusToString(mAUType), statusToString(mAUSubtype),
          statusToString(mAUMfg));

    // Get version
    // Version number format is 0xMMMMmmbb
    UInt32 theVersionNumber = 0;
    AudioComponent component = AudioComponentFindNext(0, &desc);
    AudioComponentGetVersion(component, &theVersionNumber);
    LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO, @"Audio Unit version = %i.%i.%i",
          ((theVersionNumber >> 16) & 0x0000ffff),
          ((theVersionNumber >> 8) & 0x000000ff),
          (theVersionNumber & 0x000000ff));

    // Setup callbacks
    HostCallbackInfo callbackInfo;
    callbackInfo.hostUserData = &mCallbackData;
    callbackInfo.beatAndTempoProc = getBeatAndTempo;
    callbackInfo.musicalTimeLocationProc = NULL;
    callbackInfo.transportStateProc = NULL;
    callbackInfo.transportStateProc2 = NULL;
    UInt32 callDataSize = sizeof(HostCallbackInfo);
    OSStatus err = AudioUnitSetProperty(mSynthUnit,
                                        kAudioUnitProperty_HostCallbacks,
                                        kAudioUnitScope_Global, 0,
                                        &callbackInfo, callDataSize);

    if (err != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Error setting host callbacks, error = %i (%@)",
              err, statusToString(err));
    }

    // Set frames per slice
    UInt32 frames = 2048;
    UInt32 fSize = sizeof(frames);
    err = AudioUnitSetProperty(mSynthUnit,
                               kAudioUnitProperty_MaximumFramesPerSlice,
                               kAudioUnitScope_Output, 0, &frames, fSize);

    if (err != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Error setting frames per slice, error = %i (%@)",
              err, statusToString(err));
    }
    
    // Set the render callback
    err = AudioUnitAddRenderNotify(mSynthUnit, renderNotifyProc,
                                   &mMIDIControl);

    if (err != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Error setting the render callback, error = %i (%@)",
              err, statusToString(err));
    }
    
    // See if AU has MIDI output and set callback if it does
    long numMidiOutputs = 0;
    CFArrayRef midiOutputs = NULL;
    UInt32 propSize = sizeof(midiOutputs);
    err = AudioUnitGetProperty(mSynthUnit,
                               kAudioUnitProperty_MIDIOutputCallbackInfo,
                               kAudioUnitScope_Global, 0,
                               &midiOutputs, &propSize);

    if (err == noErr)
    {
        numMidiOutputs = CFArrayGetCount(midiOutputs);
        
        if (numMidiOutputs > 0)
        {
            AUMIDIOutputCallbackStruct midiOutputCallbackStruct;
            memset(&midiOutputCallbackStruct, 0,
                   sizeof(midiOutputCallbackStruct));
            midiOutputCallbackStruct.midiOutputCallback = midiOutputProc;
            midiOutputCallbackStruct.userData = &mMIDIControl;
            
            err = AudioUnitSetProperty(mSynthUnit,
                                       kAudioUnitProperty_MIDIOutputCallback,
                                       kAudioUnitScope_Global, 0,
                                       &midiOutputCallbackStruct,
                                       sizeof(midiOutputCallbackStruct));

            if (err != noErr)
            {
                LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                      @"Error setting the MIDIOutputCallback, error = %i (%@)",
                      err, statusToString(err));
            }
            
            LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                  @"Synth has %i MIDI output(s)",
                  numMidiOutputs);
            
            for (int i = 0; i < numMidiOutputs; i++)
            {
                
                LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                      @"Synth MIDI output #%i = %@",
                      (i + 1), CFArrayGetValueAtIndex(midiOutputs, i));
            }
        }
        
        CFRelease(midiOutputs);
    }

    // Init everything
    [mAUMgr initAU];
    [mAUMgr initOutput];
    [mAUMgr connectUnits];
    [mAUMgr startOutput];
  
    // Set up MIDI
    [self setupMIDI];
    [self setMIDIInput];
    [self setMIDIOutput];

    // Show the GUI
    [mSynthWindow showViewForAU:mSynthUnit withName:mDisplayName];
    [mSynthWindow centerAUView];
}

- (void)setSynthSampleRate
{
    [mAUMgr stopOutput];
    [mAUMgr uninitAU];
    
    // Set AU sample rate
    OSStatus err = AudioUnitSetProperty(mSynthUnit,
                                        kAudioUnitProperty_SampleRate,
                                        kAudioUnitScope_Output, 0,
                                        &mSampleRate, sizeof(Float64));
    
    if (err != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
              @"Status after setting AU sample rate = %i (%@)",
              err, statusToString(err));
    }
    
    [mAUMgr initAU];
    [mAUMgr startOutput];
}

- (void)setSampleRate
{
    NSNumber *deviceID = [mAudioDeviceIDs valueForKey:mAudioDeviceName];
    AudioDeviceID activeAudioDeviceID = (AudioDeviceID)[deviceID integerValue];

    if (activeAudioDeviceID != 0)
    {
        AudioObjectPropertyAddress pa;
        pa.mSelector = kAudioDevicePropertyNominalSampleRate;
        pa.mScope = kAudioObjectPropertyScopeGlobal;
        pa.mElement = kAudioObjectPropertyElementMasterx;
        OSStatus error = AudioObjectSetPropertyData(activeAudioDeviceID,
                                                    &pa, 0, NULL,
                                                    sizeof(mSampleRate),
                                                    &mSampleRate);
        if (error != noErr)
        {
            LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"Set sample rate error = %i (%@)", error,
                  statusToString(error));
        }
    }
}

- (void)setAudioDevice
{
    NSNumber *deviceID = [mAudioDeviceIDs valueForKey:mAudioDeviceName];
    AudioDeviceID activeAudioDeviceID = (AudioDeviceID)[deviceID integerValue];
    
    // Select the desired output device
    OSStatus error = 
        AudioUnitSetProperty(mOutputUnit,
                             kAudioOutputUnitProperty_CurrentDevice,
                             kAudioUnitScope_Global, 0,
                             &activeAudioDeviceID,
                             sizeof(activeAudioDeviceID));
    
    if (error != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Select output device error = %i (%@)", error,
              statusToString(error));
    }
}

- (void)setAudioChannel
{
    long index = [mChannelIndex longValue];
    UInt32 numChannels = [[mAudioDeviceChannelCounts
                           objectForKey:mAudioDeviceName] intValue];
    SInt32 *channelMap = NULL;
    UInt32 mapSize = numChannels * sizeof(SInt32);
    channelMap = (SInt32 *)malloc(mapSize);
    
    // For each channel of desired input, map the channel from
    // the device's output channel.
    for (UInt32 i = 0; i < numChannels; i++)
    {
        channelMap[i] = -1;
    }
    
    // channelMapArray[deviceOutputChannel] = desiredAppOutputChannel
    channelMap[(SInt32)((index * 2) + 0)] = 0;
    channelMap[(SInt32)((index * 2) + 1)] = 1;
    
    OSStatus error = AudioUnitSetProperty(mOutputUnit,
                                          kAudioOutputUnitProperty_ChannelMap,
                                          kAudioUnitScope_Output, 0,
                                          channelMap, mapSize);
    
    if (error != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Select output channels error = %i (%@)", error,
              statusToString(error));
    }
    
    free(channelMap);
}

- (void)setupAUHAL
{
    OSStatus err = statusErr;
    AudioUnit inputUnit;
    
    AudioComponent comp;
    AudioComponentDescription desc = { 0 };
    
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_HALOutput;
    
    // All Audio Units in AUComponent.h must use
    // kAudioUnitManufacturer_Apple as the Manufacturer
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    // Finds a component that meets the desc spec's
    comp = AudioComponentFindNext(NULL, &desc);
    
    if (comp == NULL)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Failed AudioComponentFindNext for AUHAL");
        return;
    }
    
    // Gains access to the services provided by the component
    err = AudioComponentInstanceNew(comp, &inputUnit);
    
    if (err != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Failed AudioComponentInstanceNew for AUHAL, error = %i (%@)",
               err, statusToString(err));
    }
    
    // AUHAL needs to be initialized before anything is done to it
    err = AudioUnitInitialize(inputUnit);
    
    if (err != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Failed AudioUnitInitialize, error = %i (%@)",
              err, statusToString(err));
    }
}

- (synthStatus)loadSynth:(NSString *)appName
{
    synthStatus status = SYNTH_STATUS_UNKNOWN;
    mAUType = 'auna';
    mAUMfg = 'none';
    mAUSubtype = 'none';

    // See if we have this synth in Synths.h
    for (int i = 0;
         i < (sizeof(knownSynths) / sizeof(struct synthDefinition)); i++)
    {
        if ([knownSynths[i].appName isEqualToString:appName] == YES)
        {
            mDisplayName = knownSynths[i].auName;
            mAUType = kAudioUnitType_MusicDevice;
            mAUMfg = knownSynths[i].mfg;
            mAUSubtype = knownSynths[i].subtype;
            status = SYNTH_STATUS_FOUND;
            LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                  @"Found \"%@\" in known list, auName = %@",
                  appName, mDisplayName);
            break;
        }
    }
 
    // See if we can exactly match the name in the installed list from
    // AudioComponent manager
    CAComponentDescription desc =
        CAComponentDescription(kAudioUnitType_MusicDevice);
    int count = desc.Count();
    UInt32 dataByteSize = count * sizeof(CAComponent);
    CAComponent *AUList = static_cast<CAComponent *>(malloc(dataByteSize));
    memset(AUList, 0, dataByteSize);
    CAComponent *last = NULL;

    if (status == SYNTH_STATUS_UNKNOWN)
    {
        // Build AUList
        for (int i = 0; i < count; ++i)
        {
            AUList[i] = CAComponent(desc, last);
            last = &(AUList[i]);
        }

        for (int i = 0; i < count; ++i)
        {
            NSString *auName = (__bridge NSString *)AUList[i].GetAUName();

            if ([appName isEqualToString:auName] == YES)
            {
                AudioComponentDescription desc = AUList[i].Desc();
                mDisplayName = [auName copy];
                mAUType = desc.componentType;
                mAUMfg = desc.componentManufacturer;
                mAUSubtype = desc.componentSubType;

                LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                      @"Found \"%@\" installed AUs (exact match), "
                       "auName is \"%@\"", appName, auName);
                status = SYNTH_STATUS_FOUND;
                break;
            }
        }
    }

    free(AUList);
    
    // See if we can exactly match the name in the installed list from
    // AudioComponent manager for MIDI effects
    desc = CAComponentDescription(kAudioUnitType_MIDIProcessor);
    count = desc.Count();
    dataByteSize = count * sizeof(CAComponent);
    AUList = static_cast<CAComponent *>(malloc(dataByteSize));
    memset(AUList, 0, dataByteSize);
    last = NULL;

    if (status == SYNTH_STATUS_UNKNOWN)
    {
        // Build AUList
        for (int i = 0; i < count; ++i)
        {
            AUList[i] = CAComponent(desc, last);
            last = &(AUList[i]);
        }

        for (int i = 0; i < count; ++i)
        {
            NSString *auName = (__bridge NSString *)AUList[i].GetAUName();

            if ([appName isEqualToString:auName] == YES)
            {
                AudioComponentDescription desc = AUList[i].Desc();
                mDisplayName = [auName copy];
                mAUType = desc.componentType;
                mAUMfg = desc.componentManufacturer;
                mAUSubtype = desc.componentSubType;

                LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                      @"Found \"%@\" in installed AUs (exact match), "
                       "auName is \"%@\"", appName, auName);
                status = SYNTH_STATUS_FOUND;
                break;
            }
        }
    }

    free(AUList);

    // See if we can closely match the name in the installed list from
    // AudioComponent manager for soft synths
    desc = CAComponentDescription(kAudioUnitType_MusicDevice);
    count = desc.Count();
    dataByteSize = count * sizeof(CAComponent);
    AUList = static_cast<CAComponent *>(malloc(dataByteSize));
    memset(AUList, 0, dataByteSize);
    last = NULL;
    
    if (status == SYNTH_STATUS_UNKNOWN)
    {
        // Build AUList
        for (int i = 0; i < count; ++i)
        {
            AUList[i] = CAComponent(desc, last);
            last = &(AUList[i]);
        }

        for (int i = 0; i < count; ++i)
        {
            NSString *auName = (__bridge NSString *)AUList[i].GetAUName();

            if (([auName containsString:appName] == YES) ||
                ([appName containsString:auName] == YES))
            {
                AudioComponentDescription desc = AUList[i].Desc();
                mDisplayName = [auName copy];
                mAUType = desc.componentType;
                mAUMfg = desc.componentManufacturer;
                mAUSubtype = desc.componentSubType;

                LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                      @"Found \"%@\" in installed AUs (close match), "
                       "auName is \"%@\"", appName, auName);
                status = SYNTH_STATUS_FOUND;
                break;
            }
        }
    }

    free(AUList);
    
    // See if we can closely match the name in the installed list from
    // AudioComponent manager for MIDI effects
    desc = CAComponentDescription(kAudioUnitType_MIDIProcessor);
    count = desc.Count();
    dataByteSize = count * sizeof(CAComponent);
    AUList = static_cast<CAComponent *>(malloc(dataByteSize));
    memset(AUList, 0, dataByteSize);
    last = NULL;

    if (status == SYNTH_STATUS_UNKNOWN)
    {
        // Build AUList
        for (int i = 0; i < count; ++i)
        {
            AUList[i] = CAComponent(desc, last);
            last = &(AUList[i]);
        }

        for (int i = 0; i < count; ++i)
        {
            NSString *auName = (__bridge NSString *)AUList[i].GetAUName();

            if (([auName containsString:appName] == YES) ||
                ([appName containsString:auName] == YES))
            {
                AudioComponentDescription desc = AUList[i].Desc();
                mDisplayName = [auName copy];
                mAUType = desc.componentType;
                mAUMfg = desc.componentManufacturer;
                mAUSubtype = desc.componentSubType;

                LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                      @"Found \"%@\" in installed AUs (close match), "
                       "auName is \"%@\"", appName, auName);
                status = SYNTH_STATUS_FOUND;
                break;
            }
        }
    }

    free(AUList);
    
    // Last, try to get AU info from component bundle Info.plist
    if (status == SYNTH_STATUS_UNKNOWN)
    {
        NSMutableString *synthPath = [[NSMutableString alloc]
            initWithString:@"/Library/Audio/Plug-Ins/Components/"];
        [synthPath appendString:appName];
        [synthPath appendString:@".component"];
        NSBundle *synthBundle = [NSBundle bundleWithPath:synthPath];
        
        if (synthBundle == nil)
        {
            LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                  @"\"%@\" component not found", appName);
        }
        else
        {
            mAUName = [synthBundle objectForInfoDictionaryKey:@"CFBundleName"];
            
            // Get manufacturer and subtype from component bundle Info.plist
            NSArray *audArray =
                [synthBundle objectForInfoDictionaryKey:@"AudioComponents"];
            
            if (audArray != nil)
            {
                NSDictionary *audDict = audArray[0];
                mDisplayName = audDict[@"description"];

                NSString *auType = audDict[@"type"];
                UInt8 tmp[4] = { 0 };
                memcpy(&tmp,
                       [auType cStringUsingEncoding:NSASCIIStringEncoding],
                       sizeof(mAUType));
                UInt8 *ptr = (UInt8 *)&mAUType;
                ptr[0] = tmp[3];
                ptr[1] = tmp[2];
                ptr[2] = tmp[1];
                ptr[3] = tmp[0];
                
                NSString *auMfg = audDict[@"manufacturer"];
                memcpy(&tmp,
                       [auMfg cStringUsingEncoding:NSASCIIStringEncoding],
                       sizeof(mAUMfg));
                ptr = (UInt8 *)&mAUMfg;
                ptr[0] = tmp[3];
                ptr[1] = tmp[2];
                ptr[2] = tmp[1];
                ptr[3] = tmp[0];
                
                NSString *AUSubtype =audDict[@"subtype"];
                memcpy(&tmp,
                       [AUSubtype
                        cStringUsingEncoding:NSMacOSRomanStringEncoding],
                       sizeof(mAUSubtype));
                ptr = (UInt8 *)&mAUSubtype;
                ptr[0] = tmp[3];
                ptr[1] = tmp[2];
                ptr[2] = tmp[1];
                ptr[3] = tmp[0];

                LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                      @"Found \"%@\" after parsing AudioComponents dictionary",
                      appName);
                status = SYNTH_STATUS_FOUND;
            }
            else
            {
                LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
                      @"\"%@\" does not have an AudioComponents dictionary",
                      appName);
            }
        }
    }

    // Check that AU is a synth or MIDI effect
    if ((mAUType != kAudioUnitType_MusicDevice) &&
        (mAUType != kAudioUnitType_MIDIProcessor) &&
        (status == SYNTH_STATUS_FOUND))
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO, @"\"%@\" is not %@, is %@",
              appName, statusToString(kAudioUnitType_MusicDevice),
              statusToString(mAUType));
        status = SYNTH_STATUS_NOT_SUPPORTED;
    }

    // Fall back to DLS Music Device if needed
    if (status != SYNTH_STATUS_FOUND)
    {
        mAUName = @"DLS Music Device";
        mDisplayName = @"DLS Music Device";
        mAUType = kAudioUnitType_MusicDevice;
        mAUMfg = 'appl';
        mAUSubtype = 'dls ';
    }
    
    // Initialize channel, key range, and transpose
    mMIDIControl.channel = 0;
    mMIDIControl.low = 33;
    mMIDIControl.high = 96;
    mMIDIControl.transpose = 0;
    
    // Initialize play buffer
    mMIDIControl.playHead = 0;
    mMIDIControl.playTail = 0;
    
    // Synth unit is unknown for now
    mMIDIControl.synthUnit = nil;

    // MIDI output port is unknown for now
    mMIDIControl.outPort = NULL;
    mMIDIControl.destination = NULL;
    
    // Initialize callback data
    mCallbackData.log = mLog;
    mCallbackData.beat = 0.0;
    mCallbackData.tempo = 120.0;
    
    // Set up for saving MIDI events
    mLastRecordCount = 0;
    mRecordTimer = nil;

    // Create AU window
    mSynthWindow = [[LTSynthWindow alloc] initWithLogHandle:mLog
                    withLogFile:mLogFile];
    
    // Watch for settings notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(receiveSettingsNotification:)
      name:@"com.larrymtaylor.StandaloneHost.SettingsNotification"
      object:nil];
    
    // Watch for record notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(receiveRecordNotification:)
      name:@"com.larrymtaylor.StandaloneHost.RecordNotification"
      object:nil];
    
    // MIDI error monitor timer
    mMIDITimer = [NSTimer scheduledTimerWithTimeInterval:5
                  target:self selector:@selector(MIDITimer:)
                  userInfo:nil repeats:YES];

    // Initialize HAL
    [self setupAUHAL];
    
    // Create AUMgr and output
    mAUMgr = [[LTAUMgr alloc] initWithLogHandle:mLog withLogFile:mLogFile];
    mOutputUnit = [mAUMgr createOutput];

    // Do this to get the flags and mask
    AudioComponentDescription audesc = { 0 };
    audesc.componentType = mAUType;
    audesc.componentManufacturer = mAUMfg;
    audesc.componentSubType = mAUSubtype;
    AudioComponent comp = AudioComponentFindNext(NULL, &audesc);
    AudioComponentGetDescription(comp, &audesc);
    
    // Add AU
    mSynthUnit = [mAUMgr createAU:audesc];

    // Set up the AU
    [self setAudioUnit];
    
    return status;
}

- (void)receiveSettingsNotification:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:
         @"com.larrymtaylor.StandaloneHost.SettingsNotification"] == YES)
    {
        NSDictionary *userInfo = notification.userInfo;
        mMIDIInputIndex = userInfo[@"Midi Input Index"];
        mMIDIOutputIndex = userInfo[@"Midi Output Index"];
        mChannelIndex = userInfo[@"Channel Index"];
        mAudioDeviceName = userInfo[@"Audio Device"];
        mAudioSampleRateName = userInfo[@"Sample Rate"];
        mMIDIChannel = userInfo[@"Channel"];
        mLowKey = userInfo[@"Low Key"];
        mHighKey = userInfo[@"High Key"];
        mTranspose = userInfo[@"Transpose"];
        mTempo = userInfo[@"Tempo"];
        mAudioDeviceIDs = userInfo[@"Device IDs"];
        mAudioDeviceChannelCounts = userInfo[@"Channel Counts"];
    
        mSampleRate = [mAudioSampleRateName floatValue];
    
        mMIDIControl.channel = [mMIDIChannel intValue] - 1;
        mMIDIControl.low = [mLowKey intValue];
        mMIDIControl.high = [mHighKey intValue];
        mMIDIControl.transpose = [mTranspose intValue];
        mCallbackData.tempo = [mTempo floatValue];

        [self setMIDIInput];
        [self setMIDIOutput];
        [self setAudioDevice];
        [self setAudioChannel];
        [self setSampleRate];
        [self setSynthSampleRate];
    }
}

- (void)receiveRecordNotification:(NSNotification *)notification
{
    NSString *record;
    
    if ([[notification name] isEqualToString:
         @"com.larrymtaylor.StandaloneHost.RecordNotification"] == YES)
    {
        NSDictionary *userInfo = notification.userInfo;
        record = userInfo[@"Record"];
    }
    
    // Stop timer
    if (mRecordTimer)
    {
        [mRecordTimer invalidate];
        mRecordTimer = nil;
    }
    
    if ([record isEqualToString:@"Enabled"] == YES)
    {
        mMIDIControl.recordEnable = 1;
        mMIDIControl.recordCount = 0;
        mLastRecordCount = 0;
        
        mRecordTimer = [NSTimer scheduledTimerWithTimeInterval:5
                       target:self selector:@selector(recordTimer:)
                       userInfo:nil repeats:YES];
    }
    else
    {
        mMIDIControl.recordEnable = 0;
    }
}

- (void)recordTimer:(NSTimer *)timer
{
    if (mMIDIControl.recordEnable == 1)
    {
        // Save if activity has stopped for 5 seconds or the buffer is full
        if (((mLastRecordCount == mMIDIControl.recordCount) &&
            (mLastRecordCount > 0)) ||
            (mMIDIControl.recordCount >= kMaxRecordEvents))
        {
            // Time to save and reset
            mMIDIControl.recordEnable = 0;
            
            // Create a new sequence
            MusicSequence musicSequence;
            OSStatus err = NewMusicSequence(&musicSequence);
            
            if (err != noErr)
            {
                LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                      @"NewMusicSequence error = %i (%@)", err,
                      statusToString(err));
            }

            // Set the tempo
            MusicTrack tempoTrack;
            err = MusicSequenceGetTempoTrack(musicSequence, &tempoTrack);
            
            if (err != noErr)
            {
                LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                      @"MusicSequenceGetTempoTrack error = %i (%@)", err,
                      statusToString(err));
            }

            MIDIMetaEvent *metaEvent = NULL;
            metaEvent =
                (MIDIMetaEvent *)malloc(sizeof(struct MIDIMetaEvent) + 3);
            metaEvent->metaEventType = 0x51;
            metaEvent->dataLength = 3;
            int us = 60000000L / [mTempo intValue];  // micro-seconds per QN
            metaEvent->data[0] = (Byte)((us >> 16) & 0xff);
            metaEvent->data[1] = (Byte)((us >> 8) & 0xff);
            metaEvent->data[2] = (Byte)((us >> 0) & 0xff);
            MusicTrackNewMetaEvent(tempoTrack, 0, metaEvent);

            // Set time signature (4/4 for now)
            metaEvent->metaEventType = 0x58;
            metaEvent->dataLength = 4;
            metaEvent->data[0] = 0x04;
            metaEvent->data[1] = 0x02;
            metaEvent->data[2] = 0x18;
            metaEvent->data[3] = 0x08;
            MusicTrackNewMetaEvent(tempoTrack, 0, metaEvent);
            free(metaEvent);

            // Create a track to hold the data
            MusicTrack musicTrack;
            err = MusicSequenceNewTrack(musicSequence, &musicTrack);

            if (err != noErr)
            {
                LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                      @"MusicSequenceNewTrack error = %i (%@)",
                      err, statusToString(err));
            }
            
            MusicTimeStamp inTimeStamp;
            MIDIChannelMessage inData = { 0 };
            MIDITimeStamp startingTime = mMIDIControl.recordData[0].timeStamp;
            
            // Add all events to track
            for (int i = 0; i < mMIDIControl.recordCount; i++)
            {
                inTimeStamp = (MusicTimeStamp)
                     (AudioConvertHostTimeToNanos((mMIDIControl.recordData[i].
                     timeStamp - startingTime)) / 500000000.0);
                
                inData.status = mMIDIControl.recordData[i].data[0];
                inData.data1 = mMIDIControl.recordData[i].data[1];
                inData.data2 = mMIDIControl.recordData[i].data[2];
                err = MusicTrackNewMIDIChannelEvent(musicTrack, inTimeStamp,
                                                    &inData);
                
                if (err != noErr)
                {
                    LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                          @"MusicTrackNewMIDIChannelEvent error = %i (%@)",
                          err, statusToString(err));
                    break;
                }
            }
            
            // Make a unique file name
            struct passwd *pw = getpwuid(getuid());
            NSString *realHomeDir = [NSString stringWithUTF8String:pw->pw_dir];
            NSMutableString *fileName =
               [[NSMutableString alloc] initWithString:realHomeDir];
            [fileName appendFormat:@"/Music/StandaloneHost/%@ ", mDisplayName];
            NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
            [DateFormatter setDateFormat:@"yyyy-MM-dd 'at' hh-mm-ss"];
            [fileName appendString:[DateFormatter
                                    stringFromDate:[NSDate date]]];
            [fileName appendString:@".mid"];
            NSURL *fileURL = [[NSURL alloc] initFileURLWithPath:fileName];
            
            // Save the sequence
            err = MusicSequenceFileCreate(musicSequence,
                                          (__bridge CFURLRef)fileURL,
                                          kMusicSequenceFile_MIDIType,
                                          kMusicSequenceFileFlags_Default, 0);

            if (err != noErr)
            {
                LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                      @"MusicSequenceFileCreate error = %i (%@)",
                      err, statusToString(err));
            }
            
            // Reset counts and re-enable
            mMIDIControl.recordCount = 0;
            mLastRecordCount = 0;
            mMIDIControl.recordEnable = 1;
        }
    
        mLastRecordCount = mMIDIControl.recordCount;
    }
}

- (void)cleanup
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Stop timers
    if (mMIDITimer)
    {
        [mMIDITimer invalidate];
        mMIDITimer = nil;
    }
    
    if (mRecordTimer)
    {
        [mRecordTimer invalidate];
        mRecordTimer = nil;
    }
    
    // Disconnect MIDI source
    if (mMIDIInPort && mMIDISource)
    {
        OSStatus err = MIDIPortDisconnectSource(mMIDIInPort, mMIDISource);
        
        if (err != noErr)
        {
            LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"MIDIPortDisconnectSource error = %i (%@)",
                  err, statusToString(err));
        }
    }
    
    // Unload AU
    if (mSynthUnit != nil)
    {
        [mAUMgr stopOutput];
        [mSynthWindow closeViewForAU];
        [mAUMgr deleteAU];
        [mAUMgr deleteOutput];
        mSynthUnit = nil;
        mOutputUnit = nil;
    }
}

- (void)MIDITimer:(NSTimer *)timer
{
    if (mMIDIControl.err != noErr)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"midiReadProc error = %i (%@)",
              mMIDIControl.err, statusToString(mMIDIControl.err));
        
        NSString *message = [[NSString alloc]
            initWithFormat:@"MIDI read error = %i (%@)",
            mMIDIControl.err, statusToString(mMIDIControl.err)];
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:message];
        [alert setAlertStyle:NSAlertStyleCritical];

        mMIDIControl.err = noErr;
    }
}

@end
