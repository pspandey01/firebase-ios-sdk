#import "TestAppSender.h"

#import "AppDelegate.h"
#import "Foundation/Foundation.h"

static NSString *const kHTTPProdSendURL = @"https://fcm.googleapis.com/fcm/send";  // staging
static NSString *const kApiKey = @"AIzaSyCHRE3tI93djtCW6nuLncEI-Ey309nZPlQ";

typedef void(^SendRequestHandler)(NSData *data, NSURLResponse *response, NSError *error);

@interface TestAppSender ()

@property(nonatomic, readwrite, strong) NSURLSession *httpSendSession;
@property(nonatomic, readwrite, strong) NSURLSessionDataTask *httpSendTask;
@property(nonatomic, readwrite, strong) NSDateFormatter *dateFormatter;

@end

@implementation TestAppSender

- (instancetype)init {
  self = [super init];
  if (self) {
    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    _dateFormatter.dateStyle = NSDateFormatterMediumStyle;
  }
  return self;
}


- (BOOL)sendMessage:(NSDictionary *)message withHandler:(TestAppSendHandler)handler {
  if (_isFetching) {
    return NO;
  }

  NSMutableURLRequest *request =
      [[self class] requestToSendDownstreamMessageWithURL:kHTTPProdSendURL];
  NSError *jsonError;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&jsonError];
  if (!jsonError) {
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSString *content = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [request setHTTPBody:[content dataUsingEncoding:NSUTF8StringEncoding]];

    NSURLSession *session = [NSURLSession sharedSession];
    _isFetching = YES;
    __block NSString *result;

    SendRequestHandler sessionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
      if (error) {
        result = [NSString stringWithFormat:@"FIRMessaging HTTP "
                                            @"send request FAILED %@",
                                            error];
      } else {
        if (data != NULL) {
          result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
      }
      _isFetching = NO;
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(result);
      });
    };

    NSURLSessionDataTask *task =
        [session dataTaskWithRequest:request
                   completionHandler:^(NSData *__nullable data, NSURLResponse *__nullable response,
                                       NSError *__nullable error) {
                     dispatch_async(dispatch_get_main_queue(), ^{
                       sessionHandler(data, response, error);
                     });
                   }];

    [task resume];

    return YES;
  } else {
    return NO;
  }
}

- (NSString *)currentDate {
  return [self.dateFormatter stringFromDate:[NSDate date]];
}

+ (NSMutableURLRequest *)requestToSendDownstreamMessageWithURL:(NSString *)URL {
  NSURL *url = [NSURL URLWithString:URL];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [request setHTTPMethod:@"POST"];
  [request setValue:@"application/x-www-form-urlencoded;charset=UTF-8"
      forHTTPHeaderField:@"Content-Type"];
  [request setValue:[NSString stringWithFormat:@"key=%@", kApiKey]
      forHTTPHeaderField:@"Authorization"];
  [request setTimeoutInterval:60];  // 60s timeout
  return request;
}

@end
