//
// AppDelegate.mm
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
#import <sys/utsname.h>

#import "CAComponent.h"
#import "CAComponentDescription.h"
#import "CAStreamBasicDescription.h"

#import "SynthWindowController.h"
#import "SettingsWindowController.h"
#import "SequencerWindowController.h"
#import "LTAudioUnitData.h"
#import "LTPopup.h"
#import "LTVersionCheck.h"
#import "AppDelegate.h"
#import "NSFileManager+DirectoryLocations.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notify
{
    // Get app name (from possible renamed bundle directory, not Info.plist)
    NSBundle *appBundle = [NSBundle mainBundle];
    NSURL *appURL = [appBundle bundleURL];
    mAppName = [[appURL lastPathComponent] substringWithRange:
                NSMakeRange(0, [appURL lastPathComponent].length - 4)];
    
#ifdef LT_TEST_APP_ON
    mAppName = @"StandaloneHost";
#endif
    
    // Set up logging
    mLog = os_log_create("com.larrymtaylor.StandaloneHost", "AppDelegate");
    NSString *path =
        [[NSFileManager defaultManager] applicationSupportDirectory];
    mLogFile = [[NSString alloc] initWithFormat:@"%@/logFile.txt", path];
    UInt64 fileSize = [[[NSFileManager defaultManager]
                        attributesOfItemAtPath:mLogFile error:nil] fileSize];
    
    if (fileSize > (1024 * 1024))
    {
        [[NSFileManager defaultManager] removeItemAtPath:mLogFile error:nil];
    }
    
    // Get macOS version
    NSOperatingSystemVersion sysVersion =
        [[NSProcessInfo processInfo] operatingSystemVersion];
    NSString *systemVersion = [NSString stringWithFormat:@"%ld.%ld",
                               sysVersion.majorVersion,
                               sysVersion.minorVersion];
    
    // Log some basic information
    NSDictionary *appInfo = [appBundle infoDictionary];
    NSString *appVersion =
        [appInfo objectForKey:@"CFBundleShortVersionString"];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM/dd/yyyy h:mm a"];
    NSString *day = [dateFormatter stringFromDate:[NSDate date]];
    struct utsname osinfo;
    uname(&osinfo);
    NSString *info = [NSString stringWithUTF8String:osinfo.version];
    LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
          @"\nStandaloneHost v%@ running with name \"%@\" on macOS "
          "%@ (%@)\n%@", appVersion, mAppName, systemVersion, day, info);
    
    // Setup popup window
    mPopupWindow = [[LTPopup alloc] initWithWindowNibName:@"LTPopup"];
    
    // Setup SMF playback window
    mSequenceWindow = [[SequencerWindowController alloc]
                       initWithWindowNibName:@"SequencerWindowController"];
    [mSequenceWindow loadWindow];
    [mSequenceWindow initSMFPlayback];
    
    // Create record storage directory if needed
    struct passwd *pw = getpwuid(getuid());
    NSString *realHomeDir = [NSString stringWithUTF8String:pw->pw_dir];
    NSMutableString *directory =
        [[NSMutableString alloc] initWithString:realHomeDir];
    [directory appendString:@"/Music/StandaloneHost/"];
    
    NSFileManager *fileManager= [NSFileManager defaultManager];
    NSError *error = nil;
    
    if ([fileManager createDirectoryAtPath:directory
               withIntermediateDirectories:YES attributes:nil
                                     error:&error] == NO)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Failed to create directory %@, error = %@", directory, error);
    }
    
    // Create the settings window controller
    mSettingsWindow = [[SettingsWindowController alloc]
                       initWithWindowNibName:@"SettingsWindowController"];
    
    // Initialize the settings
    [mSettingsWindow loadWindow];
    [mSettingsWindow initSettings:mAppName];
    
    // Initialize variables
    mSynthWindow = nil;
    
    // Check to see if we have been renamed
    if ([mAppName isEqualToString:@"StandaloneHost"] == YES)
    {
        // Not renamed, so let the user select
        [mSynthMenu setEnabled:YES];
        [mSynthMenu setHidden:NO];
        [mMFXMenu setEnabled:YES];
        [mMFXMenu setHidden:NO];

        // Populate lists
        [self populateSynthList];
        [self populateMFXList];
    }
    else
    {
        // No need to allow selection
        [mSynthMenu setEnabled:NO];
        [mSynthMenu setHidden:YES];
        [mMFXMenu setEnabled:NO];
        [mMFXMenu setHidden:YES];

        // Update the main menu
        NSMenu *menu = [[[NSApp mainMenu] itemAtIndex:0] submenu];
        [menu setTitle:mAppName];
        
        // Setup the synth window
        [self launchSynth];
    }
    
    // Start version check
    mVersionCheck = [[LTVersionCheck alloc] initWithAppName:@"StandaloneHost"
                     withAppVersion:appVersion
                     withLogHandle:mLog withLogFile:mLogFile];
}

- (IBAction)synthSelect:(id)sender
{
    NSMenuItem *synthMenu = (NSMenuItem *)sender;
    mAppName = [synthMenu title];
    [self launchSynth];
}

- (void)launchSynth
{
    NSMutableString *text = [[NSMutableString alloc] init];

    // Close any previous selected synth
    if (mSynthWindow != nil)
    {
        [mSynthWindow cleanup];
        mSynthWindow = nil;
    }

    // Create the synth window controller
    mSynthWindow = [[SynthWindowController alloc] init];

    // Load the synth
    synthStatus status = [mSynthWindow loadSynth:mAppName];

    // Send the settings to the synth window controller
    [mSettingsWindow sendSettings];

    // Display popups if needed
    if (status == SYNTH_STATUS_NOT_SUPPORTED)
    {
        [text setString:mAppName];
        [text appendString:@" is not supported. "];
        [text appendString:@" Loaded the Apple DLS Music Device instead."];
        [mPopupWindow show];
        [mPopupWindow setText:(NSString *)text];
    }
    else if (status == SYNTH_STATUS_UNKNOWN)
    {
        [text setString:mAppName];
        [text appendString:@" component not found, check for typos. "];
        [text appendString:@" Loaded the Apple DLS Music Device instead."];
        [mPopupWindow show];
        [mPopupWindow setText:(NSString *)text];
    }
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return TRUE;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)inSender
{
    return NO;
}

- (void)applicationWillTerminate:(NSNotification *)notify
{
    [mSynthWindow cleanup];
    [mSettingsWindow cleanup];
}

- (IBAction)showSettingsWindow:(id)sender
{
    [mSettingsWindow showWindow:self];
}

- (IBAction)showSMFPlaybackWindow:(id)sender
{
    [mSequenceWindow show];
}

- (int)componentCountForAUType:(OSType)inAUType
{
    CAComponentDescription desc = CAComponentDescription(inAUType);
    return desc.Count();
}

- (void)populateSynthList
{
    // Get info on all synth AUs installed
    NSMutableArray *audioUnits =[[NSMutableArray alloc] init];
    long AUCount = 0;
    AudioComponentDescription desc = { 0 };
    desc.componentType = kAudioUnitType_MusicDevice;
    AUCount = AudioComponentCount(&desc);
    AudioComponent last = NULL;
    
    for (int i = 0; i < AUCount; ++i)
    {
        AudioComponent comp = AudioComponentFindNext(last, &desc);
        last = comp;
        AudioComponentDescription audesc = { 0 };
        AudioComponentGetDescription(comp, &audesc);
        NSString *mfg = statusToString(audesc.componentManufacturer);

        // Omit synths from known vendors with vendor-supplied standalone apps
        if (([mfg isEqualToString:@"Artu"] == NO) &&
            ([mfg isEqualToString:@"Chry"] == NO) &&
            ([mfg isEqualToString:@"KORG"] == NO) &&
            ([mfg isEqualToString:@"-NI-"] == NO))
        {
            LTAudioUnitData *auData =
            [[LTAudioUnitData alloc] initWithComponent:comp];
            [audioUnits addObject:auData];
        }
    }
    
    // Update count
    AUCount = [audioUnits count];
    
    // Get sorted list of manufacturers
    NSMutableArray *manufacturers = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < AUCount; i++)
    {
        LTAudioUnitData *auData =
            (LTAudioUnitData *)[audioUnits objectAtIndex:i];
        [manufacturers addObject:auData.company];
    }
    
    NSArray *uniqueManufacturers =
        [[NSSet setWithArray:manufacturers] allObjects];
    NSArray *sortedManufacturers =
        [uniqueManufacturers sortedArrayUsingSelector:@selector
         (localizedCaseInsensitiveCompare:)];
    
    // Populate the "All" menu
    NSMenu *csmi = [[NSMenu alloc] initWithTitle:@"All"];
    NSMenuItem *cmi = [mSynthSelectMenu addItemWithTitle:@"All" action:nil
                       keyEquivalent:@""];
    [mSynthSelectMenu setSubmenu:csmi forItem:cmi];
    NSMutableArray *synths = [[NSMutableArray alloc] init];
    
    for (int j = 0; j < AUCount; j++)
    {
        LTAudioUnitData *auData =
            (LTAudioUnitData *)[audioUnits objectAtIndex:j];
        [synths addObject:auData.name];
    }

    NSArray *sortedSynths =
        [synths sortedArrayUsingSelector:@selector
         (localizedCaseInsensitiveCompare:)];
    
    for (int j = 0; j < [sortedSynths count]; j++)
    {
        NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:sortedSynths[j]
                          action:@selector(synthSelect:) keyEquivalent:@""];
        [csmi addItem:mi];
    }
    
    // Populate company menus
    for (int i = 0; i < [sortedManufacturers count]; i++)
    {
        NSString *company = sortedManufacturers[i];
        NSMenu *csmi = [[NSMenu alloc] initWithTitle:company];
        NSMenuItem *cmi = [mSynthSelectMenu addItemWithTitle:company
                           action:nil keyEquivalent:@""];
        [mSynthSelectMenu setSubmenu:csmi forItem:cmi];

        // Get sorted list of synth names for this company
        NSMutableArray *synths = [[NSMutableArray alloc] init];
        
        for (int j = 0; j < AUCount; j++)
        {
            LTAudioUnitData *auData =
                (LTAudioUnitData *)[audioUnits objectAtIndex:j];
        
            if ([company isEqualToString:auData.company])
            {
                [synths addObject:auData.name];
            }
        }

        NSArray *sortedSynths =
            [synths sortedArrayUsingSelector:@selector
             (localizedCaseInsensitiveCompare:)];
        
        for (int j = 0; j < [sortedSynths count]; j++)
        {
            NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:sortedSynths[j]
                              action:@selector(synthSelect:)
                              keyEquivalent:@""];
            [csmi addItem:mi];
        }
    }
}

- (void)populateMFXList
{
    // Get info on all MFX AUs installed
    NSMutableArray *audioUnits =[[NSMutableArray alloc] init];
    int AUCount = 0;
    AudioComponentDescription desc = { 0 };
    desc.componentType = kAudioUnitType_MIDIProcessor;
    AUCount = AudioComponentCount(&desc);
    AudioComponent last = NULL;
    
    for (int i = 0; i < AUCount; ++i)
    {
        AudioComponent comp = AudioComponentFindNext(last, &desc);
        last = comp;
        LTAudioUnitData *auData =
            [[LTAudioUnitData alloc] initWithComponent:comp];
        [audioUnits addObject:auData];
    }
    
    // Get sorted list of manufacturers
    NSMutableArray *manufacturers = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < AUCount; i++)
    {
        LTAudioUnitData *auData =
            (LTAudioUnitData *)[audioUnits objectAtIndex:i];
        [manufacturers addObject:auData.company];
    }
    
    NSArray *uniqueManufacturers =
        [[NSSet setWithArray:manufacturers] allObjects];
    NSArray *sortedManufacturers =
        [uniqueManufacturers sortedArrayUsingSelector:@selector
         (localizedCaseInsensitiveCompare:)];
    
    // Populate the "All" menu
    NSMenu *csmi = [[NSMenu alloc] initWithTitle:@"All"];
    NSMenuItem *cmi = [mMFXSelectMenu addItemWithTitle:@"All" action:nil
                       keyEquivalent:@""];
    [mMFXSelectMenu setSubmenu:csmi forItem:cmi];
    NSMutableArray *mfxs = [[NSMutableArray alloc] init];
    
    for (int j = 0; j < AUCount; j++)
    {
        LTAudioUnitData *auData =
            (LTAudioUnitData *)[audioUnits objectAtIndex:j];
        [mfxs addObject:auData.name];
    }

    NSArray *sortedMFXs =
        [mfxs sortedArrayUsingSelector:@selector
         (localizedCaseInsensitiveCompare:)];
    
    for (int j = 0; j < [sortedMFXs count]; j++)
    {
        NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:sortedMFXs[j]
                          action:@selector(synthSelect:) keyEquivalent:@""];
        [csmi addItem:mi];
    }
    
    // Populate company menus
    for (int i = 0; i < [sortedManufacturers count]; i++)
    {
        NSString *company = sortedManufacturers[i];
        NSMenu *csmi = [[NSMenu alloc] initWithTitle:company];
        NSMenuItem *cmi = [mMFXSelectMenu addItemWithTitle:company
                           action:nil keyEquivalent:@""];
        [mMFXSelectMenu setSubmenu:csmi forItem:cmi];

        // Get sorted list of synth names for this company
        NSMutableArray *mfxs = [[NSMutableArray alloc] init];
        
        for (int j = 0; j < AUCount; j++)
        {
            LTAudioUnitData *auData =
                (LTAudioUnitData *)[audioUnits objectAtIndex:j];
        
            if ([company isEqualToString:auData.company])
            {
                [mfxs addObject:auData.name];
            }
        }

        NSArray *sortedMFXs =
            [mfxs sortedArrayUsingSelector:@selector
             (localizedCaseInsensitiveCompare:)];
        
        for (int j = 0; j < [sortedMFXs count]; j++)
        {
            NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:sortedMFXs[j]
                              action:@selector(synthSelect:)
                              keyEquivalent:@""];
            [csmi addItem:mi];
        }
    }
}

@end
