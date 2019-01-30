#import "AppDelegate.h"

// For iOS 10 display notification only
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
#import <UserNotifications/UserNotifications.h>
#endif

#import "FIRAnalytics.h"
#import "FIRMessaging.h"
#import "FIRMessagingClient.h"
#import "FIRMessaging_Private.h"
#import "FIROptions.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/FIRApp.h"

#import "ViewController.h"

static const int64_t kTimeIntervalBetweenProbeMessagesInSeconds = 10 * 60;  // 10 minutes

static NSString *const kProbeReplyTo = @"reply-message-id";
static NSString *const kProbeReceivedTimestamp = @"probe-received-ts";
static NSString *const kProbeReplyDate = @"probe-reply-date";
static NSString *const kSenderIDPlistKey = @"SenderID";
static NSString *const kAPIKeyPlistKey = @"APIKey";
static NSString *const kScionDebugEventProbabilityPattern = @"scionDebugEventProbability:(\\d+)";
static NSString *const kScionDebugEventName = @"probabilistic_debug_event";
static NSString *const kDuplicateMessage = @"===========Duplicate Message: %@============\n";

AppSettings *appInfo;

@interface AppDelegate ()

@property(nonatomic, readwrite, assign) int64_t lastReceivedProberMessage;
@property(nonatomic, readwrite, strong) NSDateFormatter *dateFormatter;
@property(nonatomic, readwrite, assign) BOOL gcmDisconnectNotificationShown;

@end

#pragma mark - implement FCM protocol to receive remote data message for iOS 10
// Implement UNUserNotificationCenterDelegate to receive display notification via APNS
// Implement FIRMessagingDelegate to receive data message via MCS
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface AppDelegate ()<UNUserNotificationCenterDelegate>
@end
#endif

@interface AppDelegate ()<FIRMessagingDelegate>
@end

@implementation AppDelegate {
  NSRegularExpression *scionDebugEventSpecRegex;
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.
  _dateFormatter = [[NSDateFormatter alloc] init];
  // set current time
  _dateFormatter.timeZone = [NSTimeZone localTimeZone];
  // year-month-day hour-minutes-seconds AM/PM
  [_dateFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss a"];

  scionDebugEventSpecRegex =
      [NSRegularExpression regularExpressionWithPattern:kScionDebugEventProbabilityPattern
                                                options:0
                                                  error:nil];

  // Enable Analytics debug mode
  [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"/google/measurement/debug_mode"];

  // Configure Firebase app.
  [FIRApp configure];

  // Configure TestApp.
  appInfo = [[AppSettings alloc] init];

  // Enabling this will connect/disconnect from MCS automatically
  [FIRMessaging messaging].shouldEstablishDirectChannel = YES;

  // Listen for token refresh changes and iOS 10 data messages
  [FIRMessaging messaging].delegate = self;

  if ([UNUserNotificationCenter class] != nil) {
    // iOS 10 or later
    // For iOS 10 display notification (sent via APNS)
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    UNAuthorizationOptions authOptions =
        UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:authOptions
                      completionHandler:^(BOOL granted, NSError *_Nullable error) {
                          // ...
                      }];
  } else {
    // iOS 10 notifications aren't available; fall back to iOS 8-9 notifications.
    UIUserNotificationType types =
        (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge |
         UIRemoteNotificationTypeNewsstandContentAvailability);
    UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [application registerUserNotificationSettings:settings];
  }
  [application registerForRemoteNotifications];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(messagingConnectionStateDidChange:)
                                               name:FIRMessagingConnectionStateChangedNotification
                                             object:nil];

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
  // For iOS 10 display notification (sent via APNS)
  [[UNUserNotificationCenter currentNotificationCenter] setDelegate:self];
#endif

  return YES;
}


#pragma mark - Local Notification

- (void)application:(UIApplication *)application
    didReceiveLocalNotification:(UILocalNotification *)notification {
  NSString *title = [NSString stringWithFormat:@"Local Notif: %@", notification.alertTitle];
  [appInfo displayAlertWithTitle:title message:notification.alertBody];
}

#pragma mark - Remote Notifications

- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  NSLog(@"Registered with APNS: %@", deviceToken);
  [appInfo logMessageOnScreen:[NSString stringWithFormat:@"apns_token: %@",
                                                         [self APNSTokenAsString:deviceToken]]];
}

- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  NSLog(@"Fail to register with APNS: %@", error);
  [appInfo
      logMessageOnScreen:[NSString stringWithFormat:@"apns_token: %@", error.localizedDescription]];
}

- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
  FIRMessagingMessageInfo *messageInfo = [[FIRMessaging messaging] appDidReceiveMessage:userInfo];
  BOOL duplicateMessage = (messageInfo.status != FIRMessagingMessageStatusNew);
  if (!duplicateMessage) {
    [self didReceiveMessage:userInfo];
    [appInfo logMessageOnScreen:userInfo.description];
  } else {
    NSString *message =
        [NSString stringWithFormat:kDuplicateMessage, userInfo];
    [appInfo logMessageOnScreen:message];
  }
}

// Receive both display notification and data message for devices < iOS 10
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  [appInfo logMessageOnScreen:@"Direct channel message arrived at UIApplicationDelegate"];

  FIRMessagingMessageInfo *messageInfo = [[FIRMessaging messaging] appDidReceiveMessage:userInfo];
  BOOL duplicateMessage = (messageInfo.status != FIRMessagingMessageStatusNew);

  if (!duplicateMessage) {
    [appInfo logMessageOnScreen:userInfo.description];
    [self didReceiveMessage:userInfo];
  } else {
    NSString *message =
        [NSString stringWithFormat:kDuplicateMessage, userInfo];
    [appInfo logMessageOnScreen:message];
  }

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   completionHandler(UIBackgroundFetchResultNewData);
                 });
}

#pragma mark - Notifiation Callbacks

- (void)receivedFIRMessagingMessage:(NSNotification *)notification {
  NSDictionary *message = notification.userInfo;
  [self didReceiveMessage:message];
}

- (void)didReceiveMessage:(NSDictionary *)message {
  NSLog(@"Received Message: %@", message);
  NSString *replyTo = message[kProbeReplyTo];
  if ([replyTo length]) {
    NSDate *date = [NSDate date];

    // Reply
    [self sendMessageWithID:replyTo];

    if (!self.gcmDisconnectNotificationShown &&
        (![[[FIRMessaging messaging] client] isConnected] ||
         ![[[FIRMessaging messaging] client] isConnectionActive])) {
      UILocalNotification *notification = [[UILocalNotification alloc] init];
      notification.fireDate = [[NSDate date] dateByAddingTimeInterval:1];
      notification.alertBody = @"App not connected with FIRMessaging";
      notification.applicationIconBadgeNumber = 1;
      [[UIApplication sharedApplication] scheduleLocalNotification:notification];
      self.gcmDisconnectNotificationShown = YES;
    }

    // Check if APNS is not delivering messages correctly
    int64_t currentMessageReceivedTs = [date timeIntervalSince1970];
    if (currentMessageReceivedTs - self.lastReceivedProberMessage >
        kTimeIntervalBetweenProbeMessagesInSeconds) {
      UILocalNotification *notification = [[UILocalNotification alloc] init];
      notification.fireDate = [date dateByAddingTimeInterval:1];
      NSString *message = [NSString
          stringWithFormat:@"Not receiving APNS messages. Last message %@",
                           [self humanReadableDateForTimestamp:self.lastReceivedProberMessage]];
      notification.alertBody = message;
      [[UIApplication sharedApplication] scheduleLocalNotification:notification];
    }
    self.lastReceivedProberMessage = currentMessageReceivedTs;

    // Update any UI elements if required
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_RECEIVE_PROBE_MESSAGE
                                                        object:nil];
  }

  [self logProbabilisticScionEventForMessage:message];
}

/**
 * If the message contains a notification body with the text "scionDebugEventProbability:N", where N
 * is an integer in [0, 100], this method logs a custom Scion event with probability N.
 */
- (void)logProbabilisticScionEventForMessage:(NSDictionary *)message {
  NSString *body = [self bodyFromNotification:message];
  if (!body) {
    return;
  }

  NSInteger p = [self scionEventProbabilityForNotificationBody:body];

  // Random integer in (0, 100].
  NSInteger r = arc4random_uniform(100) + 1;

  NSLog(@"Notification body requests logging of Scion event with probability %ld", (long)p);
  if (r > p) {
    NSLog(@"Not logging Scion event");
    return;
  }

  NSLog(@"Logging Scion event");
  [FIRAnalytics logEventWithName:kScionDebugEventName parameters:@{}];
}

/**
 * Retrieves a string body from a APNS notification. Sometimes aps dictionaries are of the form:
 * {
 *   alert : "This is a body",
 * }
 * while other times they can be:
 * {
 *   alert : {
 *     body : "This is a body",
 *     title : ...
 *     ...
 *   }
 * }
 */
- (nullable NSString *)bodyFromNotification:(NSDictionary *)notification {
  NSDictionary *aps = notification[@"aps"];
  if (!aps || ![aps isKindOfClass:[NSDictionary class]]) {
    return nil;
  }
  id alert = aps[@"alert"];
  if ([alert isKindOfClass:[NSString class]]) {
    return (NSString *)alert;
  } else if ([alert isKindOfClass:[NSDictionary class]]) {
    NSString *alertBody = ((NSDictionary *)alert)[@"body"];
    if ([alertBody isKindOfClass:[NSString class]]) {
      return alertBody;
    }
  }
  return nil;
}

/**
 * Determines the probability with which a custom Scion event should be fired in response to this
 * message.
 *
 * @param body Notification body text.
 * @return Probability as a percentage in [0, 100].
 */
- (NSInteger)scionEventProbabilityForNotificationBody:(NSString *)body {
  NSTextCheckingResult *match =
      [scionDebugEventSpecRegex firstMatchInString:body
                                           options:0
                                             range:NSMakeRange(0, [body length])];
  if (match == nil) {
    return 0;
  }

  NSString *capture = [body substringWithRange:[match rangeAtIndex:1]];
  int p = [capture intValue];
  if (p > 100) {
    return 0;
  }
  return p;
}

// send message back to prober
- (void)sendMessageWithID:(NSString *)messageID {
  NSMutableDictionary *message = [NSMutableDictionary dictionary];
  message[@"id"] = [messageID copy];
  int64_t time = [[NSDate date] timeIntervalSince1970] * 1000.0;
  message[kProbeReceivedTimestamp] = @(time);
  message[kProbeReplyDate] = [self currentHumanReadableDate];
  NSString *kSenderID = [FIRApp defaultApp].options.GCMSenderID;
  NSString *toSender = [NSString stringWithFormat:@"%@@gcm.googleapis.com", kSenderID];

  [[FIRMessaging messaging] sendMessage:message to:toSender withMessageID:messageID timeToLive:-1];

  // Logging
  NSDate *date = [NSDate date];
  NSString *event = [NSString stringWithFormat:@"Prober: Probe Message reply: %@, send at: %@",
                                               messageID, [self.dateFormatter stringFromDate:date]];
  [appInfo logMessageOnScreen:event];
}

- (NSString *)currentHumanReadableDate {
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.timeStyle = NSDateFormatterMediumStyle;
  formatter.dateStyle = NSDateFormatterMediumStyle;
  return [formatter stringFromDate:[NSDate date]];
}

- (NSString *)humanReadableDateForTimestamp:(int64_t)timestamp {
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
  return [self.dateFormatter stringFromDate:date];
}

#pragma mark - Universal Links and Handoff

- (BOOL)application:(UIApplication *)application
    continueUserActivity:(nonnull NSUserActivity *)userActivity
      restorationHandler:
#if defined(__IPHONE_12_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0)
          (nonnull void (^)(NSArray<id<UIUserActivityRestoring>> *_Nullable))restorationHandler {
#else
          (nonnull void (^)(NSArray *_Nullable))restorationHandler {
#endif  // __IPHONE_12_0
  if (userActivity.activityType == NSUserActivityTypeBrowsingWeb) {
    [appInfo displayAlertWithTitle:@"Link Received" message:userActivity.webpageURL.absoluteString];
    return YES;
  }
  return NO;
}

#pragma mark - FIRMessagingDelegate

- (void)messaging:(nonnull FIRMessaging *)messaging
    didReceiveRegistrationToken:(nonnull NSString *)fcmToken {
  NSString *message = [NSString stringWithFormat:@"Refreshed token: %@", messaging.FCMToken];
  [appInfo logMessageOnScreen:message];
}

- (void)messaging:(nonnull FIRMessaging *)messaging
    didReceiveMessage:(nonnull FIRMessagingRemoteMessage *)remoteMessage {
  [appInfo logMessageOnScreen:@"Direct channel message arrived at FIRMessagingDelegate"];
  NSString *messageID = remoteMessage.messageID;
  NSDictionary *userInfo = remoteMessage.appData;
  FIRMessagingMessageInfo *messageInfo = [[FIRMessaging messaging] appDidReceiveMessage:userInfo];
  BOOL isMessageDuplicate = messageInfo.status != FIRMessagingMessageStatusNew;

  if (!isMessageDuplicate) {
    [appInfo logMessageOnScreen:[NSString stringWithFormat:@"\nMessageID: %@\n%@\n", messageID,
                                                           userInfo.description]];
    [self didReceiveMessage:userInfo];
  } else {
    NSString *message = [NSString stringWithFormat:@"\n=============Duplicate Message ID %@, %@\n",
                                                   messageID, userInfo.description];
    [appInfo logMessageOnScreen:message];
  }
}

#pragma mark - FIRMessagingDataMessageManager

- (void)willSendDataMessageWithID:(NSString *)messageID error:(NSError *)error {
  NSString *event;
  if (messageID) {
    event = [NSString stringWithFormat:@"Will send message with id: %@", messageID];
  } else {
    event = [NSString
        stringWithFormat:@"Failed to send message with id: %@ error: %@", messageID, error];
  }
  [appInfo logMessageOnScreen:event];
}

- (void)didSendDataMessageWithID:(NSString *)messageID {
  if ([messageID length]) {
    NSString *event =
        [NSString stringWithFormat:@"Did successfully send message with id: %@", messageID];
    [appInfo logMessageOnScreen:event];
  }
}

#pragma mark - FIRMessaging Notifications
- (void)messagingConnectionStateDidChange:(NSNotification *)notification {
  if ([FIRMessaging messaging].isDirectChannelEstablished) {
    [appInfo logMessageOnScreen:@"FCM Direct Channel Established"];
  } else {
    [appInfo logMessageOnScreen:@"FCM Direct Channel Torn Down"];
  }
}

#pragma mark - UNUserNotificationDelegate protocol
// Only to receive display notitification for iOS 10+ devices
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
  NSDictionary *userInfo = notification.request.content.userInfo;
  FIRMessagingMessageInfo *messageInfo = [[FIRMessaging messaging] appDidReceiveMessage:userInfo];
  BOOL duplicateMessage = (messageInfo.status != FIRMessagingMessageStatusNew);

  if (!duplicateMessage) {
    [appInfo logMessageOnScreen:userInfo.description];
    [self didReceiveMessage:userInfo];
  } else {
    NSString *message =
        [NSString stringWithFormat:kDuplicateMessage, userInfo];
    [appInfo logMessageOnScreen:message];
  }

  completionHandler(UNNotificationPresentationOptionAlert);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completionHandler {
  NSDictionary *userInfo = response.notification.request.content.userInfo;

  // Print full message.
  NSLog(@"%@", userInfo);

  completionHandler();
}

#endif

- (NSString *)APNSTokenAsString:(NSData *)APNSToken {
  if (APNSToken) {
    const unsigned *bytes = [APNSToken bytes];
    // might not be super necessary to convert the byte order
    NSString *hexToken = [NSString
        stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x", ntohl(bytes[0]), ntohl(bytes[1]),
                         ntohl(bytes[2]), ntohl(bytes[3]), ntohl(bytes[4]), ntohl(bytes[5]),
                         ntohl(bytes[6]), ntohl(bytes[7])];
    return hexToken;
  }
  return nil;
}
@end
