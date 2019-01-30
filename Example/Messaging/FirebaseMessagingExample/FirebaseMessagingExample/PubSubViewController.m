#import "PubSubViewController.h"

#import "FIRAnalytics.h"
#import "FIRMessaging.h"

#import "AppDelegate.h"
#import "TestAppSender.h"

static NSString *const kTopicRegexPattern = @"[a-zA-Z0-9-_.~%]+";

@interface PubSubViewController ()

// Outlets
@property (weak, nonatomic) IBOutlet UIButton *subscribeButton;
@property (weak, nonatomic) IBOutlet UIButton *unsubscribeButton;
@property (weak, nonatomic) IBOutlet UIButton *sendViaMCSButton;
@property (weak, nonatomic) IBOutlet UIButton *sendViaAPNSButton;
@property (weak, nonatomic) IBOutlet UIButton *clearButton;
@property (weak, nonatomic) IBOutlet UIButton *fakeEventButton;

@property(nonatomic, readwrite, strong) NSMutableString *logTextString;
@property(nonatomic, readwrite, assign) BOOL subscribingToTopic;
@property(nonatomic, readwrite, strong) TestAppSender *sender;

@end

@implementation PubSubViewController

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {
  [super willRotateToInterfaceOrientation:toInterfaceOrientation
                                 duration:duration];
  [self.view setNeedsUpdateConstraints];
}

- (TestAppSender *)sender {
  if (!_sender) {
    _sender = [[TestAppSender alloc] init];
  }
  return _sender;
}

- (IBAction)didTapSubscribeButton:(id)sender {
  NSString *topic = self.topicField.text;
    [[FIRMessaging messaging]
        subscribeToTopic:topic
              completion:^(NSError *error) {
                if (error) {
                  [self
                      addTextToLogView:[NSString
                                           stringWithFormat:@"Subscription failed with error: %@.",
                                                            error.description]];
                } else {
                  [self
                      addTextToLogView:[NSString stringWithFormat:@"Successfully subscribed to %@.",
                                                                  topic]];
                }
              }];
}

- (IBAction)didTapUnsubscribeButton:(id)sender {
  NSString *topic = self.topicField.text;
    [[FIRMessaging messaging]
        unsubscribeFromTopic:topic
                  completion:^(NSError *error) {
                    if (error) {
                      [self addTextToLogView:
                                [NSString stringWithFormat:@"Unsubscription failed with error: %@.",
                                                           error.description]];
                    } else {
                      [self
                          addTextToLogView:[NSString
                                               stringWithFormat:@"Successfully unsubscribed to %@.",
                                                                topic]];
                    }
                  }];
}

- (IBAction)didTapSendByMCSButton:(id)sender {
  if (![self.sender isFetching]) {
    NSString *topic = self.topicField.text;
    if ([topic length]) {
      [self sendMessageToTopic:topic isDisplay:NO];
    } else {
      NSString *message = [NSString
          stringWithFormat:@"Invalid topic. Trying to send message to invalid topic %@", topic];
      [self addTextToLogView:message];
    }
  } else {
    [self addTextToLogView:@"Still trying to send downstream message to topic. wait..."];
  }
}

- (IBAction)didTapSendByAPNSButton:(id)sender {
  if (![self.sender isFetching]) {
    NSString *topic = self.topicField.text;
    if ([topic length]) {
      [self sendMessageToTopic:topic isDisplay:YES];
    } else {
      NSString *message = [NSString
          stringWithFormat:@"Invalid topic. Trying to send message to invalid topic %@", topic];
      [self addTextToLogView:message];
    }
  } else {
    [self addTextToLogView:@"Still trying to send downstream message to topic. wait..."];
  }
}

- (IBAction)didTapClearButton:(id)sender {
  NSRange range = NSMakeRange(0, [self.logTextString length]);
  [self.logTextString deleteCharactersInRange:range];
  self.textView.text = self.logTextString;
}



- (IBAction)didTapFakeEventButton:(id)sender {
  // Log fake events for testing (http://b/27743432)
  [self logPurchaseEventWithValue:1.99];
  // Log a dev defined event.
  NSDictionary *params = @{@"time" : @(PubSubTimestampInMilliseconds())};
  [self logEventWithName:@"fcm_promo" params:params];
}

- (void)sendMessageToTopic:(NSString *)topic
                 isDisplay:(BOOL)isDisplay {
  int64_t time = [[NSDate date] timeIntervalSince1970];
  NSString *dateString = [self.sender currentDate];
  NSDictionary *contentDict = @{
                                @"to" : topic,
                                @"data" : @{
                                    @"text" : @"Hello_FIRMessaging_Pubsub_IOS",
                                    @"id" : @"Hello_World!!",
                                    @"time" : @(time),
                                    @"date" : dateString,
                                    },
                                };
  NSMutableDictionary *contentJSONToSend = [contentDict mutableCopy];
  if (isDisplay) {
    contentJSONToSend[@"notification"] = @{
                                           @"text" : @"Hello, this is a display notification",
                                           };
  }

  BOOL success = [self.sender sendMessage:contentJSONToSend withHandler:^(NSString *result) {
    NSString *message = [NSString stringWithFormat:@"Downstream send to topic: %@ result: %@",
                         topic, result];
    [self addTextToLogView:message];
  }];

  if (success) {
    NSString *log =
        [NSString stringWithFormat:@"Trying to send downstream message to topic %@ at time %@",
         topic, dateString];
    [self addTextToLogView:log];
  } else {
    NSString *errorStr =
        [NSString stringWithFormat:@"Failed to send downstream message to topic %@. Try again.",
         topic];
    [self addTextToLogView:errorStr];
  }
}

- (void)addTextToLogView:(NSString *)text {
  if ([text length]) {
    if (!self.logTextString) {
      self.logTextString = [NSMutableString string];
    }
    [self.logTextString appendString:text];
    [self.logTextString appendString:@"\n"];
    self.textView.text = self.logTextString;

    [self scrollToBottomText:text inTextView:self.textView];
  }
}

- (void)scrollToBottomText:(NSString *)text inTextView:(UITextView *)textView {
  NSRange bottom = NSMakeRange(textView.text.length - text.length, text.length);
  [textView scrollRangeToVisible:bottom];
}

#pragma mark - Analytics Events

- (void)logPurchaseEventWithValue:(double)value {
  NSDictionary *params = @{
                           kFIRParameterValue : @(value),
                           kFIRParameterCurrency : @"USD"
                           };
  [self logEventWithName:kFIREventEcommercePurchase params:params];
}

- (void)logEventWithName:(NSString *)eventName params:(NSDictionary *)params {
  if (!eventName.length) {
    return;
  }
  [FIRAnalytics logEventWithName:eventName parameters:params];
  NSString *log = [NSString stringWithFormat:@"Sending event: %@ params: %@", eventName, params];
  [self addTextToLogView:log];
}

#pragma mar - Time Utilities

int64_t PubSubCurrentTimestampInSeconds() {
  return (int64_t)[[NSDate date] timeIntervalSince1970];
}

int64_t PubSubTimestampInMilliseconds() {
  return (int64_t)(PubSubCurrentTimestampInSeconds() * 1000.0);
}

#pragma mark - TestAppDisplayNotification

- (void)showText:(NSString *)text {
  [self addTextToLogView:text];
}

#pragma mark - UIViewController override

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {

  UITouch *touch = [[event allTouches] anyObject];
  if ([self.topicField isFirstResponder] && [touch view] != self.topicField) {
    [self.topicField resignFirstResponder];
  }
  [super touchesBegan:touches withEvent:event];
}

- (IBAction)topicFieldShouldReturn:(id)sender {
  UITextField *textField = (UITextField *)sender;
  [textField resignFirstResponder];
}

+ (NSRegularExpression *)topicRegex {
  NSError *error;
  NSRegularExpression *topicRegex =
      [NSRegularExpression regularExpressionWithPattern:kTopicRegexPattern
                                                options:NSRegularExpressionAnchorsMatchLines
                                                  error:&error];
  if (error) {
    return nil;
  }
  return topicRegex;
}

@end
