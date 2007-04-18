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
// $Id: JabberID.h,v 1.2 2005/04/29 18:44:44 gbooker Exp $
//============================================================================

/*!
  @class JabberID
  @abstract provides a representation for a Jabber Identifier
  @discussion represents a Jabber Identifier, a unique network
  identifier used for routing to and communicating with an entity on
  the Jabber Network. This class also provides the logic for comparing
  two Jabber Identifiers including handling the partial case
  insensitivity.
*/
@interface JabberID : NSObject <NSCopying, NSCoding>
{
    NSString* _username;
    NSString* _hostname;
    NSString* _resource;
    NSString* _complete;
    JabberID* _userhost_jid;
    unsigned int _hash_value; // cache the hash value, since it is
			      // time-consuming to create
}

/*!
  @method hash
  @abstract return an unsigned value associated with the value of this
  JabberID. This value will remain constant over the lifetime of the
  JabberID instance, and will be equivalent to the value of another
  JabberID instance which would be considered equivalent (although
  non-equivalent objects could have the same hash value).
*/
-(unsigned) hash;

/*!
  @method initWithCoder
  @abstract Initializes a newly allocated instance from data in
  decoder. Returns self.
*/
-(id) initWithCoder:(NSCoder*) coder;

/*!
  @method encodeWithCoder
  @abstract Encodes the receiver using encoder.
*/
-(void) encodeWithCoder:(NSCoder*) coder;

/*!
  @method copyWithZone
  @abstract Returns a new instance that's a copy of the receiver.
  @discussion Returns a new instance that's a copy of the
  receiver. Memory for the new instance is allocated from zone, which
  may be NULL.  If zone is NULL, the new instance is allocated from
  the default zone, which is returned from the NSDefaultMallocZone.
  The returned object is implicitly retained by the sender, who is
  responsible for releasing it.  The copy returned is immutable if the
  consideration "immutable vs. mutable" applies to the receiving
  object; otherwise the exact nature of the copy is determined by the
  class.
 */
-(id) copyWithZone:(NSZone*)zone;

/*!
  @method initWithString
  @abstract Initializes a newly allocated instance from a NSString.
  Returns self, or nil if the object is not a valid Jabber
  Identifier
*/
-(id) initWithString:(NSString*)jidstring;
-(id) initWithEscapedString:(NSString*)jidstring;

-(id) initWithFormat:(NSString*)fmt, ...;
+(id) withFormat:(NSString*)fmt, ...;


/*!
  @method initWithUserHost:andResource
  @abstract Initializes a newly allocated instance from two NSString
  objects. Returns self, or nil if the object is not a valid Jabber
  Identifier.
  @param userhost  userhost portion of the Jabber Identifier
  @param resource  resource portion of the Jabber Identifier
*/
-(id) initWithUserHost:(NSString*)userhost
           andResource:(NSString*)resource;

-(void) dealloc;

/*!
  @method username
  @abstract Retrieve the username (Node) portion of the Jabber
  Identifier, or "" if none.
 */
-(NSString*) username;
/*!
  @method userhost
  @abstract Retrieve the userhost portion of the Jabber Identifier
*/
-(NSString*) userhost;
/*!
  @method hostname
  @abstract Retrieve the hostname (Domain) portion of the Jabber Identifier
*/
-(NSString*) hostname;
/*!
  @method resource
  @abstract Retrieve the resource portion of the Jabber Identifier, or
  "" if none.
*/
-(NSString*) resource;
-(BOOL) hasUsername;
/*!
  @method hasResource
  @abstract returns YES if there is a resource on the Jabber Identifier
*/
-(BOOL) hasResource;
/*!
  @method hasUsername
  @abstract returns YES if there is a username (Node) on the Jabber
  Identifier
*/
-(BOOL) hasUsername;

/*!
  @method userhostJID
  @abstract returns a Jabber Identifier without any resource
  portion. Returns self if there was no resource
*/
-(JabberID*) userhostJID;

/*!
  @method completeID
  @abstract returns a NSString representation of the full Jabber Identifier
*/
-(NSString*) completeID;
-(NSString*) escapedCompleteID;
-(JabberID*) userhostJID;

/*!
    @method isEqual:
    @abstract determine if two full Jabber Identifiers are equivalent addresses
    @param other second jabber identifier to which we are comparing
    @return YES if equal, NO otherwise
 */
-(BOOL) isEqual:(JabberID*)other;
-(NSComparisonResult) compare:(JabberID *)object;

/*
 @method isUserhostEqual:
 @abstract determine if two Jabber Identifiers have matching userhosts
 @param other second Jabber Identifier to which we are comparing
 @return YES if equal, NO otherwise
 */
-(BOOL) isUserhostEqual:(JabberID*)other;
-(NSComparisonResult) compareUserhost:(JabberID *)object;


/*!
  @method parseString:intoUsername:intoUserHost:intoHostname:intoResource:
  @abstract break a jid into its component parts, returning a BOOL
  indicating if the Jabber Identifier was valid
*/
+(BOOL) parseString:(NSString*)jid 
       intoUsername:(NSString**)username
       intoHostname:(NSString**)hostname
       intoResource:(NSString**)resource
       intoComplete:(NSString**)complete;

/*!
  @method withString
  @abstract create a temporary from NSString. Returns self, or nil if
  the object is not a valid Jabber Identifier
 */
+(id) withString:(NSString*)jidstring;
/*!
  @method withUserHost:andResource
  @abstract create a temporary from two NSString objects. Returns
  self, or nil if the object is not a valid Jabber Identifier
  @param userhost  userhost portion of the Jabber Identifier
  @param resource  resource portion of the Jabber Identifier
 */
+(id) withUserHost:(NSString*)userhost
      andResource:(NSString*)resource;
@end
