/*
 * Written by Theo Hultberg (theo@iconara.net) 2004-03-09 with help from Boaz Stuller.
 * This code is in the public domain, provided that this notice remains.
 * Fixes and additions in Nov 2008 by Dominik Wagner
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>


/*!
 * @class          IXSCNotificationManager
 * @abstract       Listens for changes in the system configuration database
 *                 and posts the changes to the default notification center.
 * @discussion     To get notifications when the key "State:/Network/Global/IPv4"
 *                 changes, register yourself as an observer for notifications
 *                 with the name "State:/Network/Global/IPv4".
 *                 If you want to recieve notifications on any change in the
 *                 system configuration databse, register for notifications
 *                 on the IXSCNotificationManager object.
 *                 The user info in the notification is the data in the database
 *                 for the key you listen for.
 */
@interface IXSCNotificationManager : NSObject {
	SCDynamicStoreRef dynStore;
	CFRunLoopSourceRef rlSrc;
}


/*!
 * @method         setObservedKeys:regExes:
 * @abstract       An optimisation method that restricts the keys that are observed 
                   and for which Notification are posted to the Notification Center
 * @discussion     Default Value is inKeys:nil inRegExArray:[@".*"] which is in fact a 
                   observe all
 */
- (void)setObservedKeys:(NSArray *)inKeyArray regExes:(NSArray *)inRegExeArray;

@end
