// This application prints basic runtime information and uses a sample
// dynamically-loaded library. Basically, this is a placeholder for an actual
// application.

#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Define aliases for functions that we will find in the library dynamically, at
// runtime.
typedef int (*io_queue_init_t)(int, void **);
typedef int (*io_queue_release_t)(void **);

// Define constants used below
const char *CONFIG_FILE = "fake-config-file.conf";
const char *LIBAIO_SO_NAME = "libaio.so";

void printBasicApplicationInformation() {
  const size_t pathSize = PATH_MAX;

  char *pathBuf = calloc(pathSize + 1, sizeof(char));
  if (pathBuf == NULL) {
    perror("calloc()");
    exit(EXIT_FAILURE); // Let the OS handle the cleanup
  }

  const char *cwd = getcwd(pathBuf, pathSize);
  if (cwd != NULL) {
    printf("Working directory:  %s\n", cwd);
  } else {
    perror("getcwd()");
    exit(EXIT_FAILURE);
  }

  // Clean up the buffer for reuse in readlink()
  memset(pathBuf, 0, pathSize);

  const int nbytes = readlink("/proc/self/exe", pathBuf, pathSize);
  if (nbytes == -1) {
    perror("readlink('/proc/self/exe', ..)");
    exit(1);
  }

  printf("App binary is at:   %s\n\n", pathBuf);

  free(pathBuf);
}

void readFakeConfiguration() {
  printf("Trying to read fake configuration file from '%s'...\n", CONFIG_FILE);

  FILE *fp = fopen(CONFIG_FILE, "r");
  if (!fp) {
    perror("fopen()");
    exit(EXIT_FAILURE);
  }

  printf("File opened - its contents are:\n ----\n");

  char buf[1024];
  while (fgets(buf, sizeof(buf), fp) != NULL) {
    printf("%s\n", buf);
  }

  printf(" ----\n\n");

  if (fclose(fp)) {
    perror("fclose()");
    exit(EXIT_FAILURE);
  }
}

void useDynamicallyLinkedLibrary() {
  const int maxEvents = 128;
  void *aioCtx = NULL;
  char *error;

  // Open the shared library
  void *dynamicLibraryHandle = dlopen(LIBAIO_SO_NAME, RTLD_LAZY);
  if (!dynamicLibraryHandle) {
    fprintf(stderr, "Error opening libaio: %s\n", dlerror());
    exit(EXIT_FAILURE);
  }

  // Clear any existing error
  dlerror();

  // Find the function symbols
  const io_queue_init_t aio_queue_init =
      (io_queue_init_t)dlsym(dynamicLibraryHandle, "io_queue_init");
  error = dlerror();
  if (error != NULL) {
    fprintf(stderr, "Error locating symbol 'io_queue_init': %s\n", error);
    dlclose(dynamicLibraryHandle);
    exit(EXIT_FAILURE);
  }

  const io_queue_release_t aio_queue_release =
      (io_queue_release_t)dlsym(dynamicLibraryHandle, "io_queue_release");
  error = dlerror();
  if (error != NULL) {
    fprintf(stderr, "Error locating symbol 'io_queue_release': %s\n", error);
    dlclose(dynamicLibraryHandle);
    exit(EXIT_FAILURE);
  }

  printf("Successfully loaded libaio and found functions io_queue_init() and "
         "io_queue_release()!\n");

  // Call the functions, just to make sure the library is ready for use
  int result = aio_queue_init(maxEvents, &aioCtx);
  if (result == 0) {
    printf("Success: io_queue_init() returned 0. Context initialized.\n");
  } else {
    fprintf(stderr, "io_queue_init() failed with error code: %d\n", result);
    dlclose(dynamicLibraryHandle);
    exit(EXIT_FAILURE);
  }

  result = aio_queue_release(aioCtx);
  if (result == 0) {
    printf("Success: io_queue_release() returned 0. Context shut down.\n\n");
  } else {
    fprintf(stderr, "io_queue_release() failed with error code: %d\n", result);
    dlclose(dynamicLibraryHandle);
    exit(EXIT_FAILURE);
  }

  // Clean up
  dlclose(dynamicLibraryHandle);
}

int main() {
  printf("Hello world!\n");
  printBasicApplicationInformation();
  readFakeConfiguration();
  useDynamicallyLinkedLibrary();
  printf("Done! Closing down..\n");

  return 0;
}
