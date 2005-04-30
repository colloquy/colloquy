#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 
#include <Foundation/Foundation.h>

Boolean GetMetadataForFile( void *thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile ) {
	NSMutableDictionary *returnDict = (NSMutableDictionary *) attributes;
	NSURL *file = [NSURL fileURLWithPath:(NSString *) pathToFile];

	NSError *error = nil;
    NSXMLDocument *transcript = [[[NSXMLDocument alloc] initWithContentsOfURL:file options:NSXMLDocumentTidyXML error:&error] autorelease];

	// Get date started
	NSArray *dateArray = [transcript nodesForXPath:@"/log[1]/@began" error:&error];
    NSDate *dateStarted = [NSDate dateWithString:[[dateArray objectAtIndex:0] stringValue]];
	[returnDict setObject:dateStarted forKey:(NSString *) kMDItemContentCreationDate];

	// Get date of last message
	NSArray *xpathResult = [transcript nodesForXPath:@"/log[1]/envelope[last()]/message[last()]/@received" error:&error];
	NSDate *lastMessageDate = [NSDate dateWithString:[[xpathResult objectAtIndex:0] stringValue]];
	NSTimeInterval logDuration = [lastMessageDate timeIntervalSinceDate:dateStarted];

	// Set Duration
	[returnDict setObject:[NSNumber numberWithInt:logDuration] forKey:(NSString *) kMDItemDurationSeconds];

	// Get WhereFroms
	xpathResult = [transcript nodesForXPath:@"/log[1]@source" error:&error];
	NSString *fromURL = nil;
	if( [xpathResult count] ) {
		fromURL = [[xpathResult objectAtIndex:0] stringValue];
		[returnDict setObject:fromURL forKey:(NSString *) kMDItemWhereFroms];
	}

	// Set Title and Coverage
	NSDateFormatter *formatter = [[NSDateFormatter alloc] initWithDateFormat:@"%A, the %d of %B at %I:%M" allowNaturalLanguage:NO];
	NSString *coverageWording = nil;

	// Set Coverage
	if( fromURL ) {
		coverageWording = [NSString stringWithFormat:@"Conversation from %@ to %@ in %@", [formatter stringFromDate:dateStarted],
																							[formatter stringFromDate:lastMessageDate],
																						fromURL];
	} else {
		coverageWording = [NSString stringWithFormat:@"Conversation from %@ to %@", [formatter stringFromDate:dateStarted],
																					[formatter stringFromDate:lastMessageDate]];
	}

	[returnDict setObject:coverageWording forKey:(NSString *) kMDItemCoverage];
	[returnDict setObject:coverageWording forKey:(NSString *) kMDItemTitle];

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
	[returnDict setObject:[NSArray arrayWithObject:@"Colloquy"] forKey:(NSString *) kMDItemCreator];

    return TRUE;
}