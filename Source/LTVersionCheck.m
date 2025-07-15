// 
// LTVersionCheck.m
//
// Copyright (c) 2020-2025 Larry M. Taylor
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software. Permission is granted to anyone to
// use this software for any purpose, including commercial applications, and to
// to alter it and redistribute it freely, subject to 
// the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source
//    distribution.
//

#import "LTVersionCheck.h"


@implementation LTVersionCheck

- (id)initWithAppName:(NSString *)appName
       withAppVersion:(NSString *)appVersion
        withLogHandle:(os_log_t)log
          withLogFile:(NSString *)logFile
{
    if ((self = [super init]))
    {
        // Set up logging
        mLog = log;
        mLogFile = [logFile copy];
        
        // Setup popup window
        mPopupWindow = [[LTPopup alloc] initWithWindowNibName:@"LTPopup"];
        mText = [[NSMutableString alloc] init];

        // Init variables
        mAppName = appName;
        mAppVersion = appVersion;
        mCheckCount = 0;
        mLatestVersion = nil;

        // Start version fetch
        [self getLatestVersion];

        // Start timer
        mVersionTimer = [NSTimer scheduledTimerWithTimeInterval:1
                         target:self selector:@selector(versionTimer:)
                         userInfo:nil repeats:YES];
    }
    
    return self;
}

- (void)versionTimer:(NSTimer *)timer
{
    if ([mDataTask state] != NSURLSessionTaskStateCompleted)
    {
        return;
    }

    [mVersionTimer invalidate];
    mVersionTimer = nil;
    
    if (mLatestVersion == nil)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Cannot retrieve latest version.");
        return;
    }
    else
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO, @"Latest version is %@",
              mLatestVersion);
    }

    NSUserDefaults *userDefaults =
        [[NSUserDefaultsController sharedUserDefaultsController] values];
    NSString *settingsKey = [NSString stringWithFormat:@"%@ VersionCheckCount",
                             mAppName];
    
    if ([userDefaults valueForKey:settingsKey] != nil)
    {
        NSDictionary *checkDict =
            [userDefaults valueForKey:settingsKey];
        NSNumber *checkCountNum = [checkDict objectForKey:mAppVersion];
        mCheckCount = (checkCountNum == nil) ? 0 : [checkCountNum intValue];
    }

    if (([mAppVersion isEqualToString:mLatestVersion] == NO) &&
             (mCheckCount < 3))
    {
        [mText setString:@""];
        [mText appendFormat:@"This is %@ version ", mAppName];
        [mText appendString:mAppVersion];
        [mText appendString:@". The latest released version is "];
        [mText appendString:mLatestVersion];
        [mText appendString:@"."];
        [mPopupWindow show];
        [mPopupWindow setText:(NSString *)mText];
        
        NSDictionary *check = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:(mCheckCount + 1)], mAppVersion, nil];
         
        [userDefaults setValue:check forKey:settingsKey];
    }
}

- (void)getLatestVersion
{
    NSURLSession *session = [NSURLSession sharedSession];
    NSString *urlString = @"https://www.larrymtaylor.com/versions.php";
    mDataTask = [session dataTaskWithURL:[NSURL URLWithString:urlString] 
                 completionHandler:^(NSData *data, NSURLResponse *response, 
                                     NSError *error)
    {
        if (error != nil)
        {
            LTLog(self->mLog, self->mLogFile, OS_LOG_TYPE_ERROR,
                  @"Network session error: %@", error);
        }
        else if ((data) && ([data length] > 0))
        {
            NSError *e = nil;
            NSDictionary *jsonDicts =
                [NSJSONSerialization JSONObjectWithData:data
                 options:NSJSONReadingMutableContainers error:&e];
 
            for (NSDictionary *jsonDict in jsonDicts)
            {
                self->mLatestVersion =
                    [jsonDict valueForKey:self->mAppName];
     
                if (self->mLatestVersion != nil)
                {
                    break;
                }
            }
        }
    }];
    
    [mDataTask resume];
}

@end
