// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

#ifndef CoreAudioMock_h
#define CoreAudioMock_h

#include <stdio.h>
#include <stdint.h>
#include <CoreFoundation/CFAvailability.h>
#include <CoreFoundation/CFBase.h>

typedef CF_OPTIONS(uint8_t, CoreAudioMockStatus) {
    IDLE                   = 0x0,
    ADD_LISTENER_CALLED    = 0x1,
    REMOVE_LISTENER_CALLED = 0x2,
    DEFAULT_OUTPUT_SET     = 0x4,
    SYSTEM_OUTPUT_SET      = 0x8,
};

extern CoreAudioMockStatus get_current_mock_status(void);
extern void reset_current_mock_status(void);
extern void add_fake_device(uint32_t device_id, uint32_t buffer_count, uint32_t output_channels_per_buffer, const char* uid, const char* name);
extern void remove_fake_device(uint32_t device_id);

#endif /* CoreAudioMock_h */
