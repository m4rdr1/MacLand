#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRIsPlayingFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRRegisterFn)(dispatch_queue_t);

static CFStringRef KTitle;
static CFStringRef KArtist;
static CFStringRef KElapsed;
static CFStringRef KDuration;
static CFStringRef KRate;
static CFStringRef KTimestamp;
static CFStringRef KArtwork;

static MRGetInfoFn gGetInfo;
static MRIsPlayingFn gIsPlaying;

static CFDictionaryRef gCaptured;
static int gPlaying;
static char gLastKey[1024];
static int gSentArt;

static void sendFrame(CFDictionaryRef dict) {
    CFDataRef xml = CFPropertyListCreateData(kCFAllocatorDefault, dict,
                                             kCFPropertyListXMLFormat_v1_0, 0, NULL);
    if (!xml) return;
    CFIndex n = CFDataGetLength(xml);
    if (printf("%ld\n", (long)n) < 0) exit(0);
    if (fwrite(CFDataGetBytePtr(xml), 1, (size_t)n, stdout) != (size_t)n) exit(0);
    fflush(stdout);
    CFRelease(xml);
}

static void emit(CFDictionaryRef info, int playing) {
    if (!info) {
        CFMutableDictionaryRef empty = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        if (!empty) return;
        sendFrame(empty);
        CFRelease(empty);
        return;
    }

    CFMutableDictionaryRef out = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, info);
    if (!out) return;

    char key[1024] = {0};
    CFStringRef cfTitle = CFDictionaryGetValue(info, KTitle);
    CFStringRef cfArtist = CFDictionaryGetValue(info, KArtist);
    if (cfTitle) CFStringGetCString(cfTitle, key, (CFIndex)sizeof key - 2, kCFStringEncodingUTF8);
    size_t used = strlen(key);
    strlcpy(key + used, "\x01", sizeof key - used);
    used = strlen(key);
    if (cfArtist) {
        CFStringGetCString(cfArtist, key + used, (CFIndex)(sizeof key - used - 1), kCFStringEncodingUTF8);
    }
    int sameTrack = (gLastKey[0] != 0) && (strcmp(key, gLastKey) == 0);
    strlcpy(gLastKey, key, sizeof gLastKey);
    if (!sameTrack) gSentArt = 0;

    CFDataRef art = CFDictionaryGetValue(info, KArtwork);
    if (art && CFGetTypeID(art) == CFDataGetTypeID() && CFDataGetLength(art) > 0 && !gSentArt) {
        gSentArt = 1;
    } else {
        CFDictionaryRemoveValue(out, KArtwork);
    }

    double elapsed = 0, rate = 0;
    CFNumberRef e = CFDictionaryGetValue(info, KElapsed);
    if (e && CFGetTypeID(e) == CFNumberGetTypeID()) CFNumberGetValue(e, kCFNumberDoubleType, &elapsed);
    CFNumberRef r = CFDictionaryGetValue(info, KRate);
    if (r && CFGetTypeID(r) == CFNumberGetTypeID()) CFNumberGetValue(r, kCFNumberDoubleType, &rate);
    CFDateRef ts = CFDictionaryGetValue(info, KTimestamp);
    double now = CFAbsoluteTimeGetCurrent();
    if (ts && CFGetTypeID(ts) == CFDateGetTypeID() && rate > 0.5) {
        elapsed += now - CFDateGetAbsoluteTime(ts);
    }
    if (elapsed < 0) elapsed = 0;
    double pr = playing ? 1.0 : 0.0;
    CFNumberRef eNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &elapsed);
    CFNumberRef rNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &pr);
    CFDateRef nowDate = CFDateCreate(kCFAllocatorDefault, now);
    if (eNum) { CFDictionarySetValue(out, KElapsed, eNum); CFRelease(eNum); }
    if (rNum) { CFDictionarySetValue(out, KRate, rNum); CFRelease(rNum); }
    if (nowDate) { CFDictionarySetValue(out, KTimestamp, nowDate); CFRelease(nowDate); }

    sendFrame(out);
    CFRelease(out);
}

static void requestNow(void) {
    if (gCaptured) { CFRelease(gCaptured); gCaptured = NULL; }
    if (gGetInfo) {
        gGetInfo(dispatch_get_main_queue(), ^(CFDictionaryRef d) {
            if (d) gCaptured = CFRetain(d);
        });
    }
    if (gIsPlaying) {
        gIsPlaying(dispatch_get_main_queue(), ^(Boolean p) {
            gPlaying = p ? 1 : 0;
        });
    }
}

__attribute__((visibility("default"))) void macland_media(void *cv) {
    (void)cv;
    signal(SIGPIPE, SIG_IGN);

    KTitle = CFStringCreateWithCString(kCFAllocatorDefault, "kMRMediaRemoteNowPlayingInfoTitle", kCFStringEncodingUTF8);
    KArtist = CFStringCreateWithCString(kCFAllocatorDefault, "kMRMediaRemoteNowPlayingInfoArtist", kCFStringEncodingUTF8);
    KElapsed = CFStringCreateWithCString(kCFAllocatorDefault, "kMRMediaRemoteNowPlayingInfoElapsedTime", kCFStringEncodingUTF8);
    KDuration = CFStringCreateWithCString(kCFAllocatorDefault, "kMRMediaRemoteNowPlayingInfoDuration", kCFStringEncodingUTF8);
    KRate = CFStringCreateWithCString(kCFAllocatorDefault, "kMRMediaRemoteNowPlayingInfoPlaybackRate", kCFStringEncodingUTF8);
    KTimestamp = CFStringCreateWithCString(kCFAllocatorDefault, "kMRMediaRemoteNowPlayingInfoTimestamp", kCFStringEncodingUTF8);
    KArtwork = CFStringCreateWithCString(kCFAllocatorDefault, "kMRMediaRemoteNowPlayingInfoArtworkData", kCFStringEncodingUTF8);

    void *h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (!h) {
        fprintf(stderr, "macland-media: MediaRemote unavailable\n");
        exit(2);
    }
    gGetInfo = (MRGetInfoFn)dlsym(h, "MRMediaRemoteGetNowPlayingInfo");
    gIsPlaying = (MRIsPlayingFn)dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    if (!gGetInfo) {
        fprintf(stderr, "macland-media: now-playing symbols missing\n");
        exit(3);
    }
    MRRegisterFn reg = (MRRegisterFn)dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications");
    if (reg) reg(dispatch_get_main_queue());

    for (;;) {
        if (getppid() == 1) break;
        requestNow();
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.4, false);
        emit(gCaptured, gPlaying);
    }
}
