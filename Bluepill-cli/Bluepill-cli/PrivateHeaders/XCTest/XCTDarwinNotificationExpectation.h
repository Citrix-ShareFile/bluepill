//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import <XCTest/XCTestExpectation.h>

@class NSString, _XCTDarwinNotificationExpectationImplementation;

@interface XCTDarwinNotificationExpectation : XCTestExpectation
{
    _XCTDarwinNotificationExpectationImplementation *_internal;
}

@property(retain) _XCTDarwinNotificationExpectationImplementation *internal; // @synthesize internal=_internal;
- (void)cleanup;
@property(copy) CDUnknownBlockType handler;
@property(readonly, copy) NSString *notificationName;
- (id)initWithNotificationName:(id)arg1;
- (void)dealloc;

@end

