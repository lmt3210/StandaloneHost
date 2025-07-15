// 
// LTAudioUnitData.m
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

#import "LTAudioUnitData.h"

@implementation LTAudioUnitData

- (id)initWithComponent:(AudioComponent)comp
{
    if ((self = [super init]))
    {
        // Save component reference, get name, etc.
        self.component = [NSNumber numberWithUnsignedLong:(unsigned long)comp];
        CFStringRef auNameCF;
        AudioComponentCopyName(comp, &auNameCF);
        self.AUName = (__bridge NSString *)auNameCF;
        
        AudioComponentDescription audesc = { 0 };
        AudioComponentGetDescription(comp, &audesc);
        self.desc = audesc;
        self.arch = @"N/A";
        self.minOS = @"?";
        self.compType = statusToString(audesc.componentType);
        self.subtype = statusToString(audesc.componentSubType);
        self.manu = statusToString(audesc.componentManufacturer);
        NSArray *pieces = [self.AUName componentsSeparatedByString:@":"];
        
        if ([pieces count] == 2)
        {
            if ([[pieces[1] substringToIndex:1] isEqualToString:@" "])
            {
                self.name = [pieces[1] substringFromIndex:1];
            }
            else
            {
                self.name = [pieces[1] copy];
            }

            self.company = [pieces[0] copy];
        }
        else
        {
            self.name = [pieces[0] copy];
            
            if ([self.manu isEqualToString:@"appl"] == YES)
            {
                self.company = @"Apple";
            }
            else
            {
                self.company = @"System";
            }
        }
    
        self.sandbox = (audesc.componentFlags &
                        kAudioComponentFlag_SandboxSafe) ?  @"Yes" : @"No";
        self.async = (audesc.componentFlags &
                      kAudioComponentFlag_RequiresAsyncInstantiation) ?
                      @"Yes" : @"No";
        self.inProc = (audesc.componentFlags &
                       kAudioComponentFlag_CanLoadInProcess) ?  @"Yes" : @"No";
        self.auVersion = (audesc.componentFlags &
                          kAudioComponentFlag_IsV3AudioUnit) ?  @"V3" : @"V2";

        switch(audesc.componentType)
        {
            case kAudioUnitType_Output:
                self.type = @"Output";
                break;
            case kAudioUnitType_MusicDevice:
                self.type = @"Music Device";
                break;
            case kAudioUnitType_MusicEffect:
                self.type = @"Music Effect";
                break;
            case kAudioUnitType_FormatConverter:
                self.type = @"Format Converter";
                break;
            case kAudioUnitType_Effect:
                self.type = @"Effect";
                break;
            case kAudioUnitType_Mixer:
                self.type = @"Mixer";
                break;
            case kAudioUnitType_Panner:
                self.type = @"Panner";
                break;
            case kAudioUnitType_Generator:
                self.type = @"Generator";
                break;
            case kAudioUnitType_OfflineEffect:
                self.type = @"Offline Effect";
                break;
            case kAudioUnitType_MIDIProcessor:
                self.type = @"MIDI Processor";
                break;
            default:
                self.type = @"Other";
                break;
        }
        
        UInt32 theVersionNumber = 0;
        AudioComponent component = AudioComponentFindNext(0, &audesc);
        AudioComponentGetVersion(component, &theVersionNumber);
        self.version = [NSString stringWithFormat:@"%i.%i.%i",
                       ((theVersionNumber >> 16) & 0x0000ffff),
                       ((theVersionNumber >> 8) & 0x000000ff),
                        (theVersionNumber & 0x000000ff)];
    }

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    LTAudioUnitData *au = [[[self class] allocWithZone:zone] init];
    
    au.AUName = [self.AUName copyWithZone:zone];
    au.company = [self.company copyWithZone:zone];
    au.name = [self.name copyWithZone:zone];
    au.type = [self.type copyWithZone:zone];
    au.arch = [self.arch copyWithZone:zone];
    au.compType = [self.compType copyWithZone:zone];
    au.subtype = [self.subtype copyWithZone:zone];
    au.manu = [self.manu copyWithZone:zone];
    au.sandbox = [self.sandbox copyWithZone:zone];
    au.async = [self.async copyWithZone:zone];
    au.inProc = [self.inProc copyWithZone:zone];
    au.auVersion = [self.auVersion copyWithZone:zone];
    au.version = [self.version copyWithZone:zone];
    au.component = [self.component copyWithZone:zone];
    au.minOS = [self.minOS copyWithZone:zone];
    au.desc = self.desc;

    return au;
}

@end
