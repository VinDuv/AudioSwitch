// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

#include "CoreAudioMock.h"
#include <CoreAudio/AudioHardware.h>


static dispatch_queue_t notify_dispatch_queue = nil;
static AudioObjectPropertyListenerBlock notify_listener = nil;
static const AudioObjectPropertyAddress* notify_address = nil;
static AudioDeviceID default_output_device = -1;
static AudioDeviceID default_system_output_device = -1;
static CoreAudioMockStatus current_mock_status = IDLE;

struct fake_device {
    AudioDeviceID device_id;
    uint32_t buffer_count;
    uint32_t channels_per_buffer;
    char uid[32];
    char name[32];
};

static struct fake_device* fake_devices = nil;
static uint32_t fake_device_count = 0;

static struct fake_device* find_fake_device(AudioDeviceID device_id);
static void notify_device_list_change(void);

// MARK: CoreAudio replacement functions

OSStatus AudioObjectAddPropertyListenerBlock(AudioObjectID inObjectID, const AudioObjectPropertyAddress* inAddress, dispatch_queue_t __nullable inDispatchQueue, AudioObjectPropertyListenerBlock inListener)
{
    if (notify_listener != nil) {
        fprintf(stderr, "AudioObjectAddPropertyBlock mock only supports one listener.\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inObjectID != kAudioObjectSystemObject) {
        fprintf(stderr, "AudioObjectAddPropertyBlock mock only supports kAudioObjectSystemObject\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inAddress->mSelector != kAudioHardwarePropertyDevices || inAddress->mScope != kAudioObjectPropertyScopeGlobal || inAddress->mElement != kAudioObjectPropertyElementMaster) {
        fprintf(stderr, "AudioObjectAddPropertyBlock mock only supports selector kAudioHardwarePropertyDevices, scope kAudioObjectPropertyScopeGlobal, element kAudioObjectPropertyElementMaster\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inDispatchQueue == nil) {
        fprintf(stderr, "AudioObjectAddPropertyBlock mock requires a dispatch queue.\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    notify_dispatch_queue = inDispatchQueue;
    notify_listener = Block_copy(inListener);
    notify_address = inAddress;
    
    current_mock_status |= ADD_LISTENER_CALLED;
    
    return kAudioHardwareNoError;
}


OSStatus AudioObjectRemovePropertyListenerBlock(AudioObjectID inObjectID, const AudioObjectPropertyAddress* inAddress, dispatch_queue_t __nullable inDispatchQueue, AudioObjectPropertyListenerBlock inListener)
{
    if (notify_listener == nil) {
        fprintf(stderr, "AudioObjectAddPropertyBlock mock has not listeners currently.\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inObjectID != kAudioObjectSystemObject) {
        fprintf(stderr, "AudioObjectAddPropertyBlock mock only supports kAudioObjectSystemObject\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inAddress->mSelector != kAudioHardwarePropertyDevices || inAddress->mScope != kAudioObjectPropertyScopeGlobal || inAddress->mElement != kAudioObjectPropertyElementMaster) {
        fprintf(stderr, "AudioObjectAddPropertyBlock mock only supports selector kAudioHardwarePropertyDevices, scope kAudioObjectPropertyScopeGlobal, element kAudioObjectPropertyElementMaster\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inDispatchQueue != notify_dispatch_queue) {
        fprintf(stderr, "inDispatchQueue does not match the expected one.\n");
        return kAudioHardwareIllegalOperationError;
    }

    // Comparing two blocks pointers does not work, so no test for this

    if (inAddress != notify_address) {
        fprintf(stderr, "inAddress does not match the expected one.\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    notify_dispatch_queue = nil;
    Block_release(notify_listener);
    notify_listener = nil;
    notify_address = nil;
    
    current_mock_status |= REMOVE_LISTENER_CALLED;
    
    return kAudioHardwareNoError;
}

OSStatus AudioObjectSetPropertyData(AudioObjectID inObjectID, const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize, const void* __nullable inQualifierData, UInt32 inDataSize, const void* inData)
{
    if (inObjectID != kAudioObjectSystemObject) {
        fprintf(stderr, "AudioObjectSetPropertyData mock only supports kAudioObjectSystemObject\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if ((inAddress->mSelector != kAudioHardwarePropertyDefaultOutputDevice && inAddress->mSelector != kAudioHardwarePropertyDefaultSystemOutputDevice) || inAddress->mScope != kAudioObjectPropertyScopeGlobal || inAddress->mElement != kAudioObjectPropertyElementMaster) {
        fprintf(stderr, "AudioObjectSetPropertyData mock only supports selector kAudioHardwarePropertyDefault[System]OutputDevice, scope kAudioObjectPropertyScopeGlobal, element kAudioObjectPropertyElementMaster\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inQualifierDataSize != 0 || inQualifierData != nil) {
        fprintf(stderr, "AudioObjectSetPropertyData mock does not support in qualifier\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inDataSize != sizeof(AudioDeviceID) || inData == nil) {
        fprintf(stderr, "AudioObjectSetPropertyData mock expects an AudioDeviceID in inData\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inAddress->mSelector == kAudioHardwarePropertyDefaultOutputDevice) {
        memcpy(&default_output_device, inData, sizeof(default_output_device));
        current_mock_status |= DEFAULT_OUTPUT_SET;
    } else {
        memcpy(&default_system_output_device, inData, sizeof(default_system_output_device));
        current_mock_status |= SYSTEM_OUTPUT_SET;
    }
    
    return kAudioHardwareNoError;
}

OSStatus AudioObjectGetPropertyDataSize(AudioObjectID inObjectID, const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize, const void* __nullable inQualifierData, UInt32* outDataSize)
{
    if (inQualifierDataSize != 0 || inQualifierData != nil) {
        fprintf(stderr, "AudioObjectGetPropertyDataSize mock does not support in qualifier\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inObjectID == kAudioObjectSystemObject) {
        if (inAddress->mSelector != kAudioHardwarePropertyDevices || inAddress->mScope != kAudioObjectPropertyScopeGlobal || inAddress->mElement != kAudioObjectPropertyElementMaster) {
            fprintf(stderr, "AudioObjectGetPropertyDataSize mock only supports selector kAudioHardwarePropertyDevices, scope kAudioObjectPropertyScopeGlobal, element kAudioObjectPropertyElementMaster\n");
            return kAudioHardwareIllegalOperationError;
        }
        
        *outDataSize = fake_device_count * sizeof(AudioDeviceID);
        return kAudioHardwareNoError;
    }
    
    struct fake_device* device = find_fake_device(inObjectID);
    if (device == nil) {
        fprintf(stderr, "AudioObjectGetPropertyDataSize mock does not known object id %u\n", inObjectID);
        return kAudioHardwareBadDeviceError;
    }
    
    if (inAddress->mSelector != kAudioDevicePropertyStreamConfiguration || inAddress->mScope != kAudioObjectPropertyScopeOutput || inAddress->mElement != kAudioObjectPropertyElementMaster) {
        fprintf(stderr, "AudioObjectGetPropertyDataSize mock only supports selector kAudioDevicePropertyStreamConfiguration, scope kAudioObjectPropertyScopeOutput, element kAudioObjectPropertyElementMaster\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    *outDataSize = sizeof(AudioBufferList) + sizeof(AudioBuffer) * ((int32_t)device->buffer_count - 1);
    return kAudioHardwareNoError;
}

OSStatus AudioObjectGetPropertyData(AudioObjectID inObjectID, const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize, const void* __nullable inQualifierData, UInt32* ioDataSize, void* outData)
{
    if (inQualifierDataSize != 0 || inQualifierData != nil) {
        fprintf(stderr, "AudioObjectGetPropertyDataSize mock does not support in qualifier\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    if (inObjectID == kAudioObjectSystemObject) {
        if (inAddress->mScope != kAudioObjectPropertyScopeGlobal || inAddress->mElement != kAudioObjectPropertyElementMaster) {
            fprintf(stderr, "AudioObjectGetPropertyData mock only supports scope kAudioObjectPropertyScopeGlobal, element kAudioObjectPropertyElementMaster\n");
            return kAudioHardwareIllegalOperationError;
        }
        
        if (inAddress->mSelector == kAudioHardwarePropertyDefaultOutputDevice) {
            uint32_t out_size = sizeof(AudioDeviceID);
            
            if ((*ioDataSize) < out_size) {
                fprintf(stderr, "AudioObjectGetPropertyData mock got a too short output buffer\n");
                return kAudioHardwareIllegalOperationError;
            }
            
            AudioDeviceID* out_buffer = outData;
            *out_buffer = default_output_device;
            *ioDataSize = out_size;
            
            return kAudioHardwareNoError;

        } else if (inAddress->mSelector == kAudioHardwarePropertyDevices) {
            uint32_t out_size = fake_device_count * sizeof(AudioDeviceID);
            
            if ((*ioDataSize) < out_size) {
                fprintf(stderr, "AudioObjectGetPropertyData mock got a too short output buffer\n");
                return kAudioHardwareIllegalOperationError;
            }
            
            AudioDeviceID* out_buffer = outData;
            
            for (uint32_t i = 0 ; i < fake_device_count ; i += 1) {
                out_buffer[i] = fake_devices[i].device_id;
            }
            
            *ioDataSize = out_size;

            return kAudioHardwareNoError;

        } else {
            fprintf(stderr, "AudioObjectGetPropertyData mock only supports selectors kAudioHardwarePropertyDefaultOutputDevice and kAudioHardwarePropertyDevices\n");
            return kAudioHardwareIllegalOperationError;
        }
    }
    
    struct fake_device* device = find_fake_device(inObjectID);
    if (device == nil) {
        fprintf(stderr, "AudioObjectGetPropertyData mock does not known object id %u\n", inObjectID);
        return kAudioHardwareBadDeviceError;
    }
    
    if (inAddress->mScope != kAudioObjectPropertyScopeOutput || inAddress->mElement != kAudioObjectPropertyElementMaster) {
        fprintf(stderr, "AudioObjectGetPropertyData mock only supports scope kAudioObjectPropertyScopeOutput, element kAudioObjectPropertyElementMaster\n");
        return kAudioHardwareIllegalOperationError;
    }
    
    switch (inAddress->mSelector) {
        case kAudioDevicePropertyStreamConfiguration:
        {
            uint32_t out_size = sizeof(AudioBufferList) + sizeof(AudioBuffer) * ((int32_t)device->buffer_count - 1);
            
            if ((*ioDataSize) < out_size) {
                fprintf(stderr, "AudioObjectGetPropertyData mock got a too short output buffer\n");
                return kAudioHardwareIllegalOperationError;
            }
            
            AudioBufferList* out_buffer = outData;
            
            out_buffer->mNumberBuffers = device->buffer_count;
            
            for (uint32_t i = 0 ; i < device->buffer_count ; i += 1) {
                out_buffer->mBuffers[i].mData = nil;
                out_buffer->mBuffers[i].mDataByteSize = 1;
                out_buffer->mBuffers[i].mNumberChannels = device->channels_per_buffer;
            }
            
            *ioDataSize = out_size;
        }
        break;
            
        case kAudioDevicePropertyDeviceUID:
        {
            CFStringRef uid;
            uint32_t out_size = sizeof(uid);
            if ((*ioDataSize) < out_size) {
                fprintf(stderr, "AudioObjectGetPropertyData mock got a too short output buffer\n");
                return kAudioHardwareIllegalOperationError;
            }
            
            uid = CFStringCreateWithCString(nil, device->uid, kCFStringEncodingUTF8);
            
            memcpy(outData, &uid, sizeof(uid));
            *ioDataSize = out_size;
        }
        break;
            
        case kAudioDevicePropertyDeviceNameCFString:
        {
            CFStringRef name;
            uint32_t out_size = sizeof(name);
            if ((*ioDataSize) < out_size) {
                fprintf(stderr, "AudioObjectGetPropertyData mock got a too short output buffer\n");
                return kAudioHardwareIllegalOperationError;
            }
            
            name = CFStringCreateWithCString(nil, device->name, kCFStringEncodingUTF8);
            
            memcpy(outData, &name, sizeof(name));
            *ioDataSize = out_size;
        }
        break;
            
        default:
            fprintf(stderr, "AudioObjectGetPropertyData mock does not supports selector %x\n", inAddress->mSelector);
            return kAudioHardwareIllegalOperationError;
        break;
    }
    
    return kAudioHardwareNoError;
}

// MARK: Mock control functions
CoreAudioMockStatus get_current_mock_status(void)
{
    return current_mock_status;
}

void reset_current_mock_status(void) {
    notify_dispatch_queue = nil;
    Block_release(notify_listener);
    notify_listener = nil;
    notify_address = nil;
    default_output_device = -1;
    default_system_output_device = -1;
    
    free(fake_devices);
    fake_devices = nil;
    fake_device_count = 0;
    
    current_mock_status = IDLE;
}

void add_fake_device(uint32_t device_id, uint32_t buffer_count, uint32_t output_channels_per_buffer, const char* uid, const char* name)
{
    struct fake_device* device = nil;
    
    fake_devices = realloc(fake_devices, sizeof(*fake_devices) * (fake_device_count + 1));
    if (fake_devices == nil) {
        fprintf(stderr, "Unable to add a fake device: no memory ?\n");
        abort();
    }
    
    device = &fake_devices[fake_device_count];
    device->device_id = device_id;
    device->buffer_count = buffer_count;
    device->channels_per_buffer = output_channels_per_buffer;
    strlcpy(device->uid, uid, sizeof(device->uid));
    strlcpy(device->name, name, sizeof(device->name));

    fake_device_count += 1;
    
    notify_device_list_change();
}

void remove_fake_device(uint32_t device_id)
{
    struct fake_device* device = find_fake_device(device_id);
    if (device == nil) {
        return;
    }
    
    uint32_t device_index = (uint32_t)(device - fake_devices);
    uint32_t devices_after = fake_device_count - device_index - 1;
    
    memmove(device, device + 1, devices_after * sizeof(*device));
    
    fake_device_count -= 1;
    
    fake_devices = realloc(fake_devices, sizeof(*fake_devices) * fake_device_count);
    if ((fake_devices == nil) && (fake_device_count > 0)) {
        fprintf(stderr, "Unable to remove a fake device: no memory ?\n");
        abort();
    }
    
    notify_device_list_change();
}

static struct fake_device* find_fake_device(AudioDeviceID device_id)
{
    struct fake_device* found_device = nil;
    
    for (uint32_t i = 0 ; (i < fake_device_count) && (found_device == nil) ; i += 1) {
        if (fake_devices[i].device_id == device_id) {
            found_device = &fake_devices[i];
        }
    }
    
    return found_device;
}

static void notify_device_list_change(void)
{
    if (notify_dispatch_queue != nil) {
        dispatch_async(notify_dispatch_queue, ^{
            if (notify_listener != nil) {
                notify_listener(1, notify_address);
            }
        });
    }
}

