#pragma once

#include <functional>
#include <string>
#include <vector>

using fun = std::function<bool(const std::string&)>;

std::vector<fun> get_funs();
