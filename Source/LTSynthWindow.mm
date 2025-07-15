//
// LTSynthWindow.mm
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

#import <CoreAudio/CoreAudio.h>
#import <CoreAudioKit/CoreAudioKit.h>
#import <AudioUnit/AUCocoaUIView.h>

#import <CoreMIDI/CoreMIDI.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "CAComponent.h"
#import "CAComponentDescription.h"
#import "CAStreamBasicDescription.h"

#import "LTSynthWindow.h"


@implementation LTSynthWindow

+ (BOOL)plugInClassIsValid:(Class)pluginClass
{
    if ([pluginClass conformsToProtocol:@protocol(AUCocoaUIBase)])
    {
        if ([pluginClass instancesRespondToSelector:
             @selector(interfaceVersion)] &&
            [pluginClass instancesRespondToSelector:
             @selector(uiViewForAudioUnit:withSize:)])
        {
            return YES;
        }
    }
    
    return NO;
}

- (id)initWithLogHandle:(os_log_t)log withLogFile:(NSString *)logFile
{
    if ((self = [super init]))
    {
        mLog = log;
        mLogFile = [logFile copy];
        
        // Create AU window and view objects
        mAUWindow = [[NSWindow alloc] init];
        mAUView = [[NSView alloc] init];
    }

    return self;
}

- (void)closeViewForAU
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
      name:NSViewFrameDidChangeNotification object:mAUView];
    [mAUView removeFromSuperview];
    [mAUWindow setIsVisible:false];
}

- (void)setAUViewLocation:(NSRect)frame
{
    float mx = frame.origin.x;
    float my = frame.origin.y;
    [mAUWindow setFrameTopLeftPoint:NSMakePoint(mx, my)];
}

- (void)centerAUView
{
    [mAUWindow center];
}

- (void)setAUViewSize
{
    NSRect auFrame = [mAUView frame];

    NSSize newContentSize;
    newContentSize.width = auFrame.size.width;
    newContentSize.height = auFrame.size.height;
    
    [mAUWindow setContentSize:newContentSize];

    auFrame.origin = mLastAUFrame.origin;
    [mAUView setFrame:auFrame];
    mLastAUFrame = auFrame;
}

- (void)auViewFrameDidChange:(NSNotification *)notification
{
    if (mAUView != [notification object])
    {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
        name:NSViewFrameDidChangeNotification object:mAUView];
    
    [self setAUViewSize];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(auViewFrameDidChange:)
        name:NSViewFrameDidChangeNotification object:mAUView];
}

- (void)showViewForAU:(AudioUnit)inAU withName:(NSString *)displayName
{
    // Get AU's Cocoa view property
    UInt32 dataSize;
    Boolean isWritable;
    AudioUnitCocoaViewInfo *cocoaViewInfo = NULL;
    
    OSStatus result = AudioUnitGetPropertyInfo(inAU,
                                               kAudioUnitProperty_CocoaUI,
                                               kAudioUnitScope_Global, 0,
                                               &dataSize, &isWritable);
    
    UInt32 numberOfClasses = (dataSize - sizeof(CFURLRef)) /
                             sizeof(CFStringRef);
    
    NSURL *CocoaViewBundlePath = nil;
    NSString *factoryClassName = nil;
    
    // Does view have custom Cocoa UI?
    if ((result == noErr) && (numberOfClasses > 0))
    {
        cocoaViewInfo = (AudioUnitCocoaViewInfo *)malloc(dataSize);
        
        if (AudioUnitGetProperty(inAU, kAudioUnitProperty_CocoaUI,
                                 kAudioUnitScope_Global, 0,
                                 cocoaViewInfo, &dataSize) == noErr)
        {
            CocoaViewBundlePath =
                (__bridge NSURL *)cocoaViewInfo->mCocoaAUViewBundleLocation;
            
            // We only take the first view
            factoryClassName =
                (__bridge NSString *)cocoaViewInfo->mCocoaAUViewClass[0];
        }
        else
        {
            if (cocoaViewInfo != NULL)
            {
                free(cocoaViewInfo);
                cocoaViewInfo = NULL;
            }
        }
    }
    else
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Get kAudioUnitProperty_CocoaUI error = %i (%@), "
              "numberOfClasses = %i",
              result, statusToString(result), numberOfClasses);
    }
    
    BOOL wasAbleToLoadCustomView = NO;
    
    // Show custom UI if view has it
    if (CocoaViewBundlePath && factoryClassName)
    {
        NSBundle *viewBundle =
            [NSBundle bundleWithPath:[CocoaViewBundlePath path]];

        if (viewBundle == nil)
        {
            LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"Error loading AU view's bundle");
        }
        else
        {
            Class factoryClass = [viewBundle classNamed:factoryClassName];

            if (factoryClass == nil)
            {
               LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                     @"Error getting AU view's factory class from bundle");
            }
            
            // Make sure 'factoryClass' implements the AUCocoaUIBase protocol
            if ([LTSynthWindow plugInClassIsValid:factoryClass] == YES)
            {
                // Make a factory
                id factoryInstance = [[factoryClass alloc] init];

                if (factoryInstance != nil)
                {
                    // Make a view
                    mAUView = [factoryInstance uiViewForAudioUnit:inAU
                               withSize:NSMakeSize(50, 50)];

                    if (mAUView != nil)
                    {
                        wasAbleToLoadCustomView = YES;
                    }
                }
                else
                {
                    LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                          @"Could not create an instance of "
                          "the AU view factory");
                }
            }
            else
            {
                LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                      @"AU view's factory class does not "
                       "properly implement the AUCocoaUIBase protocol");
            }
 
            // Cleanup
            if (cocoaViewInfo)
            {
                for (UInt32 i = 0; i < numberOfClasses; i++)
                {
                    CFRelease(cocoaViewInfo->mCocoaAUViewClass[i]);
                }
                
                free(cocoaViewInfo);
            }
        }
    }
    
    if (!wasAbleToLoadCustomView)
    {
        // Otherwise show generic Cocoa view
        mAUView = [[AUGenericView alloc] initWithAudioUnit:inAU];
        [(AUGenericView *)mAUView setShowsExpertParameters:YES];
    }
    
    // Display view
    [self setAUViewSize];
    [[mAUWindow contentView] addSubview:mAUView];
    mLastAUFrame = [mAUView frame];
    
    // Watch for size changes
    [[NSNotificationCenter defaultCenter]
        addObserver:self selector:@selector(auViewFrameDidChange:)
        name:NSViewFrameDidChangeNotification object:mAUView];

    // Set window title and order front
    [mAUWindow setTitle:displayName];
    [mAUWindow makeKeyAndOrderFront:self];
}

@end
