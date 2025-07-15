// 
// LTAudioUnitData.h
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
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>

#import "LTLog.h"

@interface LTAudioUnitData : NSObject
{
}

@property NSString *AUName;
@property NSString *company;
@property NSString *name;
@property NSString *type;
@property NSString *arch;
@property NSString *compType;
@property NSString *subtype;
@property NSString *manu;
@property NSString *sandbox;
@property NSString *async;
@property NSString *inProc;
@property NSString *auVersion;
@property NSString *version;
@property NSNumber *component;
@property NSString *minOS;
@property AudioComponentDescription desc;

- (id)initWithComponent:(AudioComponent)comp;

@end
