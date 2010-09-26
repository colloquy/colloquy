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
//     Copyright (C) 2002-2003 Dave Smith (dizzyd@jabber.org)
// 
// $Id: XMLElement.m,v 1.3 2004/10/16 21:40:05 gbooker Exp $
//============================================================================

#import "acid-dom.h"
#import <Foundation/NSEnumerator.h>

@interface _ElementEnumerator : NSEnumerator
{
    NSArray*        _elements;
    unsigned int    _index;
}
-(id) initWithArray:(NSArray*)elems;
-(void) dealloc;
-(NSArray*) allObjects;
-(id) nextObject;
@end

@implementation _ElementEnumerator

-(id) initWithArray:(NSArray*)elems
{
    [self init];
    _elements = [elems retain];
    _index = 0;
    return self;
}

-(void) dealloc
{
    [_elements release];
    [super dealloc];
}

-(NSArray*) allObjects
{
    return nil;
}

-(id) nextObject
{
    while (_index < [_elements count])
    {
        id curr = [_elements objectAtIndex:_index++];
        if ([curr isKindOfClass:[XMLElement class]])
            return curr;
    }
    return nil;
}

@end

@implementation XMLElement

// Basic initializers
-(id) init
{
    [super init];
    _attribs  = [[NSMutableDictionary alloc] init];
    _children = [[NSMutableArray alloc] init];
    return self;
}

-(void) dealloc
{
    [_attribs release];
    [_children release];
    [_name release];
    [_defaultURI release];
    [super dealloc];
}

// Extended initializers
-(id) initWithQName:(XMLQName*)qname
     withAttributes:(NSMutableDictionary*)atts
     withDefaultURI:(NSString*)uri
{
    [self init];

    _name  = [qname retain];
    _defaultURI = [uri retain];
    [_attribs release];
    _attribs = [atts retain];

    return self;
}

-(id) initWithQName:(XMLQName*)qname
{
    return [self initWithQName:qname withDefaultURI:[qname uri]];
}

-(id) initWithQName:(XMLQName*)qname withDefaultURI:(NSString*)uri
{
    [self init];
    _name  = [qname retain];
    _defaultURI = [uri retain];

    return self;
}

// High-level child initializers

-(XMLElement*) addElement:(XMLElement*)element
{
    [element setParent:self];
    [_children addObject:element];
    return element;
}

-(XMLElement*) addElementWithName:(NSString*)name
{
    return [self addElementWithName:name withDefaultURI:_defaultURI];
}

-(XMLElement*) addElementWithQName:(XMLQName*)name
{
    return [self addElementWithQName:name withDefaultURI:[name uri]];
}

-(XMLElement*) addElementWithName:(NSString*)name withDefaultURI:(NSString*)uri
{
    return [self addElementWithQName:QNAME(uri, name) withDefaultURI:uri];
}

-(XMLElement*) addElementWithQName:(XMLQName*)name withDefaultURI:(NSString*)uri
{
    XMLElement* result;
    if (!uri)
        uri = _defaultURI;

    // Create a new XMLElement node
    result = [[XMLElement alloc] initWithQName:name withDefaultURI:uri];

    // Add the new node to us as a child
    [self addElement:result];

    [result release];
    return result;
}

-(XMLCData*) addCData:(const char*)cdata ofLength:(unsigned)cdatasz
{
    // If the last child is a CData object, just append this data to it
    if ([[_children lastObject] isKindOfClass:[XMLCData class]])
    {
        [[_children lastObject] appendText:cdata ofLength:cdatasz];
        return [_children lastObject];
    }
    else
    {
        XMLCData* result = [[XMLCData alloc] initWithCharPtr:cdata ofLength:cdatasz];
        [_children addObject:result];
        [result release];
        return result;
    }
}

-(XMLCData*) addCData:(NSString*)cdata
{
    // If the last child is a CData object, just append this data to it
    if ([[_children lastObject] isKindOfClass:[XMLCData class]])
    {
        [[_children lastObject] appendText:cdata];
        return [_children lastObject];
    }
    else
    {
        XMLCData* result = [[XMLCData alloc] initWithString:cdata];
        [_children addObject:result];
        [result release];
        return result;
    }    
}


// Raw child management
-(void) appendChildNode:(id <XMLNode>)node
{
    [_children addObject:node];
}

-(void) detachChildNode:(id <XMLNode>)node
{
    [_children removeObjectIdenticalTo:node];
}

// Child node info
-(BOOL) hasChildren
{
    return ([_children count] > 0);
}

-(unsigned) childCount
{
    return [_children count];
}

// Attribute management
-(void)      putAttribute:(NSString*)name withValue:(NSString*)value
{
    XMLQName* qn = [XMLQName construct:name withURI:_defaultURI];
    [_attribs setObject:value forKey:qn];
}

-(NSString*) getAttribute:(NSString*)name
{
    XMLQName* qn = [XMLQName construct:name withURI:_defaultURI];
    return [_attribs objectForKey:qn];
}

-(void) delAttribute:(NSString*)name
{
    XMLQName* qn = [XMLQName construct:name withURI:_defaultURI];
    [_attribs removeObjectForKey:qn];
}

-(BOOL)  cmpAttribute:(NSString*)name withValue:(NSString*)value
{
    XMLQName* qn = [XMLQName construct:name withURI:_defaultURI];
    return [[_attribs objectForKey:qn] isEqual:value];
}

-(void) putQualifiedAttribute:(XMLQName*)name withValue:(NSString*)value
{
    [_attribs setObject:value forKey:name];
}

-(NSString*) getQualifiedAttribute:(XMLQName*)qname
{
    return [_attribs objectForKey:qname];
}

-(BOOL)  cmpQualifiedAttribute:(XMLQName*)qname withValue:(NSString*)value
{
    return [[_attribs objectForKey:qname] isEqual:value];
}


-(void) delQualifiedAttribute:(XMLQName*)qname
{
    [_attribs removeObjectForKey:qname];
}

// Convert this node to string representation
-(NSString*) description
{
    return [XMLAccumulator process:self];
}

// Implementation of XMLNode protocol
-(XMLQName*) qname
{
    return _name;
}

-(NSString*) name
{
    return [_name name];
}

-(NSString*) uri
{
    return [_name uri];
}

-(void) description:(XMLAccumulator*)acc
{
    id it;
    NSEnumerator* attrib_keys = [_attribs keyEnumerator];

    [acc openElement:self];

    while ((it = [attrib_keys nextObject]))
    {
        [acc addAttribute:it withValue:[_attribs objectForKey:it] ofElement:self];
    }

	if ([_children count]) {
		[acc addChildren:_children ofElement:self];
		[acc closeElement:self];
	} else {
		[acc selfCloseElement];
	}
}

-(id<XMLNode>) firstChild
{
    return [_children objectAtIndex:0];
}

-(NSEnumerator*) childElementsEnumerator
{
    NSEnumerator* result = [[_ElementEnumerator alloc] initWithArray:_children];
    [result autorelease];
    return result;
}

// Extract first child CDATA from this Element
-(NSString*) cdata
{
    unsigned int i;
    for (i = 0; i < [_children count]; ++i)
    {
        id curr = [_children objectAtIndex:i];
        if ([curr isKindOfClass:[XMLCData class]])
            return [curr text];
    }
    return nil;
}

// Convert a name and uri into a XMLQName structure
-(XMLQName*) getQName:(NSString*)name ofURI:(NSString*)uri
{
    return [XMLQName construct:name withURI:uri];
}

-(XMLQName*) getQName:(const char*)expatname
{
    return [XMLQName construct:expatname];
}

-(XMLElement*) parent
{
    return _parent;
}

-(void) setParent:(XMLElement*)elem
{
    _parent = elem;
}

-(NSString*) defaultURI
{
    return _defaultURI;
}

-(NSString*) addUniqueIDAttribute
{
    static int UID = 0;
    NSString* result = [NSString stringWithFormat:@"ACID_%d", ++UID];
    [self putAttribute:@"id" withValue:result];
    return result;
}

-(void) setup
{}

-(void) addNamespaceURI:(NSString*)uri withPrefix:(NSString*)prefix
{}

-(void) delNamespaceURI:(NSString*)uri
{}

@end

