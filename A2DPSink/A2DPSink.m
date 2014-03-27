//
//  A2DPSink.m
//  A2DPSink
//
//  Copyright (c) 2014, Eric Orion Anderson
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice, this
//  list of conditions and the following disclaimer in the documentation and/or
//  other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "A2DPSink.h"

NSString * const A2DPSinkErrorDomain = @"A2DPSinkErrorDomain";

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...) ;
#endif

#define AVDTP_PKT_TYPE_SINGLE		0x00
#define AVDTP_PKT_TYPE_START		0x01
#define AVDTP_PKT_TYPE_CONTINUE		0x02
#define AVDTP_PKT_TYPE_END          0x03

#define AVDTP_MSG_TYPE_COMMAND		0x00
#define AVDTP_MSG_TYPE_GEN_REJECT	0x01
#define AVDTP_MSG_TYPE_ACCEPT		0x02
#define AVDTP_MSG_TYPE_REJECT		0x03

#define AVDTP_DISCOVER              0x01
#define AVDTP_GET_CAPABILITIES		0x02
#define AVDTP_SET_CONFIGURATION		0x03
#define AVDTP_GET_CONFIGURATION		0x04
#define AVDTP_RECONFIGURE           0x05
#define AVDTP_OPEN                  0x06
#define AVDTP_START                 0x07
#define AVDTP_CLOSE                 0x08
#define AVDTP_SUSPEND               0x09
#define AVDTP_ABORT                 0x0A

#define AVDTP_SEP_TYPE_SOURCE		0x00
#define AVDTP_SEP_TYPE_SINK         0x01

#define AVDTP_MEDIA_TYPE_AUDIO		0x00
#define AVDTP_MEDIA_TYPE_VIDEO		0x01
#define AVDTP_MEDIA_TYPE_MULTIMEDIA	0x02

static const unsigned char sbc_media_transport[] = {
    0x01,           /* Media transport */
    0x00,       /* Audio Type */
    0x07,           /* Media codec category */
    0x06,       /* Length */
    0x00,	/* Media type audio */
    0x00,	/* Codec SBC */
    0x22,	/* 44.1 kHz, stereo */
    0x15,	/* 16 blocks, 8 subbands */
    0x02,   /* Minimum Bitpool Value */
    0x35,   /* Maximum Bitpool Value */
};

//static const unsigned char MPEG1_2Audio_media_transport[] = {
//    0x01,       /* Media transport */
//        0x00,   /* Audio Type */
//    0x07,       /* Media codec category */
//        0x06,   /* Length */
//        0x00,   /* Media type audio */
//        0x01,   /* Codec MPEG-1, 2 Audio */
//        0x32,   /* Layer 3 (MP3), stereo */
//        0x43,   /* MPF-2 Support, 44.1 & 48khz */
//        0xBF,   /* Variable Bit Rate, Bit Rates */
//        0xFE,   /* More Bit Rates */
//};

static const unsigned char MPEG2_ACC_media_transport[] = {
    0x01,       /* Media transport */
        0x00,   /* Audio Type */
    0x07,       /* Media codec category */
        0x08,   /* Length */
            0x00,   /* Media type audio */
            0x02,   /* Codec MPEG-2, 4 AAC */
            0x80,   /* MPEG-2 AAC LC Object Type */
            0x01,   /* 44.1khz Sampling */
            0x8C,   /* 48khz Sampling, 2 Channel */
            0x84,   /* Variable Bit Rate, 256k Max Bit Rate */
            0x00,   /* Bit Rates */
            0x00,   /* Bit Rates */
};

typedef struct avdtp_common_header {
	uint8_t message_type:2;
	uint8_t packet_type:2;
	uint8_t transaction:4;
} __attribute__ ((packed)) avdtp_common_header;

typedef struct avdtp_single_header {
	uint8_t message_type:2;
	uint8_t packet_type:2;
	uint8_t transaction:4;
	uint8_t signal_id:6;
	uint8_t rfa0:2;
} __attribute__ ((packed)) avdtp_single_header;

typedef struct avdtp_start_header {
	uint8_t message_type:2;
	uint8_t packet_type:2;
	uint8_t transaction:4;
	uint8_t no_of_packets;
	uint8_t signal_id:6;
	uint8_t rfa0:2;
} __attribute__ ((packed)) avdtp_start_header;

typedef struct avdtp_continue_header {
	uint8_t message_type:2;
	uint8_t packet_type:2;
	uint8_t transaction:4;
} __attribute__ ((packed)) avdtp_continue_header;

typedef struct seid_info {
	uint8_t rfa0:1;
	uint8_t inuse:1;
	uint8_t seid:6;
	uint8_t rfa2:3;
	uint8_t type:1;
	uint8_t media_type:4;
} __attribute__ ((packed)) seid_info;

struct seid {
	uint8_t rfa0:2;
	uint8_t seid:6;
} __attribute__ ((packed));

typedef struct rtp_header {
    uint8_t csrccount:4;
    uint8_t extension:1;
    uint8_t padding:1;
    uint8_t version:2;
    
    uint8_t payloadtype:7;
    uint8_t marker:1;
    
    uint16_t sequence_number;
    uint32_t timestamp;
    uint32_t ssrc;
    uint32_t csrc[0];
} __attribute__ ((packed)) rtp_header;

@interface A2DPSink()
@property(nonatomic, strong) NSObject<A2DPSinkDelegate> *delegate;
@property(nonatomic, assign) A2DPSinkProfileType type;
@property(nonatomic, assign) BluetoothL2CAPPSM l2CAPPSM;
@property(nonatomic, assign) BluetoothSDPServiceRecordHandle serverHandle;
@property(nonatomic, assign) IOBluetoothUserNotification *incomingChannelNotification;
@property(nonatomic, strong) IOBluetoothSDPServiceRecord *loadedServiceRecord;
@end

static A2DPSink *a2dpSink = nil;
@implementation A2DPSink

+(A2DPSink *)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        a2dpSink = [[A2DPSink alloc] init];
    });
    return a2dpSink;
}

- (void)loadWithType:(A2DPSinkProfileType)type andDelegate:(NSObject<A2DPSinkDelegate> *)delegate
{
    NSParameterAssert(delegate!=nil);
    self.type = type;
    self.delegate = delegate;
    [self load];
}

-(void)newL2CAPChannelOpened:(IOBluetoothUserNotification *)inNotification channel:(IOBluetoothL2CAPChannel *)newChannel
{
    [newChannel setDelegate:self];
}

- (void)load
{
    NSString *dictionaryPath = nil;
    NSMutableDictionary *sdpEntries = nil;
    dictionaryPath = [[NSBundle mainBundle] pathForResource:@"A2DP-SNK" ofType:@"plist"];
    if(dictionaryPath)
    {
        sdpEntries = [NSMutableDictionary dictionaryWithContentsOfFile:dictionaryPath];
        if(sdpEntries)
        {
            DLog(@"Loading A2DP Sink...");
            [sdpEntries setObject:@"Audio Sink" forKey:@"0100 - ServiceName*"];
            self.loadedServiceRecord = [IOBluetoothSDPServiceRecord publishedServiceRecordWithDictionary:sdpEntries];
            DLog(@"serviceRecord attributes: %@", [self.loadedServiceRecord attributes]);
            
            IOReturn result = [self.loadedServiceRecord getL2CAPPSM:&_l2CAPPSM];
            if(result!=kIOReturnSuccess)
            {
                int code = err_get_code(result);
                NSString *errorString = [NSString stringWithFormat:@"A2DPSink Load Error - Error getting RFCOMMChannelId: %d %02x", code, code];
                DLog(@"%@", errorString);
                [self.delegate a2dpSink:self errorOccured:[NSError errorWithDomain:A2DPSinkErrorDomain code:kA2DPLoadError userInfo:@{NSLocalizedDescriptionKey:errorString}]];
                return;
            }
            result = [self.loadedServiceRecord getServiceRecordHandle:&_serverHandle];
            if(result==kIOReturnSuccess)
            {
                DLog(@"SDP Successfully Published 'Audio Sink'");
                self.incomingChannelNotification = [IOBluetoothL2CAPChannel registerForChannelOpenNotifications:self selector:@selector(newL2CAPChannelOpened:channel:) withPSM:_l2CAPPSM direction:kIOBluetoothUserNotificationChannelDirectionIncoming];
            }
            else
            {
                int code = err_get_code(result);
                NSString *errorString = [NSString stringWithFormat:@"A2DPSink Load Error - Error getting service record handle: %d %02x", code, code];
                DLog(@"%@", errorString);
                [self.delegate a2dpSink:self errorOccured:[NSError errorWithDomain:A2DPSinkErrorDomain code:kA2DPLoadError userInfo:@{NSLocalizedDescriptionKey:errorString}]];
            }
        }
    }
    else
    {
        NSString *errorString = [NSString stringWithFormat:@"A2DPSink Load Error - Dictionary could not be loaded."];
        DLog(@"%@", errorString);
        [self.delegate a2dpSink:self errorOccured:[NSError errorWithDomain:A2DPSinkErrorDomain code:kA2DPLoadError userInfo:@{NSLocalizedDescriptionKey:errorString}]];
    }
}

- (void)unload
{
    NSString *dictionaryPath = nil;
    NSMutableDictionary *sdpEntries = nil;
    dictionaryPath = [[NSBundle mainBundle] pathForResource:@"A2DP-SNK" ofType:@"plist"];
    if(dictionaryPath)
    {
        sdpEntries = [NSMutableDictionary dictionaryWithContentsOfFile:dictionaryPath];
        if(sdpEntries)
        {
            DLog(@"Unloading A2DP Sink...");
            IOReturn result = kIOReturnSuccess;
            if(self.loadedServiceRecord) {
                result = [self.loadedServiceRecord removeServiceRecord];
            }
            else
            {
                [sdpEntries setObject:@"Audio Sink" forKey:@"0100 - ServiceName*"];
                IOBluetoothSDPServiceRecord *serviceRecord = [IOBluetoothSDPServiceRecord publishedServiceRecordWithDictionary:sdpEntries];
                [serviceRecord removeServiceRecord]; //not setting result as it's best effort here
            }
            if(result!=kIOReturnSuccess)
            {
                int code = err_get_code(result);
                NSString *errorString = [NSString stringWithFormat:@"A2DPSink Unload Error - Error unloading service: %d %02x", code, code];
                DLog(@"%@", errorString);
                [self.delegate a2dpSink:self errorOccured:[NSError errorWithDomain:A2DPSinkErrorDomain code:kA2DPUnloadError userInfo:@{NSLocalizedDescriptionKey:errorString}]];
            }
        }
    }
    else
    {
        NSString *errorString = [NSString stringWithFormat:@"A2DPSink Unload Error - Dictionary could not be loaded."];
        DLog(@"%@", errorString);
        [self.delegate a2dpSink:self errorOccured:[NSError errorWithDomain:A2DPSinkErrorDomain code:kA2DPLoadError userInfo:@{NSLocalizedDescriptionKey:errorString}]];
    }
}

#pragma mark - Utility Methods -

- (NSString *)hexCharacterToBinary:(unichar)myChar
{
    switch(myChar)
    {
        case '0': return @"0000";
        case '1': return @"0001";
        case '2': return @"0010";
        case '3': return @"0011";
        case '4': return @"0100";
        case '5': return @"0101";
        case '6': return @"0110";
        case '7': return @"0111";
        case '8': return @"1000";
        case '9': return @"1001";
        case 'a':
        case 'A': return @"1010";
        case 'b':
        case 'B': return @"1011";
        case 'c':
        case 'C': return @"1100";
        case 'd':
        case 'D': return @"1101";
        case 'e':
        case 'E': return @"1110";
        case 'f':
        case 'F': return @"1111";
        case '>': return @" ";
        case ' ': return @" ";
    }
    return @"";
}

- (NSString *)hexStringToBinary:(NSString *)string
{
    NSMutableString *binStr = [[NSMutableString alloc] init];
    for(NSUInteger i=1; i<[string length]-1; i++)
    {
        [binStr appendString:[self hexCharacterToBinary:[string characterAtIndex:i]]];
    }
    return [binStr copy];
}

//static void dump_rtp_header(struct rtp_header *hdr)
//{
//	NSLog(@"\tV %d P %d X %d CC %d M %d PT %d S %d TS %d SSRC %d\n", hdr->version, hdr->padding, hdr->extension, hdr->csrccount, hdr->marker, hdr->payloadtype, hdr->sequence_number, hdr->timestamp, hdr->ssrc);
//}

//static void dump_avdtp_header(struct avdtp_single_header *hdr)
//{
//	NSLog(@"\tTL %d PT %d MT %d SI %d\n", hdr->transaction, hdr->packet_type, hdr->message_type, hdr->signal_id);
//}

#pragma mark - L2CAP Channel Delegates -

- (void)l2capChannelData:(IOBluetoothL2CAPChannel*)l2capChannel data:(void *)dataPointer length:(size_t)dataLength
{
    unsigned char buf[2048];
    memcpy(buf, dataPointer, dataLength);
    
    NSData *newData = [NSData dataWithBytes:dataPointer length:dataLength];
    avdtp_single_header *hdr = (void *)buf;
    //dump_avdtp_header(hdr);
    
    if(hdr->message_type == AVDTP_MSG_TYPE_COMMAND) //receiving a command
    {
        switch(hdr->signal_id)
        {
            case AVDTP_DISCOVER: //device requesting discover
            {
                seid_info *sei = (void *)(buf + 2);
                hdr->message_type = AVDTP_MSG_TYPE_ACCEPT;
                buf[2] = 0x00;
                buf[3] = 0x00;
                sei->seid = 0x01;
                sei->type = AVDTP_SEP_TYPE_SINK;
                sei->media_type = AVDTP_MEDIA_TYPE_AUDIO;
                DLog(@"\tAccepting discover command...");
                NSData *sendingData = [NSData dataWithBytes:buf length:4];
                DLog(@"\tSending Data:%@ (%@)", sendingData, [self hexStringToBinary:[sendingData description]]);
                [l2capChannel writeAsync:buf length:4 refcon:NULL];
                return;
            }
            case AVDTP_GET_CAPABILITIES: //device requesting capatibilies
            {
                hdr->message_type = AVDTP_MSG_TYPE_ACCEPT;
                switch (self.type)
                {
                    case A2DPSinkProfileTypeSBC:
                    {
                        memcpy(&buf[2], sbc_media_transport, sizeof(sbc_media_transport));
                        DLog(@"\tAccepting get capabilities command...");
                        NSData *sendingData = [NSData dataWithBytes:buf length:2+sizeof(sbc_media_transport)];
                        DLog(@"\tSending Data:%@ (%@)", sendingData, [self hexStringToBinary:[sendingData description]]);
                        [l2capChannel writeAsync:buf length:2+sizeof(sbc_media_transport) refcon:NULL];
                        break;
                    }
                    case A2DPSinkProfileTypeMPEG2:
                    {
                        memcpy(&buf[2], MPEG2_ACC_media_transport, sizeof(MPEG2_ACC_media_transport));
                        DLog(@"\tAccepting get capabilities command...");
                        NSData *sendingData = [NSData dataWithBytes:buf length:2+sizeof(MPEG2_ACC_media_transport)];
                        DLog(@"\tSending Data:%@ (%@)", sendingData, [self hexStringToBinary:[sendingData description]]);
                        [l2capChannel writeAsync:buf length:2+sizeof(MPEG2_ACC_media_transport) refcon:NULL];
                        break;
                    }
                    default: break;
                }
                return;
            }
            case AVDTP_SET_CONFIGURATION: //device requesting to set configuration
            {
                hdr->message_type = AVDTP_MSG_TYPE_ACCEPT;
				DLog(@"\tAccepting set configuration command...");
                NSData *sendingData = [NSData dataWithBytes:buf length:2];
                DLog(@"\tSending Data:%@ (%@)", sendingData, [self hexStringToBinary:[sendingData description]]);
                [l2capChannel writeAsync:buf length:2 refcon:NULL];
                return;
            }
            case AVDTP_OPEN: //device requesting to open a stream
            {
                hdr->message_type = AVDTP_MSG_TYPE_ACCEPT;
				DLog(@"\tAccepting open stream command...");
                NSData *sendingData = [NSData dataWithBytes:buf length:2];
                DLog(@"\tSending Data:%@ (%@)", sendingData, [self hexStringToBinary:[sendingData description]]);
                [l2capChannel writeAsync:buf length:2 refcon:NULL];
                return;
            }
            case AVDTP_START: //device is starting audio
            {
                hdr->message_type = AVDTP_MSG_TYPE_ACCEPT;
				DLog(@"\tAccepting start stream command...");
                NSData *sendingData = [NSData dataWithBytes:buf length:2];
                DLog(@"\tSending Data:%@ (%@)", sendingData, [self hexStringToBinary:[sendingData description]]);
                [l2capChannel writeAsync:buf length:2 refcon:NULL];
                return;
            }
            case AVDTP_CLOSE:
            {
                hdr->message_type = AVDTP_MSG_TYPE_ACCEPT;
				DLog(@"\tAccepting close stream command...");
                NSData *sendingData = [NSData dataWithBytes:buf length:2];
                DLog(@"\tSending Data:%@ (%@)", sendingData, [self hexStringToBinary:[sendingData description]]);
                [l2capChannel writeAsync:buf length:2 refcon:NULL];
                [l2capChannel closeChannel];
                [self.delegate a2dpSink:self channelDisconnected:l2capChannel];
                return;
            }
            case AVDTP_SUSPEND:
            {
                hdr->message_type = AVDTP_MSG_TYPE_ACCEPT;
				DLog(@"\tAccepting suspend stream command...");
                NSData *sendingData = [NSData dataWithBytes:buf length:2];
                DLog(@"\tSending Data:%@ (%@)", sendingData, [self hexStringToBinary:[sendingData description]]);
                [l2capChannel writeAsync:buf length:2 refcon:NULL];
                return;
            }
            case AVDTP_ABORT: {
                hdr->message_type = AVDTP_MSG_TYPE_ACCEPT;
				DLog(@"\tAccepting abort command...");
                NSData *sendingData = [NSData dataWithBytes:buf length:2];
                DLog(@"\tSending Data:%@ (%@)", sendingData, [self hexStringToBinary:[sendingData description]]);
                [l2capChannel writeAsync:buf length:2 refcon:NULL];
                [l2capChannel closeChannel];
                [self.delegate a2dpSink:self channelDisconnected:l2capChannel];
                return;
            }
            default:
            {
                //try getting rtp info
                rtp_header *rtpHeader = (void *)buf;
                //dump_rtp_header(rtpHeader);
                
                if(rtpHeader->version==2 && newData.length>21) //assumption here that is actually rtp data
                {
                    NSData *rtpData = [NSData dataWithBytes:dataPointer length:dataLength];
                    [self.delegate a2dpSink:self channel:l2capChannel rawRTPdataReceived:rtpData];
                }
                else
                {
                    NSString *errorString = [NSString stringWithFormat:@"A2DPSink Payload Error - Unknown payload receieved."];
                    DLog(@"%@", errorString);
                    [self.delegate a2dpSink:self errorOccured:[NSError errorWithDomain:A2DPSinkErrorDomain code:kA2DPPayloadError userInfo:@{NSLocalizedDescriptionKey:errorString}]];
                }
            }
        }
    }
}

@end
