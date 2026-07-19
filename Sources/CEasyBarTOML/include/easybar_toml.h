#ifndef EASYBAR_TOML_H
#define EASYBAR_TOML_H

#include <stddef.h>

char *easybar_toml_parse(const char *input);
char *easybar_toml_edit(const char *input, const char *request_json);
void easybar_toml_string_free(char *value);

#endif
