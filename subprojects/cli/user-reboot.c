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

typedef void (*data_dictionary_applier)(const char *name, launch_data_t value, void *context);

typedef struct {
    data_dictionary_applier applier;
    void *context;
} data_dictionary_iteration;

typedef struct {
    bool has_dyld;
} environment_context;

typedef struct {
    pid_t parent_pid;
    struct stat correct_executable;
    bool allowed;
} caller_validation_context;

static void data_dictionary_iterator(launch_data_t value, const char *name, void *context) {
    data_dictionary_iteration *iteration = (data_dictionary_iteration *)context;
    iteration->applier(name, value, iteration->context);
}

static void data_dictionary_apply(launch_data_t data, data_dictionary_applier applier, void *context) {
    data_dictionary_iteration iteration = {
        .applier = applier,
        .context = context,
    };
    launch_data_dict_iterate(data, data_dictionary_iterator, &iteration);
}

static void detect_dyld_environment_variable(const char *name, launch_data_t value, void *context) {
    (void)value;

    environment_context *environment = (environment_context *)context;
    if (strncmp(name, "DYLD_", 5) == 0) {
        environment->has_dyld = true;
    }
}

static launch_data_t job_program_data(launch_data_t job) {
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

static void validate_caller_launch_job(const char *name, launch_data_t value, void *context) {
    (void)name;

    if (launch_data_get_type(value) != LAUNCH_DATA_DICTIONARY) {
        return;
    }

    caller_validation_context *validation = (caller_validation_context *)context;

    launch_data_t integer = launch_data_dict_lookup(value, LAUNCH_JOBKEY_PID);
    if (integer == NULL || launch_data_get_type(integer) != LAUNCH_DATA_INTEGER) {
        return;
    }

    pid_t pid = (pid_t)launch_data_get_integer(integer);
    if (pid != validation->parent_pid) {
        return;
    }

    launch_data_t variables = launch_data_dict_lookup(value, LAUNCH_JOBKEY_ENVIRONMENTVARIABLES);
    if (variables != NULL && launch_data_get_type(variables) == LAUNCH_DATA_DICTIONARY) {
        environment_context environment = {
            .has_dyld = false,
        };
        data_dictionary_apply(variables, detect_dyld_environment_variable, &environment);
        if (environment.has_dyld) {
            return;
        }
    }

    launch_data_t string = job_program_data(value);
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

    if (validation->correct_executable.st_dev == check.st_dev &&
        validation->correct_executable.st_ino == check.st_ino) {
        validation->allowed = true;
    }
}

static bool parent_is_springboard(void) {
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

    caller_validation_context validation = {
        .parent_pid = getppid(),
        .correct_executable = correct,
        .allowed = false,
    };
    data_dictionary_apply(response, validate_caller_launch_job, &validation);
    launch_data_free(response);

    return validation.allowed;
}

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;

    if (!parent_is_springboard()) {
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
