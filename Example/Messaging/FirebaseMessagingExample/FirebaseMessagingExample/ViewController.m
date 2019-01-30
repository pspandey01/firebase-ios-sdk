#import "ViewController.h"

#import "AppDelegate.h"
#import "FIRMessaging.h"
#import "FIROptions.h"
#import "TestAppSender.h"

#import "googlemac/iPhone/InstanceID/Firebase/Lib/Source/FIRInstanceID.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/FIRApp.h"

static NSString *const kTestAppMessageIDKey = @"FIRMessaging_TEST_APP_MSG_ID_KEY";
static NSString *const kTestAppUpStreamID = @"526444376080";

@interface ViewController ()

// outlets
@property(weak, nonatomic) IBOutlet UITextView *logTextView;
@property(weak, nonatomic) IBOutlet UIButton *registerButton;
@property(weak, nonatomic) IBOutlet UIButton *unregisterButton;
@property(weak, nonatomic) IBOutlet UIButton *sendUpstreamButton;
@property(weak, nonatomic) IBOutlet UIButton *sendViaMCSButton;
@property(weak, nonatomic) IBOutlet UIButton *clearButton;
@property(weak, nonatomic) IBOutlet UIButton *sendViaAPNSButton;
@property(weak, nonatomic) IBOutlet UITabBarItem *gcmSendTabBarItem;
@property(weak, nonatomic) IBOutlet UISwitch *autoInitEnabled;
@property(weak, nonatomic) IBOutlet UISwitch *shouldUseMessageDelegate;

@property(nonatomic, readwrite, strong) NSMutableString *logTextString;
@property(nonatomic, readwrite, strong) TestAppSender *sender;

@end

@implementation ViewController

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Do any additional setup after loading the view.
  self.logTextString = [NSMutableString string];
  if (![[NSUserDefaults standardUserDefaults] integerForKey:kTestAppMessageIDKey]) {
    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:kTestAppMessageIDKey];
  }
  self.autoInitEnabled.on = [FIRMessaging messaging].isAutoInitEnabled;
  self.shouldUseMessageDelegate.on = [FIRMessaging messaging].useMessagingDelegateForDirectChannel;
}

- (TestAppSender *)sender {
  if (!_sender) {
    _sender = [[TestAppSender alloc] init];
  }
  return _sender;
}

- (BOOL)isSandboxApp {
  NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
  if ([bundleID hasSuffix:@".dev"]) {
    return YES;
  } else if ([bundleID hasSuffix:@".enterprise"]) {
    return NO;
  } else {
    [self addTextToLogView:@"Unknown app type (sandbox or prod). Defaults to sandbox"];
    return YES;
  }
}

#pragma mark - Callbacks

- (IBAction)didTapGetIIDAndTokenButton:(id)sender {
  [[FIRInstanceID instanceID]
      instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        if (error) {
          [self addTextToLogView:[NSString
                                     stringWithFormat:@"Getting IID and Token failed: %@", error]];
          return;
        }

        if (![result.instanceID
                isEqualToString:[result.token componentsSeparatedByString:@":"].firstObject]) {
          [self addTextToLogView:[NSString stringWithFormat:@"Error! Inconsistency between IID and "
                                                            @"Token! IID: %@\nToken: %@",
                                                            result.instanceID, result.token]];
        } else {
          [self addTextToLogView:[NSString stringWithFormat:@"IID: %@\nToken: %@",
                                                            result.instanceID, result.token]];
        }
      }];
}

- (IBAction)didTapRegisterButton:(id)sender {
  [self addTextToLogView:@"Trying to subscribe with FIRMessaging"];
  FIRMessaging *messaging = [FIRMessaging messaging];
  NSString *apnsLog = [NSString stringWithFormat:@"APNS Token: %@", [messaging APNSToken]];
  [self addTextToLogView:apnsLog];

  FIRInstanceID *appId = [FIRInstanceID instanceID];
  BOOL isConnecting = [self.sender isFetching];
  if (!isConnecting) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSString *defaultToken = [appId token];
#pragma clang diagnostic pop

    NSLog(@"Registration token: %@", defaultToken);
    [self addTextToLogView:[NSString
                               stringWithFormat:@"InstanceID New token success: %@", defaultToken]];
  } else {
    [self addTextToLogView:@"still subscribing to FIRMessaging wait..."];
  }
}

- (IBAction)didTapSendUPButton:(id)sender {
  [self addTextToLogView:@"Trying to send upstream message(via API)"];
  FIRMessaging *messaging = [FIRMessaging messaging];
  [[FIRInstanceID instanceID]
      tokenWithAuthorizedEntity:kTestAppUpStreamID
                          scope:@"*"
                        options:nil
                        handler:^(NSString *_Nullable token, NSError *_Nullable error) {
                          NSString *sendTo = [NSString
                              stringWithFormat:@"%@@gcm.googleapis.com", kTestAppUpStreamID];
                          int msgID = [[self class] incrementMessageID];

                          NSDictionary *message = @{
                            @"msg" : @"Upstream message from iOS App",
                            @"date" : [self.sender currentDate],
                          };

                          [messaging
                                sendMessage:message
                                         to:sendTo
                              withMessageID:[NSString stringWithFormat:@"gcm-test-app:%d", msgID]
                                 timeToLive:-1];
                        }];
}

/**
 *  Delete the FIRMessaging registration token for the app.
 */
- (IBAction)didTapUnregisterButton:(id)sender {
  [self addTextToLogView:@"Trying to delete InstanceID token"];
  FIRInstanceID *instanceID = [FIRInstanceID instanceID];

  BOOL isFetching = [self.sender isFetching];
  if (!isFetching) {
    __weak __typeof(self) weakSelf = self;
    FIRInstanceIDDeleteTokenHandler handler = ^void(NSError *error) {
      __typeof(self) strongSelf = weakSelf;

      if (error) {
        [strongSelf addTextToLogView:[NSString stringWithFormat:@"Delete Token failed: %@", error]];
        return;
      }

      [strongSelf addTextToLogView:@"Delete FIRMessaging Token success"];
    };
    NSString *senderID = [FIRApp defaultApp].options.GCMSenderID;
    [instanceID deleteTokenWithAuthorizedEntity:senderID scope:@"*" handler:handler];
  } else {
    [self addTextToLogView:@"Waiting for previous operation to complete"];
  }
}

/**
 *  Triggers a downstream send which should be received using MCS connection.
 */
- (IBAction)didTapSendMCSButton:(id)sender {
  if (![self.sender isFetching]) {
    [self addTextToLogView:@"Trying to send MCS message(via HTTP)"];
    FIRMessaging *messaging = [FIRMessaging messaging];
    NSString *registrationToken = messaging.FCMToken;
    if ([registrationToken length]) {
      [self sendMessageUsingRegistrationIDForDisplay:NO];
    } else {
      NSString *message =
          @"Trying to send message to invalid nil registration. Call register first.";
      [self showAlertWithTitle:@"Invalid Send." message:message];
    }
  } else {
    [self addTextToLogView:@"Still trying to send via HTTP. wait..."];
  }
}

/**
 *  Clears the text view.
 */
- (IBAction)didTapClearButton:(id)sender {
  NSRange range = NSMakeRange(0, [self.logTextString length]);
  [self.logTextString deleteCharactersInRange:range];
  self.logTextView.text = self.logTextString;
}

/**
 *  Triggers a downstream send which should be received via APNS.
 */
- (IBAction)didTapSendAPNSButton:(id)sender {
  if (![self.sender isFetching]) {
    [self addTextToLogView:@"Trying to send APNS message(via HTTP)"];
    FIRMessaging *messaging = [FIRMessaging messaging];
    NSString *registrationToken = messaging.FCMToken;
    if ([registrationToken length]) {
      [self sendMessageUsingRegistrationIDForDisplay:YES];
    } else {
      NSString *message =
          @"Trying to send message to invalid nil registration. Call register first.";
      [self showAlertWithTitle:@"Invalid Send." message:message];
    }
  } else {
    [self addTextToLogView:@"Still trying to send via HTTP. wait..."];
  }
}

- (IBAction)autoInitSwitched:(id)sender {
  [FIRMessaging messaging].autoInitEnabled = self.autoInitEnabled.on;
}

- (IBAction)messageDelegateSwitched:(id)sender {
  [FIRMessaging messaging].useMessagingDelegateForDirectChannel = self.shouldUseMessageDelegate.on;
  if (self.shouldUseMessageDelegate.on) {
    [self addTextToLogView:
              @"\n'Should Use Message Delegate' flag is on.\nDirect channel messages are all "
              @"delivered in FIRMessagingDelegate messaging:didReceiveMessage:\n"];
  } else {
    [self
        addTextToLogView:
            @"\n'Should Use Message Delegate' flag is off.\nDirect channel messages below iOS 9 "
            @"are delivered in application:didReceiveRemoteNotification:fetchCompletionHandler:\n"];
  }
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
  if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
  } else {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *__nonnull action){
                                                   }];

    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
  }
}

#pragma mark - TestAppDisplayNotification

- (void)showText:(NSString *)text {
  [self addTextToLogView:text];
}

#pragma mark - Messages

- (void)sendMessageUsingRegistrationIDForDisplay:(BOOL)isDisplay {
  NSMutableDictionary *message = [NSMutableDictionary dictionary];
  FIRMessaging *messaging = [FIRMessaging messaging];
  NSString *registrationToken = messaging.FCMToken;

  if (isDisplay) {
    message[@"notification"] = @{
      @"body" : @"This is the body of the notification",
      @"title" : @"This is the title of the notification",
      @"badge" : @"0",
    };
  } else {
    message[@"data"] = @{
      @"body" : @"This is the body of the notification",
      @"title" : @"This is the title of the notification",
      @"badge" : @"0",
      @"sound" : @"default",
    };
  }

  message[@"to"] = registrationToken;

  BOOL sendSuccess =
      [self.sender sendMessage:message
                   withHandler:^(NSString *result) {
                     NSString *message =
                         [NSString stringWithFormat:@"Downstream send to RegID result: %@", result];
                     [self addTextToLogView:message];
                   }];

  NSString *dateString = [self.sender currentDate];
  if (sendSuccess) {
    NSString *log = [NSString stringWithFormat:@"Trying to send downstream at time %@", dateString];
    [self addTextToLogView:log];
  } else {
    NSString *errorStr = [NSString stringWithFormat:@"Error while sending. Try again."];
    [self addTextToLogView:errorStr];
  }
}

#pragma mark - Private

- (void)addTextToLogView:(NSString *)text {
  if ([text length]) {
    [self.logTextString appendString:text];
    [self.logTextString appendString:@"\n"];
    self.logTextView.text = [self.logTextString copy];

    [self scrollToBottomText:text inTextView:self.logTextView];
  }
}

- (void)scrollToBottomText:(NSString *)text inTextView:(UITextView *)textView {
  NSRange bottom = NSMakeRange(textView.text.length - text.length, text.length);
  [textView scrollRangeToVisible:bottom];
}

#pragma mark - Private

+ (int)incrementMessageID {
  int msgId = (int)[[NSUserDefaults standardUserDefaults] integerForKey:kTestAppMessageIDKey] + 1;
  [[NSUserDefaults standardUserDefaults] setInteger:msgId forKey:kTestAppMessageIDKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  return msgId;
}

@end
