#ifndef CEASYBAR_EVENTKIT_COMPAT_H
#define CEASYBAR_EVENTKIT_COMPAT_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Reads EventKit's compatibility travel-time value without allowing an Objective-C exception to escape.
FOUNDATION_EXPORT bool easybar_eventkit_read_travel_time(
  NSObject *object,
  double *seconds
);

/// Writes EventKit's compatibility travel-time value without allowing an Objective-C exception to escape.
FOUNDATION_EXPORT bool easybar_eventkit_write_travel_time(
  NSObject *object,
  double seconds
);

#ifdef __cplusplus
}
#endif

#endif
