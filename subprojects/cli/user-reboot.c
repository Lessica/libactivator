//
//  user-reboot.c
//  libactivator
//
//  Created by Lessica on 6/17/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#include <launch.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sysexits.h>
#include <unistd.h>

#include <sys/stat.h>

extern int reboot3(uint64_t flags, ...);

#define RB2_USERREBOOT (0x2000000000000000llu)

typedef void (*LAUNCHDataDictionaryApplier)(const char *name, launch_data_t value, void *context);

typedef struct {
    LAUNCHDataDictionaryApplier applier;
    void *context;
} LAUNCHDataDictionaryIteration;

typedef struct {
    bool hasDYLD;
} LAUNCHEnvironmentContext;

typedef struct {
    pid_t parentPID;
    struct stat correctExecutable;
    bool allowed;
} LAUNCHCallerValidationContext;

static void LAUNCHDataDictionaryIterator(launch_data_t value, const char *name, void *context) {
    LAUNCHDataDictionaryIteration *iteration = (LAUNCHDataDictionaryIteration *)context;
    iteration->applier(name, value, iteration->context);
}

static void LAUNCHDataDictionaryApply(launch_data_t data, LAUNCHDataDictionaryApplier applier, void *context) {
    LAUNCHDataDictionaryIteration iteration = {
        .applier = applier,
        .context = context,
    };
    launch_data_dict_iterate(data, LAUNCHDataDictionaryIterator, &iteration);
}

static void LAUNCHDetectDYLDEnvironmentVariable(const char *name, launch_data_t value, void *context) {
    (void)value;

    LAUNCHEnvironmentContext *environmentContext = (LAUNCHEnvironmentContext *)context;
    if (strncmp(name, "DYLD_", 5) == 0) {
        environmentContext->hasDYLD = true;
    }
}

static launch_data_t LAUNCHJobProgramData(launch_data_t job) {
    launch_data_t string = launch_data_dict_lookup(job, LAUNCH_JOBKEY_PROGRAM);
    if (string != NULL && launch_data_get_type(string) == LAUNCH_DATA_STRING) {
        return string;
    }

    launch_data_t array = launch_data_dict_lookup(job, LAUNCH_JOBKEY_PROGRAMARGUMENTS);
    if (array == NULL || launch_data_get_type(array) != LAUNCH_DATA_ARRAY) {
        return NULL;
    }

    if (launch_data_array_get_count(array) == 0) {
        return NULL;
    }

    string = launch_data_array_get_index(array, 0);
    if (string == NULL || launch_data_get_type(string) != LAUNCH_DATA_STRING) {
        return NULL;
    }

    return string;
}

static void LAUNCHValidateCallerLaunchJob(const char *name, launch_data_t value, void *context) {
    (void)name;

    if (launch_data_get_type(value) != LAUNCH_DATA_DICTIONARY) {
        return;
    }

    LAUNCHCallerValidationContext *validationContext = (LAUNCHCallerValidationContext *)context;

    launch_data_t integer = launch_data_dict_lookup(value, LAUNCH_JOBKEY_PID);
    if (integer == NULL || launch_data_get_type(integer) != LAUNCH_DATA_INTEGER) {
        return;
    }

    pid_t pid = (pid_t)launch_data_get_integer(integer);
    if (pid != validationContext->parentPID) {
        return;
    }

    launch_data_t variables = launch_data_dict_lookup(value, LAUNCH_JOBKEY_ENVIRONMENTVARIABLES);
    if (variables != NULL && launch_data_get_type(variables) == LAUNCH_DATA_DICTIONARY) {
        LAUNCHEnvironmentContext environmentContext = {
            .hasDYLD = false,
        };
        LAUNCHDataDictionaryApply(variables, LAUNCHDetectDYLDEnvironmentVariable, &environmentContext);
        if (environmentContext.hasDYLD) {
            return;
        }
    }

    launch_data_t string = LAUNCHJobProgramData(value);
    if (string == NULL) {
        return;
    }

    const char *program = launch_data_get_string(string);
    if (program == NULL) {
        return;
    }

    struct stat check;
    if (lstat(program, &check) == -1) {
        return;
    }

    if (validationContext->correctExecutable.st_dev == check.st_dev &&
        validationContext->correctExecutable.st_ino == check.st_ino) {
        validationContext->allowed = true;
    }
}

static bool LAUNCHParentIsSpringBoard(void) {
    struct stat correct;
    if (lstat("/System/Library/CoreServices/SpringBoard.app/SpringBoard", &correct) == -1) {
        return false;
    }

    launch_data_t request = launch_data_new_string(LAUNCH_KEY_GETJOBS);
    if (request == NULL) {
        return false;
    }

    launch_data_t response = launch_msg(request);
    launch_data_free(request);

    if (response == NULL || launch_data_get_type(response) != LAUNCH_DATA_DICTIONARY) {
        if (response != NULL) {
            launch_data_free(response);
        }
        return false;
    }

    LAUNCHCallerValidationContext validationContext = {
        .parentPID = getppid(),
        .correctExecutable = correct,
        .allowed = false,
    };
    LAUNCHDataDictionaryApply(response, LAUNCHValidateCallerLaunchJob, &validationContext);
    launch_data_free(response);

    return validationContext.allowed;
}

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;

    if (!LAUNCHParentIsSpringBoard()) {
        fprintf(stderr, "Unauthorized caller\n");
        return EX_NOPERM;
    }

    if (setgid(0) != 0) {
        perror("setgid");
        return EX_OSERR;
    }
    if (setuid(0) != 0) {
        perror("setuid");
        return EX_OSERR;
    }
    if (reboot3(RB2_USERREBOOT) != 0) {
        perror("reboot3");
        return EX_UNAVAILABLE;
    }
    return 0;
}
