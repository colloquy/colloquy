//============================================================================
// 
//     License:
// 
//     This library is free software; you can redistribute it and/or
//     modify it under the terms of the GNU Lesser General Public
//     License as published by the Free Software Foundation; either
//     version 2.1 of the License, or (at your option) any later version.
// 
//     This library is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//     Lesser General Public License for more details.
// 
//     You should have received a copy of the GNU Lesser General Public
//     License along with this library; if not, write to the Free Software
//     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  
//     USA
// 
//     Copyright (C) 2002 Dave Smith (dizzyd@jabber.org)
// 
// $Id: XMLAccumulator.m,v 1.2 2004/10/03 11:09:06 jtownsend Exp $
//============================================================================

#import "acid-dom.h"
#import <expat.h>

@implementation XMLAccumulator

-(id) init:(NSMutableString*)data 
{
    [super init];
    _prefixes = [[NSMutableDictionary alloc] init];
    _overrides = [[NSMutableDictionary alloc] init];
    _data = [data retain];
    return self;
}

-(void) dealloc
{
    [_data release];
    [_prefixes release];
    [_overrides release];
    [super dealloc];
}

-(void) addOverridePrefix:(NSString*)prefix forURI:(NSString*)uri 
{
    [_overrides setObject:prefix forKey:uri];
}

-(NSString*) generatePrefix:(NSString*)uri
{
    // Lookup the URI
    NSString* prefix = [_prefixes objectForKey:uri];
    if (!prefix)
    {
        prefix = [[NSString alloc] initWithFormat:@"xn%d", _prefix_counter++];
        [_prefixes setObject:prefix forKey:uri];
        [prefix autorelease];
    }
    return prefix;
}

-(NSString*) lookupURI:(NSString*)uri
{
    return [_overrides objectForKey:uri];
}

-(void) openElement:(XMLElement*)elem
{
    XMLQName*   qname  = [elem qname];
    NSString*   uri    = [elem defaultURI];
    XMLElement* parent = [elem parent];
    NSString*   oprefix = [self lookupURI:[qname uri]];

    // If the URI of the qname is in the prefix override table, then we force
    // this element name to be prefixed with the specified prefix
    if (oprefix)
    {
        [_data appendFormat:@"<%@:%@", oprefix, [qname name]];
    }
    else
    {
        // If the default URI provided matches the URI of the
        // element name and they are identical, we don't need to prefix the
        // element name
        if ([uri isEqual:[qname uri]])
        {
            // Now check the parent's URI; if it's the same as the default
            // provided, we can just use a standard tag name with no
            // xmlns= declarations
            if ([uri isEqual:[parent defaultURI]])
                [_data appendFormat:@"<%@", [qname name]];
            else
                [_data appendFormat:@"<%@ xmlns='%@'", [qname name], uri];
        }
        // If the default URI doesn't match the URI of the tag name, we'll
        // need to generate a prefix for the tag name URI and prepend it to the
        // tag name
        else
        {
            NSString* prefix = [self generatePrefix:[qname uri]];
            if ([uri isEqual:[parent defaultURI]])
            {
                [_data appendFormat:@"<%@:%@ xmlns:%@='%@'",
                    prefix, [qname name], prefix, [qname uri]];
            }
            else
                [_data appendFormat:@"<%@:%@ xmlns:%@='%@' xmlns='%@'",
                    prefix, [qname name], prefix, [qname uri], uri];
        }
    }
}

-(void) selfCloseElement
{
	[_data appendString:@"/>"];
}

-(void) closeElement:(XMLElement*)elem
{
    XMLQName*   qname  = [elem qname];
    NSString*   uri    = [elem defaultURI];
    NSString*   oprefix = [self lookupURI:[qname uri]];

    if (oprefix)
    {
        [_data appendFormat:@"</%@:%@>", oprefix, [qname name]];
    }
    else
    {
        // If the default URI provided matches the URI of the
        // tag name; if they are identical, we don't need to prefix the
        // element name
        if ([uri isEqual:[qname uri]])
        {
            [_data appendFormat:@"</%@>", [qname name]];
        }
        // If the default URI doesn't match the URI of the tag name, we'll
        // need to generate a prefix for the tag name URI and prepend it to the
        // tag name
        else
        {
            NSString* prefix = [self generatePrefix:[qname uri]];
            [_data appendFormat:@"</%@:%@>", prefix, [qname name]];
        }
    }
}

-(void) addAttribute:(XMLQName*)qname withValue:(NSString*)value ofElement:(XMLElement*)elem
{
    NSString*   uri    = [elem defaultURI];

    // If the default URI matches the URI of the attrib name, we don't
    // need to prefix the attribute name
    if ([uri isEqual:[qname uri]])
    {
        [_data appendFormat:@" %@='%@'", [qname name], [XMLCData escape:value]];
    }
    // Else if the default URI differs, we'll need to prefix the attribute name
    else
    {
        // Check the prefix in the our prefix overrides table first

        NSString* prefix = [self lookupURI:[qname uri]];
        if (!prefix)
            prefix = [self generatePrefix:[qname uri]];
        [_data appendFormat:@" %@:%@='%@'", prefix, [qname name], [XMLCData escape:value]];
    }
}

-(void) addSimpleAttribute:(NSString*)name withValue:(NSString*)value
{
    [_data appendFormat:@" %@='%@'", name, [XMLCData escape:value]];
}

-(void) addChildren:(NSArray*)children ofElement:(XMLElement*)elem
{
    id<XMLNode> curobj;
    NSEnumerator* e = [children objectEnumerator];

    // First add the closing ">" on the string; this makes the
    // assumption that addChildren is only called after all the
    // attributes have been added
    [_data appendString:@">"];

    // Process child nodes
    while ((curobj = [e nextObject]))
    {
        [curobj description:self];
    }
}

-(void) addCData:(XMLCData*)cdata
{
    [_data appendString:[cdata description]];
}

+(NSString*) process:(XMLElement*)element
{
    // Create a pool to catch any temps which might be generated
    NSAutoreleasePool* workpool = [[NSAutoreleasePool alloc] init];
    
    // Setup result data holder and accumulator
    NSMutableString* result = [[NSMutableString alloc] initWithCapacity:512];    
    XMLAccumulator* acc = [[XMLAccumulator alloc] init:result];
    [element description:acc];
    [acc release];
    
    // Let go of the autorelease pool
    [workpool release];
    // Now autorelase the result string
    [result autorelease];
    return result;
}

@end
