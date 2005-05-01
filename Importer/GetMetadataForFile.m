#ifndef MAC_OS_X_VERSION_10_4
#define MAC_OS_X_VERSION_10_4 1040
#endif

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 
#include <Foundation/Foundation.h>

Boolean GetMetadataForFile( void *thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile ) {
	NSMutableDictionary *returnDict = (NSMutableDictionary *) attributes;
	NSURL *file = [NSURL fileURLWithPath:(NSString *) pathToFile];
	NSString *title = [[(NSString *) pathToFile lastPathComponent] stringByDeletingPathExtension];

	// Set title
	[returnDict setObject:title forKey:(NSString *) kMDItemTitle];

	NSError *error = nil;
    NSXMLDocument *transcript = [[[NSXMLDocument alloc] initWithContentsOfURL:file options:NSXMLDocumentTidyXML error:&error] autorelease];

	// Get date started
    NSDate *dateStarted = nil;
	NSArray *xpathResult = [transcript nodesForXPath:@"/log[1]/@began" error:&error];
	
	if( ! [xpathResult count] )
		xpathResult = [transcript nodesForXPath:@"/log[1]/envelope[1]/message[1]/@received" error:&error];

	if( [xpathResult count] ) {
		dateStarted = [NSDate dateWithString:[[xpathResult objectAtIndex:0] stringValue]];
		[returnDict setObject:dateStarted forKey:(NSString *) kMDItemContentCreationDate];
	}

	// Get date of last message
	NSDate *lastMessageDate = nil;

	xpathResult = [transcript nodesForXPath:@"/log[1]/envelope[last()]/message[last()]/@received" error:&error];
	if( [xpathResult count] ) {
		lastMessageDate = [NSDate dateWithString:[[xpathResult objectAtIndex:0] stringValue]];
		[returnDict setObject:lastMessageDate forKey:(NSString *) kMDItemContentModificationDate];
		[returnDict setObject:lastMessageDate forKey:(NSString *) kMDItemLastUsedDate];
	}

	if( lastMessageDate && dateStarted ) {
		// Set Duration
		NSTimeInterval logDuration = [lastMessageDate timeIntervalSinceDate:dateStarted];
		[returnDict setObject:[NSNumber numberWithInt:logDuration] forKey:(NSString *) kMDItemDurationSeconds];

		// Set Coverage
		NSDateFormatter *formatter = [[[NSDateFormatter alloc] initWithDateFormat:@"" allowNaturalLanguage:NO] autorelease];
		[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[formatter setDateStyle:NSDateFormatterShortStyle];
		[formatter setTimeStyle:NSDateFormatterShortStyle];

		NSString *coverageWording = [NSString stringWithFormat:@"%@ to %@", [formatter stringFromDate:dateStarted], [formatter stringFromDate:lastMessageDate]];
		[returnDict setObject:coverageWording forKey:(NSString *) kMDItemCoverage];
	}

	// Get Where From
	xpathResult = [transcript nodesForXPath:@"/log[1]/@source" error:&error];
	NSString *fromURL = nil;
	if( [xpathResult count] ) {
		fromURL = [[xpathResult objectAtIndex:0] stringValue];
		[returnDict setObject:fromURL forKey:(NSString *) kMDItemWhereFroms];
	}

	// Get Participants
	NSMutableArray *participants = [NSMutableArray array];
	NSArray *participantNodes = [transcript nodesForXPath:@"/log[1]/envelope/sender" error:&error];
	NSEnumerator *enumerator = [participantNodes objectEnumerator];
	NSXMLNode *participantNode = nil;

	while( ( participantNode = [enumerator nextObject] ) ) {
		NSString *nickname = [participantNode stringValue];
		if( ! [participants containsObject:nickname] )
			[participants addObject:nickname];
	}

	[returnDict setObject:participants forKey:(NSString *) kMDItemContributors];

	// Now the stuff that doesn't change
	[returnDict setObject:[NSArray arrayWithObject:@"Chat transcript"] forKey:(NSString *) kMDItemKind];
	[returnDict setObject:[NSArray arrayWithObject:@"Colloquy"] forKey:(NSString *) kMDItemCreator];

    return TRUE;
}

#endif