//
//  A2DPSink.h
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

#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM (NSUInteger, A2DPSinkProfileType) {
    A2DPSinkProfileTypeSBC,
    A2DPSinkProfileTypeMPEG2
};

typedef NS_ENUM(NSInteger, A2DPSinkErrorCode)
{
    kA2DPUnknownError = -1000,
    kA2DPLoadError = -1001,
    kA2DPUnloadError = -1002,
    kA2DPPayloadError = -1003
};

@protocol A2DPSinkDelegate;
@interface A2DPSink : NSObject

+ (A2DPSink *)sharedInstance;
- (void)loadWithType:(A2DPSinkProfileType)type andDelegate:(NSObject<A2DPSinkDelegate> *)delegate;
- (void)unload;

@end

@protocol A2DPSinkDelegate <NSObject>

- (void)a2dpSink:(A2DPSink *)sink channelConnected:(IOBluetoothL2CAPChannel *)channel;
- (void)a2dpSink:(A2DPSink *)sink channelDisconnected:(IOBluetoothL2CAPChannel *)channel;
- (void)a2dpSink:(A2DPSink *)sink channel:(IOBluetoothL2CAPChannel *)channel rawRTPdataReceived:(NSData *)data;
- (void)a2dpSink:(A2DPSink *)sink errorOccured:(NSError *)error;

@end
