//
//  GetMetadataForFile.h
//  Colloquy (Old)
//
//  Created by C.W. Betts on 4/11/13.
//
//

#ifndef Colloquy__Old__GetMetadataForFile_h
#define Colloquy__Old__GetMetadataForFile_h

#include <CoreFoundation/CoreFoundation.h>

#ifndef __private_extern
#define __private_extern __attribute__((visibility("hidden")))
#endif

__private_extern Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile);
__private_extern Boolean GetMetadataForURL(void* thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFURLRef urlForFile);

#endif
