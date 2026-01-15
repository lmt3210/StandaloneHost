//
// Synths.h
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

struct synthDefinition
{
    NSString *appName;  // The name we are running as, same as component bundle
                        // name (which will not be StandaloneHost if renamed)
                        // or actual AU name if known synth
    NSString *auName;   // The AU name as returned from Component Manager
                        // using GetAUName
    OSType mfg;
    OSType subtype;
};

const struct synthDefinition knownSynths[] =
{
    { @"AX73", @"AX73", 'Mnic', 'ax73' },
    { @"Martinic AX73", @"AX73", 'Mnic', 'ax73' },
    { @"D-50", @"D-50", 'RoCl', 'Vds0' },
    { @"ESP", @"Expanded Softsynth Plugin for MONTAGE M-MODX M", 'Ymau', 'eSMm' },
    // FB-3100 AudioComponents dictionary returns wrong manufacturer 
    // and subtype
    { @"FB3100", @"FB-3100", 'FuBu', 'FB31' },
    { @"FB-3100", @"FB-3100", 'FuBu', 'FB31' },
    // FB-3200 AudioComponents dictionary returns wrong manufacturer 
    // and subtype
    { @"FB3200", @"FB-3200", 'FuBu', 'FB32' },
    { @"FB-3200", @"FB-3200", 'FuBu', 'FB32' },
    // FB-3300 AudioComponents dictionary returns wrong manufacturer 
    // and subtype
    { @"FB3300", @"FB-3300", 'FuBu', 'fb33' },
    { @"FB-3300", @"FB-3300", 'FuBu', 'fb33' },
    // FB-7999 AudioComponents dictionary returns wrong manufacturer 
    // and subtype
    { @"FB7999", @"FB-7999", 'FuBu', 'fb79' },
    { @"FB-7999", @"FB-7999", 'FuBu', 'fb79' },
    // Fury 800 AudioComponents dictionary returns wrong manufacturer 
    // and subtype
    { @"Fury800", @"Fury-800", 'FuBu', 'f800' },
    { @"Fury-800", @"Fury-800", 'FuBu', 'f800' },
    // Kern does not have an AudioComponents dictionary in Info.plist
    { @"Kern", @"Kern", 'FuBu', 'kern' },
    { @"MS-20", @"MS-20", 'KORG', 'KLMV' },
    // Minimonsta does not have an AudioComponents dictionary in Info.plist
    { @"Minimonsta", @"Minimonsta", 'GFor', 'OMii' },
    { @"Minimonsta_AUMachO", @"Minimonsta", 'GFor', 'OMii' },
    // Nave does not have an AudioComponents dictionary in Info.plist
    { @"Nave", @"Nave", 'Wald', 'nave' },
    // Oddity does not have an AudioComponents dictionary in Info.plist
    { @"Oddity2", @"Oddity2", 'GFor', 'OOd2' },
    { @"Oddity2_AUMachO", @"Oddity2", 'GFor', 'OOd2' },
    // OP-X PRO does not have an AudioComponents dictionary in Info.plist
    { @"OP-X PRO-II", @"OP-X PRO-II", 'Sopr', 'OPPU' },
    // PPG Wave does not have an AudioComponents dictionary in Info.plist
    { @"PPG Wave", @"PPG Wave", '3E00', '2901' },
    { @"PPG Wave 3.V", @"PPG Wave", '3E00', '2901' },
    { @"Rapture Pro", @"Rapture Pro", 'CWSY', 'rpro' },
    { @"RapturePro", @"Rapture Pro", 'CWSY', 'rpro' },
    { @"SOUND Canvas", @"SOUND Canvas", 'RoCl', 'Sc55' },
    { @"SOUND Canvas VA", @"SOUND Canvas", 'RoCl', 'Sc55' },
    { @"SynthMaster1", @"SynthMaster One", 'k331', 'Sm1i' },
    { @"SynthMaster2", @"SynthMaster 2", 'k331', 'Sm2i' },
    { @"SYSTEM-100", @"SYSTEM-100", 'RoCl', 'Vas3' },
    // Vacuum Pro does not have an AudioComponents dictionary in Info.plist
    { @"Vacuum Pro", @"Vacuum Pro", 'Wzoo', 'VacP' },
    { @"VacuumPro", @"Vacuum Pro", 'Wzoo', 'VacP' },
    { @"Z3TA+2", @"Z3TA+ 2", 'CWSY', 'samp' },
    { @"Z3TA+ 2", @"Z3TA+ 2", 'CWSY', 'samp' },
    { @"ZENOLOGY", @"ZENOLOGY", 'RoCl', 'Px00' }
};
