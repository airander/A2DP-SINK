//
//  A2DPSinkExampleAppDelegate.m
//  A2DPSink-Example
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

#import "A2DPSinkExampleAppDelegate.h"

@implementation A2DPSinkExampleAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[A2DPSink sharedInstance] loadWithType:A2DPSinkProfileTypeMPEG2 andDelegate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[A2DPSink sharedInstance] unload];
}

#pragma mark - A2DP Sink Delegates -

- (void)a2dpSink:(A2DPSink *)sink channelConnected:(IOBluetoothL2CAPChannel *)channel
{
    NSLog(@"Channel Connected!");
}

- (void)a2dpSink:(A2DPSink *)sink channelDisconnected:(IOBluetoothL2CAPChannel *)channel
{
    NSLog(@"Channel disconnected!");
}

- (void)a2dpSink:(A2DPSink *)sink channel:(IOBluetoothL2CAPChannel *)channel rawRTPdataReceived:(NSData *)data
{
    NSLog(@"Received RAW RTP Data (Channel Device: %@): %@", channel.device.name, data);
}

- (void)a2dpSink:(A2DPSink *)sink errorOccured:(NSError *)error
{
    NSLog(@"An error occured: %@", error);
}

@end
