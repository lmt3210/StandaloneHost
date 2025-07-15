//
// LTMidiCallbacks.mm
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

#import "LTMidiCallbacks.h"


// This callback happens on the main thread, so ok to use notifications
void midiNotifyProc(const MIDINotification *message, void *refCon)
{
    if (message->messageID == kMIDIMsgSetupChanged)
    {
        [[NSNotificationCenter defaultCenter]
          postNotificationName:@"LTMIDINotification" object:nil];
    }
}

// This callback happens on a separate, high-priority thread
OSStatus getBeatAndTempo(void *userData, Float64 *outBeat, Float64 *outTempo)
{
    struct LTCallbackData *cd = (struct LTCallbackData *)userData;
    
    if (outBeat != NULL)
    {
        *outBeat = cd->beat;
    }
    
    if (outTempo != NULL)
    {
        *outTempo = cd->tempo;
    }
    
    return noErr;
}

// This callback happens on a separate, high-priority thread
OSStatus renderNotifyProc(void *inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *inTimeStamp,
                          UInt32 inBusNumber, UInt32 inNumberFrames,
                          AudioBufferList *ioData)
{
    struct LTMIDIControl *mc = (struct LTMIDIControl *)inRefCon;
    
    if (*ioActionFlags & kAudioUnitRenderAction_PreRender)
    {
        for (int i = 0; i < inNumberFrames; i++)
        {
            if (mc->playTail != mc->playHead)
            {
                MusicDeviceMIDIEvent((MusicDeviceComponent)mc->synthUnit,
                                     mc->playData[mc->playTail].data[0],
                                     mc->playData[mc->playTail].data[1],
                                     mc->playData[mc->playTail].data[2], i);
                mc->playTail = (mc->playTail + 1) % kMaxPlayEvents;
            }
        }
    }

    return noErr;
}

// This callback happens on a separate, high-priority thread
void midiReadProc(const MIDIPacketList *inPktList, void *refCon,
                  void *connRefCon)
{
    struct LTMIDIControl *mc = (struct LTMIDIControl *)refCon;
    MIDIPacket *inPacket = (MIDIPacket *)inPktList->packet;

    for (int i = 0; i < inPktList->numPackets; i++)
    {
        UInt16 inPacketLength = inPacket->length;

#ifdef LT_MIDI_LOG
        LTLog(mc->log, LTLOG_NO_FILE, OS_LOG_TYPE_DEBUG,
              @"MIDI packet count = %d, packet #%d length = %d, "
              "timestamp = %ul", inPktList->numPackets, (i + 1),
              inPacketLength, inPacket->timeStamp);
        
        for (int k = 0; k < inPacketLength; k++)
        {
            LTLog(mc->log, LTLOG_NO_FILE, OS_LOG_TYPE_DEBUG,
                  @"MIDI packet #%d data[%d] = 0x%.2x", (i + 1), k,
                  inPacket->data[k]);
        }
#endif
        
        for (int j = 0; j < inPacketLength;)
        {
            Byte status = inPacket->data[j];
            Byte message = status & 0xF0;
            Byte channel = status & 0x0F;
            Byte data1 = inPacket->data[j + 1] & 0x7F;
            Byte data2 = inPacket->data[j + 2] & 0x7F;
            UInt16 eventLength = inPacketLength;
            BOOL sendEvent = false;
            
            switch (message)
            {
                case MIDI_NOTE_OFF:
                case MIDI_NOTE_ON:
                case MIDI_AFTER_TOUCH:
                    eventLength = 3;

                    if ((channel == mc->channel) || (mc->channel == -1))
                    {
                        if ((data1 >= mc->low) && (data1 <= mc->high))
                        {
                            data1 += mc->transpose;
                            sendEvent = true;
                        }
                    }

                    break;
                case MIDI_SET_PARAMETER:
                case MIDI_PITCH_WHEEL:
                    eventLength = 3;

                    if ((channel == mc->channel) || (mc->channel == -1))
                    {
                        sendEvent = true;
                    }

                    break;
                case MIDI_SET_PROGRAM:
                case MIDI_SET_PRESSURE:
                    eventLength = 2;

                    if ((channel == mc->channel) || (mc->channel == -1))
                    {
                        sendEvent = true;
                    }

                    break;
                case MIDI_SYSTEM_MSG:

                    switch (status)
                    {
                        case MIDI_SYSEX:
                            eventLength = inPacketLength;
                            break;
                        case MIDI_TCQF:
                        case MIDI_SONG_SELECT:
                            eventLength = 2;
                            break;
                        case MIDI_SONG_POS:
                            eventLength = 3;
                            break;
                        case MIDI_CLOCK:
                        case MIDI_ACTIVE_SENSE:
                        case MIDI_EOX:
                        case MIDI_TUNE_REQ:
                        case MIDI_SEQ_START:
                        case MIDI_SEQ_CONTINUE:
                        case MIDI_SEQ_STOP:
                        case MIDI_SYS_RESET:
                            eventLength = 1;
                            break;
                    }

                    break;
            }

#ifdef LT_MIDI_LOG
            LTLog(mc->log, LTLOG_NO_FILE, OS_LOG_TYPE_DEBUG,
                  @"MIDI current event length = %d", eventLength);
            LTLog(mc->log, LTLOG_NO_FILE, OS_LOG_TYPE_DEBUG,
                  @"Sending event with "
                  "status = 0x%.2x, data1 = 0x%.2x, data2 = 0x%.2x",
                  status, data1, data2);
#endif
 
            // Record if enabled
            if ((sendEvent == true) && (mc->recordEnable == 1) &&
                (mc->recordCount < kMaxRecordEvents))
            {
                mc->recordData[mc->recordCount].timeStamp =
                    inPacket->timeStamp;
                mc->recordData[mc->recordCount].length = eventLength;
                mc->recordData[mc->recordCount].data[0] = status;
                mc->recordData[mc->recordCount].data[1] =
                    inPacket->data[j + 1];
                mc->recordData[mc->recordCount].data[2] =
                    inPacket->data[j + 2];
                mc->recordCount++;
            }
            
            // Add to play buffer if event is playable
            if ((sendEvent == true) &&
                (((mc->playHead + 1) % kMaxPlayEvents) != mc->playTail))
            {
                mc->playData[mc->playHead].timeStamp = inPacket->timeStamp;
                mc->playData[mc->playHead].length = eventLength;
                mc->playData[mc->playHead].data[0] = status;;
                mc->playData[mc->playHead].data[1] = data1;
                mc->playData[mc->playHead].data[2] = data2;
                mc->playHead = (mc->playHead + 1) % kMaxPlayEvents;
            }
            
            j += eventLength;
        }

        inPacket = MIDIPacketNext(inPacket);
    }
}

// This callback happens on a separate, high-priority thread
OSStatus midiOutputProc(void *userData, const AudioTimeStamp *timeStamp,
                        UInt32 midiOutNum,
                        const struct MIDIPacketList *inPktList)
{
    struct LTMIDIControl *mc = (struct LTMIDIControl *)userData;
    mc->err = noErr;

    if (mc->outPort && mc->destination)
    {
        mc->err = MIDISend(mc->outPort, mc->destination, inPktList);
    }
    
    return noErr;
}
