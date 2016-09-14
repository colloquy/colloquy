//
//  RunOnMainThread.h
//  Chat Core
//
//  Created by C.W. Betts on 4/6/15.
//
//

#ifndef Chat_Core_RunOnMainThread_h
#define Chat_Core_RunOnMainThread_h

#import <Foundation/Foundation.h>

static inline void RunOnMainThread(BOOL async, dispatch_block_t __nonnull block)
{
	void (*theDispatchFunc)(dispatch_queue_t, dispatch_block_t);
	if (async) {
		theDispatchFunc = dispatch_async;
	} else {
		theDispatchFunc = dispatch_sync;
	}
	
	if ([NSThread isMainThread]) {
		block();
	} else {
		theDispatchFunc(dispatch_get_main_queue(), block);
	}
}

static inline void RunOnMainThreadSync(dispatch_block_t __nonnull block)
{
	RunOnMainThread(NO, block);
}

static inline void RunOnMainThreadAsync(dispatch_block_t __nonnull block)
{
	RunOnMainThread(YES, block);
}

#endif
