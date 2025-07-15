// 
// LTMidi.h
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

#ifndef LT_MIDI_H
#define LT_MIDI_H

// These typedefs are for JUCE-based projects
#ifndef Byte
    typedef unsigned char Byte;
#endif

#ifndef UInt8
    typedef unsigned char UInt8;
#endif

#ifndef UInt16
    typedef uint16 UInt16;
#endif

#ifndef UInt32
    typedef uint32 UInt32;
#endif

#ifndef UInt64
    typedef uint64 UInt64;
#endif

#ifndef MIDITimeStamp
    typedef uint64 MIDITimeStamp;
#endif


#define MIDI_NOTE_OFF        0x80
#define MIDI_NOTE_ON         0x90
#define MIDI_AFTER_TOUCH     0xA0
#define MIDI_CONTROL_CHANGE  0xB0
#define MIDI_SET_PARAMETER   0xB0
#define MIDI_PROGRAM_CHANGE  0xC0
#define MIDI_SET_PROGRAM     0xC0
#define MIDI_SET_PRESSURE    0xD0
#define MIDI_PITCH_WHEEL     0xE0
#define MIDI_SYSTEM_MSG      0xF0

#define MIDI_SYSEX           0xF0
#define MIDI_TCQF            0xF1
#define MIDI_SONG_POS        0xF2
#define MIDI_SONG_SELECT     0xF3
#define MIDI_TUNE_REQ        0xF6
#define MIDI_EOX             0xF7
#define MIDI_CLOCK           0xF8
#define MIDI_SEQ_START       0xFA
#define MIDI_SEQ_CONTINUE    0xFB
#define MIDI_SEQ_STOP        0xFC
#define MIDI_UNDEFINED       0xFD
#define MIDI_ACTIVE_SENSE    0xFE
#define MIDI_SYS_RESET       0xFF

#define MIDI_SOURCE_IN       1
#define MIDI_SOURCE_OUT      2
#define MIDI_DATA_SIZE       256
#define MIDI_PKT_LIST_SIZE   1024
#define MIDI_NUM_CHANNELS    16
#define GM_NUM_PATCHES       128
#define GM_NUM_CATEGORIES    16
#define GM_NUM_DRUM_KITS     9

struct LTMidiEvent
{
    MIDITimeStamp timeStamp;
    Byte source;
    UInt16 length;
    Byte data[MIDI_DATA_SIZE];
};

struct LTMidiRawData
{
    UInt32 length;
    UInt8 data[MIDI_DATA_SIZE];
};

struct LTSMFEvent
{
    Byte track;
    UInt64 deltaTime;
    UInt64 time;
    UInt16 length;
    UInt16 mlength;
    Byte status;
    Byte data[MIDI_DATA_SIZE];
    UInt32 ppqn;
    Byte keysig;
};

#define DEFAULT_BPM      120
#define DEFAULT_PPQN     24
#define DEFAULT_NBPM     4
#define DEFAULT_DBPM     4
#define DEFAULT_KEY_SIG  7

// MIDI status bytes
#define MIDI_CHNLNUM  0x0F
#define MIDI_CHNLMASK 0xF0
#define MIDI_STATUS   0x80

// Standard MIDI file meta event types
#define MIDI_META_EVENT   0xFF
#define TYPE_SEQ_NUM      0x00
#define TYPE_TEXT         0x01
#define TYPE_COPYRIGHT    0x02
#define TYPE_SEQ_NAME     0x03
#define TYPE_INS_NAME     0x04
#define TYPE_LYRIC        0x05
#define TYPE_MARKER       0x06
#define TYPE_CUE          0x07
#define TYPE_SELECT_PORT  0x21
#define TYPE_END          0x2F
#define TYPE_TEMPO        0x51
#define TYPE_SMPTE        0x54
#define TYPE_TIME_SIG     0x58
#define TYPE_KEY_SIG      0x59
#define TYPE_SEQ_SPEC     0x7F

// SMF MIDI states
enum MIDI_STATES
{
     DATA_BYTE_1,
     DATA_BYTE_2,
     DATA_BYTE_X,
     STAT_BYTE,
     STAT_BYTE_X,
     CLK_BYTE,
     CLK_BYTE_X,
     SYS_BYTE
};

// Time signatures
enum TIME_SIG
{
     TIME_SIG_UNK,
     TIME_SIG_2_4,
     TIME_SIG_3_4,
     TIME_SIG_4_4,
     TIME_SIG_5_4,
     TIME_SIG_6_8,
     TIME_SIG_9_8,
     TIME_SIG_12_8
};

static const char *noteNameFlat[] = { "C", "Db", "D", "Eb", "E", "F",
                                      "Gb", "G", "Ab", "A", "Bb", "B" };

static const char *noteNameSharp[] = { "C", "C#", "D", "D#", "E", "F",
                                       "F#", "G", "G#", "A", "A#", "B" };

static const char *keySig[] = { "Cb", "Gb", "Db", "Ab", "Eb",
                                "Bb", "F", "C", "G ", "D ",
                                "A ", "E ", "B ", "F#", "C#" };

static const char *gmPatchList[GM_NUM_PATCHES] =
{
    // Pianos
    "Acoustic Grand Piano",
    "Bright Acoustic Piano",
    "Electric Grand Piano",
    "Honky-Tonk Piano",
    "Electric Piano 1",
    "Electric Piano 2",
    "Harpsichord",
    "Clavinet",

    // Chromatic Percussion
    "Celesta",
    "Glockenspiel",
    "Music Box",
    "Vibraphone",
    "Marimba",
    "Xylophone",
    "Tubular Bells",
    "Dulcimer",

    // Organs
    "Draw Organ",
    "Percussive Organ",
    "Rock Organ",
    "Church Organ",
    "Reed Organ",
    "Accordian",
    "Harmonica",
    "Tango Accordian",

    // Guitars
    "Acoustic Guitar (Nylon)",
    "Acoustic Guitar (Steel)",
    "Electric Guitar (Jazz)",
    "Electric Guitar (Clean)",
    "Electric Guitar (Muted)",
    "Overdriven Guitar",
    "Distortion Guitar",
    "Guitar Harmonics",

    // Basses
    "Acoustic Bass",
    "Electric Bass (Finger)",
    "Electric Bass (Picked)",
    "Fretless Bass",
    "Slap Bass 1",
    "Slap Bass 2",
    "Synth Bass 1",
    "Synth Bass 2",

    // Strings
    "Violin",
    "Viola",
    "Cello",
    "Contrabass",
    "Tremolo Strings",
    "Pizzicato Strings",
    "Orchestral Harp",
    "Timpani",

    // Ensembles
    "String Ensemble 1",
    "String Ensemble 2",
    "Synth Strings 1",
    "Synth Strings 2",
    "Choir Ahhs",
    "Voice Oohs",
    "Synth Voice",
    "Orchestra Hit",

    // Brass
    "Trumpet",
    "Trombone",
    "Tuba",
    "Muted Trumpet",
    "French Horn",
    "Brass Section",
    "Synth Brass 1",
    "Synth Brass 2",

    // Reeds
    "Soprano Sax",
    "Alto Sax",
    "Tenor Sax",
    "Baritone Sax",
    "Oboe",
    "English Horn",
    "Bassoon",
    "Clarinet",
 
    // Pipes
    "Picclo",
    "Flute",
    "Recorder",
    "Pan Flute",
    "Bottle Blow",
    "Shakuhachi",
    "Whistle",
    "Ocarina",
 
    // Synth Lead
    "Lead 1 (Square)",
    "Lead 2 (Sawtooth)",
    "Lead 3 (Calliope)",
    "Lead 4 (Chiff)",
    "Lead 5 (Charang)",
    "Lead 6 (Voice)",
    "Lead 7 (Fifths)",
    "Lead 8 (Bass+Lead)",
 
    // Synth Pads
    "Pad 1 (New Age)",
    "Pad 2 (Warm)",
    "Pad 3 (Polysynth)",
    "Pad 4 (Choir)",
    "Pad 5 (Bowed)",
    "Pad 6 (Metallic)",
    "Pad 7 (Halo)",
    "Pad 8 (Sweep)",

    // Synth FX
    "FX 1 (Rain)",
    "FX 2 (Soundtrack)",
    "FX 3 (Crystal)",
    "FX 4 (Atmosphere)",
    "FX 5 (Brightness)",
    "FX 6 (Goblins)",
    "FX 7 (Echoes)",
    "FX 8 (Sci-fi)",

    // Ethnic
    "Sitar",
    "Banjo",
    "Shamisen",
    "Koto",
    "Kalimba",
    "Bagpipe",
    "Fiddle",
    "Shanai",

    // Percussive
    "Tinkle Bell",
    "Agogo",
    "Steel Drums",
    "Woodblock",
    "Taiko Drum",
    "Melodic Tom",
    "Synth Drum",
    "Reverse Cymbal",

    // FX
    "Guitar Fret Noise",
    "Breath Noise",
    "Seashore",
    "Bird Tweet",
    "Telephone Ring",
    "Helicopter",
    "Applause",
    "Gunshot"
};

static const char *gmCategoryList[GM_NUM_CATEGORIES] =
{
    "Piano",
    "Chromatic Percussion",
    "Organ",
    "Guitar",
    "Bass",
    "Strings",
    "Ensemble",
    "Brass",
    "Reed",
    "Pipe",
    "Synth Lead",
    "Synth Pad",
    "Synth Effects",
    "Ethnic",
    "Percussive",
    "Sound Effects"
};

static const char *gmDrumKitList[GM_NUM_DRUM_KITS] =
{
    "Standard",
    "Room",
    "Power",
    "Electronic",
    "TR-808",
    "Jazz",
    "Brush",
    "Orchestra",
    "SFX"
};

static const char *gmDrums[128] =
{
    "???",   // C0
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",   // C1
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",
    "???",   // C2 = 24
    "???",
    "???",
    "High Q",
    "Slap",
    "Scratch Push",
    "Scratch Pull",
    "Sticks",
    "Square Click",
    "Metronome Click",
    "Metronome Bell",
    "Acoustic Bass Drum",
    "Bass Drum",         // C3 = 36
    "Side Stick",
    "Acoustic Snare",
    "Hand Clap",
    "Electric Snare",
    "Low Floor Tom",
    "Closed Hi-Hat",
    "High Floor Tom",
    "Pedal Hi-Hat",
    "Low Tom",
    "Open Hi-Hat",
    "Low-Mid Tom",
    "High-Mid Tom",      // C4 = 48
    "Crash Cymbal 1",
    "High Tom",
    "Ride Cymbal 1",
    "Chinese Cymbal",
    "Ride Bell",
    "Tambourine",
    "Splash Cymbal",
    "Cowbell",
    "Crash Cymbal 2",
    "Vibra Slap",
    "Ride Cymbal 2",
    "Hi Bongo",          // C5 = 60
    "Lo Bongo",
    "Mute High Conga",
    "Open High Conga",
    "Low Conga",
    "High Timbale",
    "Low Timbale",
    "High Agogo",
    "Low Agogo",
    "Cabasa",
    "Maracas",
    "Short Whistle",
    "Long Whistle",      // C6 = 72
    "Short Guiro",
    "Long Guiro",
    "Claves",
    "High Wood Block",
    "Low Wood Block",
    "Mute Cuica",
    "Open Cuica",
    "Mute Triangle",
    "Open Triangle",
    "Shaker",
    "Jingle Bell",
    "Bell Tree",         // C7
    "Castanets",
    "Mute Surdo",
    "Open Surdo"
};

static const char *ccList[] =
{
    "Bank Select",
    "Modulation Depth",
    "Breath Controller",
    "Undefined",
    "Foot Controller",
    "Portamento Time",
    "Date Entry",
    "Volume",
    "Balance",
    "Undefined",
    "Pan",
    "Expression",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "General Purpose 1",
    "General Purpose 2",
    "General Purpose 3",
    "General Purpose 4",
 
    // 20-31 are undefined
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
 
    // LSB for control changes 0-31 and 32-63
    "LSB 32", "LSB 33", "LSB 34", "LSB 35", "LSB 36", "LSB 37", "LSB 38",
    "LSB 39", "LSB 40", "LSB 41", "LSB 42", "LSB 43", "LSB 44", "LSB 45",
    "LSB 46", "LSB 47", "LSB 48", "LSB 49", "LSB 50", "LSB 51", "LSB 52",
    "LSB 53", "LSB 54", "LSB 55", "LSB 56", "LSB 57", "LSB 58", "LSB 59",
    "LSB 60", "LSB 61", "LSB 62", "LSB 63",

    "Sustain Pedal",
    "Portamento",
    "Sustenuto Pedal",
    "Soft Pedal",
    "Legato Switch",
    "Hold 2",
    "Sound Variation",
    "Harm Content",
    "Release Time",
    "Attack Time",
    "Brightness",
    "Reverb",
    "Delay",
    "Pitch Transpose",
    "Flange",
    "Special FX",
    "General Purpose 5",
    "General Purpose 6",
    "General Purpose 7",
    "General Purpose 8",
    "Portamento Control",
 
    // 85-90 are undefined
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Reverb Depth",
    "Tremolo Depth",
    "Chorus Depth",
    "Celeste Depth",
    "Phaser Depth",
    "Data Increment",
    "Data Decrement",
    "Non Reg Param LSB",
    "Non Reg Param MSB",
    "Reg Param LSB",
    "Reg Param MSB",
 
    // 102-119 are undefined
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
    "Undefined",
 
    "All Sound Off",
    "Reset All Controllers",
    "Local Control",
    "All Notes Off",
    "Omni Mode Off",
    "Omni Mode On",
    "Mono Mode On",
    "Poly Mode On"
};

#endif  // LTMIDI_H
