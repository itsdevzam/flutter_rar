#include "flutter_rar.h"

#ifndef RARDLL
#define RARDLL 1
#endif
#ifndef SILENT
#define SILENT 1
#endif

#include "rar.hpp"

#include <cctype>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <functional>
#include <mutex>
#include <string>
#include <vector>

#if defined(_WIN32)
#include <direct.h>
#include <windows.h>
#else
#include <pthread.h>
#include <sys/stat.h>
#endif

namespace {

std::mutex g_mutex;

enum Mode { kList = 0, kExtract = 1, kExtractOne = 2, kTest = 3 };

struct CallbackState {
  std::string password;
};

std::string wideToUtf8(const wchar_t* value) {
  if (value == nullptr || value[0] == 0) return std::string();
#if defined(_WIN32)
  const int size = WideCharToMultiByte(CP_UTF8, 0, value, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) return std::string();
  std::string out(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value, -1, &out[0], size, nullptr, nullptr);
  return out;
#else
  std::string out;
  for (size_t i = 0; value[i] != 0 && i < 1024; ++i) {
    const uint32_t cp = static_cast<uint32_t>(value[i]);
    if (cp < 0x80) {
      out.push_back(static_cast<char>(cp));
    } else if (cp < 0x800) {
      out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp < 0x10000) {
      out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else {
      out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
  }
  return out;
#endif
}

#if defined(_WIN32)
std::wstring utf8ToWide(const std::string& value) {
  if (value.empty()) return std::wstring();
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (size <= 1) return std::wstring();
  std::wstring out(static_cast<size_t>(size - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, &out[0], size);
  return out;
}
#endif

void appendJsonString(std::string& out, const std::string& value) {
  out.push_back('"');
  for (size_t i = 0; i < value.size(); ++i) {
    const unsigned char c = static_cast<unsigned char>(value[i]);
    switch (c) {
      case '"':
        out += "\\\"";
        break;
      case '\\':
        out += "\\\\";
        break;
      case '\b':
        out += "\\b";
        break;
      case '\f':
        out += "\\f";
        break;
      case '\n':
        out += "\\n";
        break;
      case '\r':
        out += "\\r";
        break;
      case '\t':
        out += "\\t";
        break;
      default:
        if (c < 0x20) {
          char buf[8];
          std::snprintf(buf, sizeof(buf), "\\u%04x", c);
          out += buf;
        } else {
          out.push_back(static_cast<char>(c));
        }
        break;
    }
  }
  out.push_back('"');
}

const char* errorText(int code) {
  switch (code) {
    case ERAR_SUCCESS:
      return "Success";
    case ERAR_END_ARCHIVE:
      return "End of archive";
    case ERAR_NO_MEMORY:
      return "Not enough memory";
    case ERAR_BAD_DATA:
      return "Archive data is corrupt";
    case ERAR_BAD_ARCHIVE:
      return "Not a valid RAR archive";
    case ERAR_UNKNOWN_FORMAT:
      return "Unknown archive format";
    case ERAR_EOPEN:
      return "Could not open the archive";
    case ERAR_ECREATE:
      return "Could not create the output file";
    case ERAR_ECLOSE:
      return "Could not close the file";
    case ERAR_EREAD:
      return "Read error";
    case ERAR_EWRITE:
      return "Write error";
    case ERAR_MISSING_PASSWORD:
      return "Password required";
    case ERAR_EREFERENCE:
      return "Missing reference volume";
    case ERAR_BAD_PASSWORD:
      return "Wrong password";
    default:
      return "RAR error";
  }
}

std::string detectVersion(const char* path) {
#if defined(_WIN32)
  const std::wstring wide = utf8ToWide(path);
  FILE* file = _wfopen(wide.c_str(), L"rb");
#else
  FILE* file = std::fopen(path, "rb");
#endif
  if (file == nullptr) return std::string();
  unsigned char bytes[8] = {0, 0, 0, 0, 0, 0, 0, 0};
  const size_t count = std::fread(bytes, 1, 8, file);
  std::fclose(file);
  if (count >= 7 && bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72 &&
      bytes[3] == 0x21 && bytes[4] == 0x1A && bytes[5] == 0x07) {
    if (bytes[6] == 0x00) return "RAR4";
    if (count >= 8 && bytes[6] == 0x01 && bytes[7] == 0x00) return "RAR5";
  }
  if (count >= 4 && bytes[0] == 0x52 && bytes[1] == 0x45 && bytes[2] == 0x7E &&
      bytes[3] == 0x5E) {
    return "RAR15";
  }
  return std::string();
}

std::string normalizeName(const RARHeaderDataEx& header) {
  std::string name = wideToUtf8(header.FileNameW);
  if (name.empty()) name = header.FileName;
  for (size_t i = 0; i < name.size(); ++i) {
    if (name[i] == '\\') name[i] = '/';
  }
  return name;
}

std::string trimSlashes(std::string name) {
  while (!name.empty() && name[name.size() - 1] == '/') name.erase(name.size() - 1);
  while (name.size() >= 2 && name[0] == '.' && name[1] == '/') name.erase(0, 2);
  return name;
}

bool sameEntry(const std::string& stored, const std::string& requested) {
  return trimSlashes(stored) == trimSlashes(requested);
}

bool isSafeRelative(const std::string& name) {
  if (name.empty()) return false;
  if (name[0] == '/' || name[0] == '\\') return false;
  if (name.size() >= 2 && std::isalpha(static_cast<unsigned char>(name[0])) && name[1] == ':') {
    return false;
  }
  std::string part;
  for (size_t i = 0; i <= name.size(); ++i) {
    if (i == name.size() || name[i] == '/' || name[i] == '\\') {
      if (part == "..") return false;
      part.clear();
    } else {
      part.push_back(name[i]);
    }
  }
  return true;
}

std::string joinPath(const std::string& dest, const std::string& name) {
  std::string root = dest;
  while (!root.empty() && (root[root.size() - 1] == '/' || root[root.size() - 1] == '\\')) {
    root.erase(root.size() - 1);
  }
  const std::string relative = trimSlashes(name);
  if (relative.empty()) return root;
  char sep = '/';
  if (root.find('\\') != std::string::npos && root.find('/') == std::string::npos) sep = '\\';
  return root + sep + relative;
}

int64_t dosTimeMs(unsigned int dos) {
  if (dos == 0) return -1;
  std::tm time = {};
  time.tm_sec = static_cast<int>(dos & 0x1F) * 2;
  time.tm_min = static_cast<int>((dos >> 5) & 0x3F);
  time.tm_hour = static_cast<int>((dos >> 11) & 0x1F);
  time.tm_mday = static_cast<int>((dos >> 16) & 0x1F);
  time.tm_mon = static_cast<int>((dos >> 21) & 0x0F) - 1;
  time.tm_year = static_cast<int>((dos >> 25) & 0x7F) + 1980 - 1900;
  time.tm_isdst = 0;
#if defined(_WIN32)
  const time_t unixTime = _mkgmtime(&time);
#else
  const time_t unixTime = timegm(&time);
#endif
  if (unixTime < 0) return -1;
  return static_cast<int64_t>(unixTime) * 1000;
}

int64_t modifiedMs(const RARHeaderDataEx& header) {
  const uint64_t fileTime =
      (static_cast<uint64_t>(header.MtimeHigh) << 32) | header.MtimeLow;
  const uint64_t epoch = 116444736000000000ULL;
  if (fileTime > epoch) return static_cast<int64_t>((fileTime - epoch) / 10000ULL);
  return dosTimeMs(header.FileTime);
}

bool ensureDirectory(const std::string& path) {
  if (path.empty()) return false;
  std::string current;
  for (size_t i = 0; i <= path.size(); ++i) {
    const bool boundary = i == path.size() || path[i] == '/' || path[i] == '\\';
    if (!boundary) {
      current.push_back(path[i]);
      continue;
    }
    if (i < path.size()) current.push_back(path[i]);
    if (current.empty() || current == "/" || current == "\\" ||
        (current.size() == 3 && current[1] == ':')) {
      continue;
    }
    std::string toMake = current;
    if (!toMake.empty() && (toMake[toMake.size() - 1] == '/' || toMake[toMake.size() - 1] == '\\')) {
      toMake.erase(toMake.size() - 1);
    }
    if (toMake.empty()) continue;
#if defined(_WIN32)
    const std::wstring wide = utf8ToWide(toMake);
    if (!wide.empty()) CreateDirectoryW(wide.c_str(), nullptr);
#else
    if (mkdir(toMake.c_str(), 0755) != 0 && errno != EEXIST) {
      // Parent may already exist. Keep walking.
    }
#endif
  }
  return true;
}

int CALLBACK rarCallback(UINT message, LPARAM userData, LPARAM p1, LPARAM p2) {
  CallbackState* state = reinterpret_cast<CallbackState*>(userData);
  if (state == nullptr || state->password.empty()) return 0;
  if (message == UCM_NEEDPASSWORDW && p1 != 0 && p2 > 1) {
#if defined(_WIN32)
    const std::wstring wide = utf8ToWide(state->password);
    wchar_t* buffer = reinterpret_cast<wchar_t*>(p1);
    const size_t cap = static_cast<size_t>(p2);
    const size_t count = wide.size() < cap - 1 ? wide.size() : cap - 1;
    if (count > 0) std::memcpy(buffer, wide.c_str(), count * sizeof(wchar_t));
    buffer[count] = 0;
#else
    wchar_t* buffer = reinterpret_cast<wchar_t*>(p1);
    const size_t cap = static_cast<size_t>(p2);
    size_t written = 0;
    const unsigned char* bytes =
        reinterpret_cast<const unsigned char*>(state->password.c_str());
    for (size_t i = 0; bytes[i] != 0 && written + 1 < cap; ++i) {
      buffer[written++] = static_cast<wchar_t>(bytes[i]);
    }
    buffer[written] = 0;
#endif
    return 0;
  }
  if (message == UCM_NEEDPASSWORD && p1 != 0 && p2 > 1) {
    char* buffer = reinterpret_cast<char*>(p1);
    const size_t cap = static_cast<size_t>(p2);
    std::snprintf(buffer, cap, "%s", state->password.c_str());
    return 0;
  }
  if (message == UCM_CHANGEVOLUME || message == UCM_CHANGEVOLUMEW) return -1;
  return 0;
}

int processFile(HANDLE archive, int operation, const std::string& dest) {
#if defined(_WIN32)
  if (dest.empty()) return RARProcessFileW(archive, operation, nullptr, nullptr);
  const std::wstring wide = utf8ToWide(dest);
  return RARProcessFileW(archive, operation, const_cast<wchar_t*>(wide.c_str()), nullptr);
#else
  if (dest.empty()) return RARProcessFile(archive, operation, nullptr, nullptr);
  return RARProcessFile(archive, operation, const_cast<char*>(dest.c_str()), nullptr);
#endif
}

struct Entry {
  std::string name;
  std::string extractedPath;
  bool isDirectory;
  bool isEncrypted;
  bool skipped;
  uint64_t uncompressedSize;
  uint64_t compressedSize;
  uint32_t crc32;
  int64_t modifiedAt;
};

std::string failJson(const std::string& message, const std::string& version) {
  std::string out = "{\"success\":false,\"message\":";
  appendJsonString(out, message);
  out += ",\"rarVersion\":";
  appendJsonString(out, version);
  out += ",\"isEncrypted\":false,\"destinationPath\":\"\",\"entries\":[]}";
  return out;
}

std::string successJson(
    const std::string& message,
    const std::string& version,
    bool encrypted,
    const std::string& destination,
    const std::vector<Entry>& entries) {
  std::string out = "{\"success\":true,\"message\":";
  appendJsonString(out, message);
  out += ",\"rarVersion\":";
  appendJsonString(out, version);
  out += encrypted ? ",\"isEncrypted\":true" : ",\"isEncrypted\":false";
  out += ",\"destinationPath\":";
  appendJsonString(out, destination);
  out += ",\"entries\":[";
  for (size_t i = 0; i < entries.size(); ++i) {
    const Entry& entry = entries[i];
    if (i != 0) out += ',';
    out += "{\"name\":";
    appendJsonString(out, entry.name);
    out += ",\"extractedPath\":";
    appendJsonString(out, entry.extractedPath);
    out += entry.isDirectory ? ",\"isDirectory\":true" : ",\"isDirectory\":false";
    out += ",\"uncompressedSize\":";
    char number[32];
    std::snprintf(number, sizeof(number), "%llu", static_cast<unsigned long long>(entry.uncompressedSize));
    out += number;
    out += ",\"compressedSize\":";
    std::snprintf(number, sizeof(number), "%llu", static_cast<unsigned long long>(entry.compressedSize));
    out += number;
    out += entry.isEncrypted ? ",\"isEncrypted\":true" : ",\"isEncrypted\":false";
    out += ",\"compression\":";
    appendJsonString(out, version == "RAR5" ? "rar5" : "rar4");
    out += ",\"modifiedAt\":";
    if (entry.modifiedAt < 0) {
      out += "null";
    } else {
      std::snprintf(number, sizeof(number), "%lld", static_cast<long long>(entry.modifiedAt));
      out += number;
    }
    out += ",\"crc32\":";
    std::snprintf(number, sizeof(number), "%u", entry.crc32);
    out += number;
    out += entry.skipped ? ",\"skipped\":true}" : ",\"skipped\":false}";
  }
  out += "]}";
  return out;
}

std::string runArchive(
    const std::string& path,
    const std::string& dest,
    const std::string& password,
    const std::string& onlyEntry,
    int mode) {
  const std::string version = detectVersion(path.c_str());
  if (version.empty()) return failJson("Not a RAR archive", "");
  if (version == "RAR15") return failJson("RAR 1.5 archives are not supported", version);
  if ((mode == kExtract || mode == kExtractOne) && dest.empty()) {
    return failJson("Destination directory is required", version);
  }
  if (mode == kExtractOne && onlyEntry.empty()) return failJson("Entry not found", version);
  if (mode == kExtract || mode == kExtractOne) ensureDirectory(dest);

  CallbackState callback;
  callback.password = password;

  RAROpenArchiveDataEx openData;
  std::memset(&openData, 0, sizeof(openData));
#if defined(_WIN32)
  const std::wstring widePath = utf8ToWide(path);
  openData.ArcNameW = const_cast<wchar_t*>(widePath.c_str());
#else
  openData.ArcName = const_cast<char*>(path.c_str());
#endif
  openData.OpenMode = mode == kList ? RAR_OM_LIST : RAR_OM_EXTRACT;
  openData.Callback = rarCallback;
  openData.UserData = reinterpret_cast<LPARAM>(&callback);

  HANDLE archive = RAROpenArchiveEx(&openData);
  if (archive == nullptr || openData.OpenResult != ERAR_SUCCESS) {
    const int code = openData.OpenResult == 0 ? ERAR_EOPEN : static_cast<int>(openData.OpenResult);
    if (archive != nullptr) RARCloseArchive(archive);
    return failJson(errorText(code), version);
  }
  if (!password.empty()) RARSetPassword(archive, const_cast<char*>(password.c_str()));

  std::vector<Entry> entries;
  std::string error;
  bool matched = mode != kExtractOne;
  int writtenFiles = 0;
  int skipped = 0;
  bool encrypted = (openData.Flags & ROADF_ENCHEADERS) != 0;

  while (error.empty()) {
    RARHeaderDataEx header;
    std::memset(&header, 0, sizeof(header));
    const int readCode = RARReadHeaderEx(archive, &header);
    if (readCode == ERAR_END_ARCHIVE) break;
    if (readCode != ERAR_SUCCESS) {
      error = errorText(readCode);
      break;
    }

    const std::string name = normalizeName(header);
    const bool directory = (header.Flags & RHDF_DIRECTORY) != 0;
    const bool fileEncrypted = (header.Flags & RHDF_ENCRYPTED) != 0;
    if (fileEncrypted) encrypted = true;
    const bool wanted = mode != kExtractOne || sameEntry(name, onlyEntry);
    if (wanted && mode == kExtractOne) matched = true;
    const bool safe = isSafeRelative(name);
    const bool write = (mode == kExtract || mode == kExtractOne) && wanted && safe;

    int operation = RAR_SKIP;
    if (mode == kTest && wanted) operation = RAR_TEST;
    if (write) operation = RAR_EXTRACT;

    const int processCode = processFile(archive, operation, write ? dest : std::string());
    if (processCode != ERAR_SUCCESS && operation != RAR_SKIP) {
      error = errorText(processCode);
      break;
    }

    Entry entry;
    entry.name = name;
    entry.isDirectory = directory;
    entry.isEncrypted = fileEncrypted;
    entry.skipped = !safe;
    entry.uncompressedSize =
        (static_cast<uint64_t>(header.UnpSizeHigh) << 32) | header.UnpSize;
    entry.compressedSize =
        (static_cast<uint64_t>(header.PackSizeHigh) << 32) | header.PackSize;
    entry.crc32 = header.FileCRC;
    entry.modifiedAt = modifiedMs(header);
    entry.extractedPath = write ? joinPath(dest, name) : std::string();
    if (!safe) ++skipped;
    if (write && !directory) ++writtenFiles;
    entries.push_back(entry);
  }

  RARCloseArchive(archive);
  if (!error.empty()) return failJson(error, version);
  if (mode == kExtractOne && !matched) return failJson("Entry not found", version);

  std::string message;
  if (mode == kList) {
    message = "Listed " + std::to_string(entries.size()) + " entries.";
  } else if (mode == kTest) {
    message = "Archive is valid";
  } else {
    message = "Extracted " + std::to_string(writtenFiles) + " files. (native UnRAR)";
    if (skipped > 0) {
      message += " Skipped " + std::to_string(skipped) + " unsafe or unsupported entries.";
    }
  }
  const std::string destination = (mode == kExtract || mode == kExtractOne) ? dest : std::string();
  return successJson(message, version, encrypted, destination, entries);
}

void runOnLargeStack(const std::function<void()>& function) {
#if defined(_WIN32)
  struct Job {
    const std::function<void()>* function;
  };
  Job job = {&function};
  HANDLE thread = CreateThread(
      nullptr,
      8 * 1024 * 1024,
      [](LPVOID param) -> DWORD {
        static_cast<Job*>(param)->function->operator()();
        return 0;
      },
      &job,
      0,
      nullptr);
  if (thread == nullptr) {
    function();
    return;
  }
  WaitForSingleObject(thread, INFINITE);
  CloseHandle(thread);
#else
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, 8 * 1024 * 1024);
  const std::function<void()>* job = &function;
  pthread_t thread;
  const int created = pthread_create(
      &thread,
      &attr,
      [](void* param) -> void* {
        (*static_cast<const std::function<void()>*>(param))();
        return nullptr;
      },
      const_cast<std::function<void()>*>(job));
  pthread_attr_destroy(&attr);
  if (created != 0) {
    function();
    return;
  }
  pthread_join(thread, nullptr);
#endif
}

char* copyString(const std::string& value) {
  char* out = static_cast<char*>(std::malloc(value.size() + 1));
  if (out == nullptr) return nullptr;
  std::memcpy(out, value.data(), value.size());
  out[value.size()] = '\0';
  return out;
}

}  // namespace

char* flutter_rar_run(
    const char* path,
    const char* dest,
    const char* password,
    const char* entry,
    int mode) {
  std::lock_guard<std::mutex> lock(g_mutex);
  std::string json;
  try {
    runOnLargeStack([&]() {
      json = runArchive(
          path == nullptr ? std::string() : path,
          dest == nullptr ? std::string() : dest,
          password == nullptr ? std::string() : password,
          entry == nullptr ? std::string() : entry,
          mode);
    });
  } catch (const std::exception& error) {
    json = failJson(error.what(), "");
  } catch (...) {
    json = failJson("Unknown native error", "");
  }
  if (json.empty()) json = failJson("Unknown native error", "");
  return copyString(json);
}

void flutter_rar_free(char* ptr) { std::free(ptr); }
