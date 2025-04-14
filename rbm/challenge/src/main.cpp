#include <fstream>
#include <iostream>
#include <vector>

#include "base64.hpp"
#include "generated.hpp"

const std::string get_flag();
const std::string maybe_get_env(const std::string env_name, const std::string default_value);

static_assert(sizeof(unsigned long long) == sizeof(uint64_t));

int main()
{
  std::cout << "rainbow mountain" << std::endl;

  try {
    std::cout << "function index: " << std::endl;
    std::vector<fun>::size_type fn_number;

    std::cin >> fn_number;

    fun got_fun = get_funs().at(fn_number);

    std::cout << "picked " << std::hex << (uint64_t)&got_fun << std::dec << std::endl;

    std::string input;
    std::cout << "base64'd input: ";
    std::cin >> input;

    std::string decoded_input = base64::from_base64(input);

    std::cout << "decoded " << decoded_input.length() << " bytes" << std::endl;

    if (got_fun(decoded_input)) {
      std::cout << "correct!" << std::endl;
      std::cout << "the flag is " <<
        get_flag() << std::endl;
    } else {
      std::cout << "incorrect!" << std::endl;
    }
  } catch (std::out_of_range &e) {
    std::cout << "function index out of range" << std::endl;
  } catch (std::exception &e) {
    std::cout << "error: " << e.what() << std::endl;
  }
}

const std::string get_flag() {
  char* env_value = std::getenv("FLAG");
  if (env_value) {
    return std::string(env_value);
  }

  const std::string flag_filename = maybe_get_env("FLAG_FILE", "/flag");
  std::ifstream flag_file(flag_filename);
  if (!flag_file.is_open()) {
    return "no flag configured! contact orga";
  }

  std::string flag;
  std::getline(flag_file, flag);
  flag_file.close();
  if (flag.empty()) {
    return "no flag configured! contact orga";
  }
  return flag;
}

const std::string maybe_get_env(const std::string env_name, const std::string default_value)
{
  char *env_value = std::getenv(env_name.c_str());

  if (env_value)
  {
    return std::string(env_value);
  }
  return default_value;
}
